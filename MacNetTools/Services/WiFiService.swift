import CoreWLAN
import Foundation

/// Cache for vendor name lookups keyed by BSSID, to prevent rate limiting.
actor VendorCache {
    private var cache: [String: String] = [:]

    func get(_ bssid: String) -> String? {
        return cache[bssid]
    }

    func set(_ name: String, for bssid: String) {
        cache[bssid] = name
    }
}

/// Holds data extracted from a CWNetwork scan result, using only Sendable types
/// so it can safely cross thread boundaries.
/// When not connected, the noise is always 0, so we only include the RSSI data
private struct ScannedNetworkData: Sendable {
    let ssid: String
    let bssid: String
    let rssi: Int
    let channelNumber: Int
    let band: String
    let phyMode: String
    let informationElementData: Data?
}

/// Wraps CoreWLAN to provide WiFi scanning and vendor lookup.
/// Information Element (IE) parsing is handled via `WiFiIEParser`.
/// Reference: IEEE 802.11-2024 Clause 11 (MLME) and Clause 9 (Frame Formats).
class WiFiService: @unchecked Sendable {
    private let vendorCache = VendorCache()

    /// Retrieves a comprehensive WiFi model for the specified or default interface.
    ///
    /// This function orchestrates several operations:
    /// 1. Synchronous retrieval of active interface properties (RSSI, SSID, etc.).
    /// 2. Background scanning for nearby networks (prevents blocking the main thread).
    /// 3. Parallel asynchronous vendor lookups for all identified BSSIDs.
    /// 4. Parsing of Information Elements (IEs) from 802.11 Beacon/Probe Response frames.
    func getWiFiModel(interfaceName: String? = nil) async -> WiFiModel? {
        let client = CWWiFiClient.shared()

        guard
            let interface = interfaceName.flatMap({
                client.interface(withName: $0)
            }) ?? client.interface()
        else {
            return nil
        }

        // Read fast CWInterface properties
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let signalNoiseRatio = rssi - noise
        let ssid = interface.ssid() ?? kUnknown
        let connectedBssid = interface.bssid() ?? kUnknown
        let channel = interface.wlanChannel()
        let primaryChannelNumber = channel?.channelNumber ?? 0
        let phyMode = interface.activePHYMode()
        let security = interface.security()
        let countryCode = interface.countryCode() ?? kUnknown
        let txRate = interface.transmitRate()
        let ifName = interface.interfaceName

        // Background scanning to avoid blocking the Swift cooperative pool
        // IEEE 802.11 Clause 11.1.4 (Scanning)
        let scannedNetworksWithSameSSID = await scanNetworksInBackground(
            ssid: ssid
        )
        let scannedNearbyNetworks = await scanNetworksInBackground()

        // Parse Information Elements (IEs) for the connected BSSID
        // Reference: IEEE 802.11-2024 Clause 9.4.2 (Elements)
        var encryptionInfo: String? = nil
        var bssLoad: BSSLoadInfo? = nil
        var vendorSpecificIEs: [VendorSpecificIE] = []
        var secondaryChannelOffset: String? = nil
        var secondaryChannels: [Int] = []

        if let currentData = scannedNetworksWithSameSSID.first(where: {
            $0.bssid == connectedBssid
        }),
            let ieData = currentData.informationElementData
        {
            let ies = WiFiIEParser.parseInformationElements(ieData)

            if let securityInfo = WiFiIEParser.extractCipherInfo(from: ies) {
                let group = securityInfo.group ?? kUnknown
                let pairwise =
                    securityInfo.pairwise.isEmpty
                    ? "None" : securityInfo.pairwise.joined(separator: ", ")
                let akms =
                    securityInfo.akms.isEmpty
                    ? "None" : securityInfo.akms.joined(separator: ", ")
                encryptionInfo =
                    "AKM: \(akms); Pairwise: \(pairwise); Group: \(group)"
            }

            // BSS Load (IEEE 802.11-2024 Clause 9.4.2.26)
            bssLoad = WiFiIEParser.extractBSSLoad(from: ies)
            vendorSpecificIEs = WiFiIEParser.extractVendorSpecificIEs(from: ies)
            secondaryChannelOffset = WiFiIEParser.extractSecondaryChannelOffset(
                from: ies
            )
            secondaryChannels = WiFiIEParser.extractSecondaryChannels(
                primaryChannel: primaryChannelNumber,
                ies: ies
            )
        }

        // Execute vendor lookups and data processing in parallel
        async let fetchedNearbyNetworks = buildNearbyWiFiWithMetadata(
            from: scannedNearbyNetworks,
            connectedBssid: connectedBssid
        )
        async let fetchedVendor = fetchVendorName(bssid: connectedBssid)
        async let fetchedAvailableBssidsWithVendors = buildBSSIDsWithMetadata(
            from: scannedNetworksWithSameSSID,
            connectedBssid: connectedBssid
        )

        let (vendor, availableBssidsWithVendors, nearbyNetworks) = await (
            fetchedVendor, fetchedAvailableBssidsWithVendors,
            fetchedNearbyNetworks
        )

        return WiFiModel(
            ssid: ssid,
            connectedBssid: connectedBssid,
            vendor: vendor,
            channel: channel,
            phyMode: phyMode,
            security: security,
            rssi: rssi,
            noise: noise,
            signalNoiseRatio: signalNoiseRatio,
            countryCode: countryCode,
            availableBssidsWithVendors: availableBssidsWithVendors,
            txRateMbps: txRate,
            interfaceName: ifName,
            encryptionInfo: encryptionInfo ?? kUnknown,
            bssLoad: bssLoad,
            vendorSpecificIEs: vendorSpecificIEs,
            secondaryChannelOffset: secondaryChannelOffset,
            secondaryChannels: secondaryChannels,
            nearbyNetworks: nearbyNetworks
        )
    }

