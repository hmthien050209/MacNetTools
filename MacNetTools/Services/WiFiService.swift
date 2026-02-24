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
private struct ScannedNetworkData: Sendable {
    let bssid: String
    let rssi: Int
    let noise: Int
    let informationElementData: Data?
}

/// Wraps CoreWLAN to provide WiFi scanning and vendor lookup.
/// Information Element parsing is delegated to `WiFiIEParser`.
/// The expensive `scanForNetworks` call is dispatched to a background GCD queue
/// so as not to block the Swift cooperative thread pool.
class WiFiService: @unchecked Sendable {
    private let vendorCache = VendorCache()

    func getWiFiModel(interfaceName: String? = nil) async -> WiFiModel? {
        let client = CWWiFiClient.shared()

        guard
            let interface = interfaceName.flatMap({
                client.interface(withName: $0)
            }) ?? client.interface()
        else {
            return nil
        }

        // Read fast CWInterface properties (lightweight, OK on cooperative pool)
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

        // Run the expensive scanForNetworks on a background GCD queue
        // to avoid blocking the Swift cooperative thread pool
        let scannedNetworks = await scanNetworksInBackground(ssid: ssid)

        // Parse Information Elements once for the connected BSSID
        var encryptionInfo: String? = nil
        var bssLoad: BSSLoadInfo? = nil
        var vendorSpecificIEs: [VendorSpecificIE] = []
        var secondaryChannelOffset: String? = nil
        var secondaryChannels: [Int] = []

        if let currentData = scannedNetworks.first(where: {
            $0.bssid == connectedBssid
        }),
            let ieData = currentData.informationElementData
        {
            let ies = WiFiIEParser.parseInformationElements(ieData)

            if let securityInfo = WiFiIEParser.extractCipherInfo(from: ies) {
                let group = securityInfo.group ?? "Unknown"
                let pairwise =
                    securityInfo.pairwise.isEmpty
                    ? "None" : securityInfo.pairwise.joined(separator: ", ")
                let akms =
                    securityInfo.akms.isEmpty
                    ? "None" : securityInfo.akms.joined(separator: ", ")
                encryptionInfo =
                    "AKM: \(akms); Pairwise: \(pairwise); Group: \(group)"
            }

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

        // Async vendor lookups (non-blocking, fine on cooperative pool)
        async let fetchedVendor = fetchVendorName(bssid: connectedBssid)
        async let fetchedAvailableBssidsWithVendors = buildBSSIDsWithVendors(
            from: scannedNetworks
        )

        let (vendor, availableBssidsWithVendors) = await (
            fetchedVendor, fetchedAvailableBssidsWithVendors
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
            secondaryChannels: secondaryChannels
        )
    }

    // MARK: - Helpers

    /// Runs the expensive scanForNetworks on a background GCD queue,
    /// extracting only Sendable data from CWNetwork objects.
    private func scanNetworksInBackground(ssid: String) async
        -> [ScannedNetworkData]
    {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let iface = CWWiFiClient.shared().interface(),
                    let ssidData = ssid.data(using: .utf8),
                    let networks = try? iface.scanForNetworks(
                        withSSID: ssidData
                    )
                else {
                    continuation.resume(returning: [])
                    return
                }
                let results = networks.map { network in
                    ScannedNetworkData(
                        bssid: network.bssid ?? "",
                        rssi: network.rssiValue,
                        noise: network.noiseMeasurement,
                        informationElementData: network.informationElementData
                    )
                }
                continuation.resume(returning: results)
            }
        }
    }

    /// Builds BSSID display strings with vendor info from pre-scanned data.
    private func buildBSSIDsWithVendors(
        from scannedNetworks: [ScannedNetworkData]
    ) async -> [String] {
        var results: [String] = []
        for data in scannedNetworks where !data.bssid.isEmpty {
            let vendor = await fetchVendorName(bssid: data.bssid)
            let snr = data.rssi - data.noise
            results.append(
                "\(data.bssid) (\(vendor), RSSI: \(data.rssi) dBm, Noise: \(data.noise) dBm, SNR: \(snr) dB)"
            )
        }
        return results
    }

    // MARK: - Vendor lookup

    /// Dynamically fetches the vendor name from a BSSID using a public API.
    func fetchVendorName(bssid: String?) async -> String {
        guard let bssid = bssid, !bssid.isEmpty else {
            return "BSSID unknown"
        }

        if let cached = await vendorCache.get(bssid),
            cached != kVendorLookupFailed
        {
            return cached
        }

        guard let url = URL(string: "https://api.macvendors.com/\(bssid)")
        else {
            return "Invalid BSSID"
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            let name: String
            if statusCode == 200 {
                name = String(data: data, encoding: .utf8) ?? kUnknownVendor
            } else if statusCode == 404 {
                // Not found
                name = kUnknownVendor
            } else {
                // Other errors, don't cache
                return kVendorLookupFailed
            }

            await vendorCache.set(name, for: bssid)
            return name
        } catch {
            return kVendorLookupFailed
        }
    }
}