    // MARK: - Helpers

    /// Offloads the expensive `scanForNetworks` call to a background GCD queue.
    ///
    /// CoreWLAN scanning is a synchronous, blocking system call that can take
    /// several seconds. This method bridges to modern concurrency to keep the
    /// UI responsive.
    private func scanNetworksInBackground(ssid: String? = nil) async
        -> [ScannedNetworkData]
    {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let iface = CWWiFiClient.shared().interface(),
                    let networks = try? iface.scanForNetworks(
                        withSSID: ssid?.data(using: .utf8)
                    )
                else {
                    continuation.resume(returning: [])
                    return
                }
                let results = networks.map { network in
                    let phy = WiFiService.getPHYMode(for: network)
                    return ScannedNetworkData(
                        ssid: network.ssid ?? "",
                        bssid: network.bssid ?? "",
                        rssi: network.rssiValue,
                        channelNumber: network.wlanChannel?.channelNumber ?? 0,
                        band: network.wlanChannel?.channelBand.description
                            ?? kUnknown,
                        phyMode: phy,
                        informationElementData: network.informationElementData
                    )
                }
                continuation.resume(returning: results)
            }
        }
    }

    /// Parallelized retrieval of nearby WiFi metadata using TaskGroup.
    private func buildNearbyWiFiWithMetadata(
        from scannedNetworks: [ScannedNetworkData],
        connectedBssid: String
    ) async -> [NearbyWiFiNetwork] {
        await withTaskGroup(of: (Int, NearbyWiFiNetwork).self) { group in
            let validNetworks = scannedNetworks.enumerated().filter {
                !$0.element.bssid.isEmpty && !$0.element.ssid.isEmpty
            }

            for (index, data) in validNetworks {
                group.addTask {
                    // Staggering: Introduce a small offset delay to avoid triggering 429s
                    // on initial burst of parallel lookups.
                    let delayMs = UInt64(index % 10) * 100_000_000  // 100ms * (0..9)
                    try? await Task.sleep(nanoseconds: delayMs)

                    let vendor = await self.fetchVendorName(bssid: data.bssid)
                    let network = NearbyWiFiNetwork(
                        ssid: data.ssid,
                        bssid: data.bssid,
                        vendor: vendor,
                        channel: data.channelNumber,
                        band: data.band,
                        phyMode: data.phyMode,
                        rssi: data.rssi,
                        isConnected: data.bssid == connectedBssid
                    )
                    return (index, network)
                }
            }

            var results = [(Int, NearbyWiFiNetwork)]()
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    /// Parallelized retrieval of BSSID metadata using TaskGroup.
    private func buildBSSIDsWithMetadata(
        from scannedNetworks: [ScannedNetworkData],
        connectedBssid: String
    ) async -> [NearbyWiFiNetwork] {
        await withTaskGroup(of: (Int, NearbyWiFiNetwork).self) { group in
            let validNetworks = scannedNetworks.enumerated().filter {
                !$0.element.bssid.isEmpty
            }

            for (index, data) in validNetworks {
                group.addTask {
                    let vendor = await self.fetchVendorName(bssid: data.bssid)
                    let network = NearbyWiFiNetwork(
                        ssid: data.ssid,
                        bssid: data.bssid,
                        vendor: vendor,
                        channel: data.channelNumber,
                        band: data.band,
                        phyMode: data.phyMode,
                        rssi: data.rssi,
                        isConnected: data.bssid == connectedBssid
                    )
                    return (index, network)
                }
            }

            var results = [(Int, NearbyWiFiNetwork)]()
            for await result in group {
                results.append(result)
            }
            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    // MARK: - Vendor lookup

    /// Fetches the hardware vendor for a given BSSID (OUI lookup).
    ///
    /// The first 3 octets (OUI) typically identify the manufacturer.
    /// Reference: IEEE 802.11-2024, Clause 9.2.4.3.4 (BSSID) and Clause 9.4.1.29 (Organization Identifier).
    /// Logic includes retry-on-rate-limit (429) and staggered polling.
    func fetchVendorName(bssid: String?) async -> String {
        guard let bssid = bssid, !bssid.isEmpty else {
            return ""
        }

        if let cached = await vendorCache.get(bssid),
            cached != kVendorLookupFailed
        {
            return cached
        }

        guard let url = URL(string: "\(kMacVendorsBaseUrl)\(bssid)")
        else { return "" }

        var retryCount = 0
        let maxRetries = 2

        while retryCount <= maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: url
                )
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                if statusCode == 200 {
                    let name =
                        String(data: data, encoding: .utf8) ?? kUnknownVendor
                    await vendorCache.set(name, for: bssid)
                    return name
                } else if statusCode == 404 {
                    await vendorCache.set(kUnknownVendor, for: bssid)
                    return kUnknownVendor
                } else if statusCode == 429 {
                    // Rate limited: Wait and retry with exponential backoff
                    retryCount += 1
                    if retryCount <= maxRetries {
                        // Wait 1s, then 2s
                        try? await Task.sleep(
                            nanoseconds: UInt64(retryCount) * 1_000_000_000
                        )
                        continue
                    }
                }

                // For other transient errors or if retries exhausted
                return ""
            } catch {
                retryCount += 1
                if retryCount <= maxRetries {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }
                return ""
            }
        }

        return ""
    }

    /// Determines the highest supported PHY mode for a scanned network.
    /// Since CWNetwork only provides a 'supports' check, we probe in descending order.
    private static func getPHYMode(for network: CWNetwork) -> String {
        if network.supportsPHYMode(.mode11ax) {
            return CWPHYMode.mode11ax.description
        }
        if network.supportsPHYMode(.mode11ac) {
            return CWPHYMode.mode11ac.description
        }
        if network.supportsPHYMode(.mode11n) {
            return CWPHYMode.mode11n.description
        }
        if network.supportsPHYMode(.mode11g) {
            return CWPHYMode.mode11g.description
        }
        if network.supportsPHYMode(.mode11a) {
            return CWPHYMode.mode11a.description
        }
        if network.supportsPHYMode(.mode11b) {
            return CWPHYMode.mode11b.description
        }
        return "Unknown"
    }
}
