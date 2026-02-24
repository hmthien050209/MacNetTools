import CoreWLAN
import Foundation
import SystemConfiguration

/// The vendor cache based on the BSSIDs, to prevent rate limiting exceeding
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

/// Built-in OUI lookup table for vendor-specific Information Elements.
/// Aruba Network Utility and similar tools use a local database rather than
/// an API to resolve vendor names from OUI prefixes.
private let knownOUIs: [String: String] = [
    "00:50:F2": "Microsoft",
    "00:0B:86": "Aruba Networks",
    "00:03:7F": "Atheros Communications",
    "50:6F:9A": "Wi-Fi Alliance",
    "00:40:96": "Cisco Systems",
    "00:10:18": "Broadcom",
    "00:90:4C": "Epigram (Broadcom)",
    "00:17:F2": "Apple",
    "00:E0:4C": "Realtek Semiconductor",
    "8C:FD:F0": "Qualcomm",
    "00:15:6D": "Ubiquiti",
    "00:27:22": "Ubiquiti Networks",
    "00:0C:E7": "MediaTek",
    "00:0C:43": "Ralink Technology",
    "00:24:D7": "Intel Corporate",
    "00:1A:11": "Google",
    "00:26:86": "Quantenna",
    "AC:85:3D": "Huawei Technologies",
    "00:14:6C": "Netgear",
    "00:1B:11": "D-Link",
    "00:0F:AC": "IEEE 802.11",
    "00:13:74": "Atheros",
    "00:1D:6E": "Nokia",
    "00:26:44": "Thomson Telecom",
]

class CoreWLANService: @unchecked Sendable {
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
            let ies = parseInformationElements(ieData)

            if let securityInfo = extractCipherInfo(from: ies) {
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

            bssLoad = extractBSSLoad(from: ies)
            vendorSpecificIEs = extractVendorSpecificIEs(from: ies)
            secondaryChannelOffset = extractSecondaryChannelOffset(from: ies)
            secondaryChannels = extractSecondaryChannels(
                primaryChannel: primaryChannelNumber,
                ies: ies
            )
        }

        // Async vendor lookups (non-blocking, fine on cooperative pool)
        async let fetchedVendor = fetchVendorName(bssid: connectedBssid)
        async let fetchedAvailableBssidsWithVendors =
            buildBSSIDsWithVendors(from: scannedNetworks)

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

    func getBasicNetModel(interfaceName: String? = nil) async -> BasicNetModel?
    {
        let client = CWWiFiClient.shared()

        guard
            let interface = interfaceName.flatMap({
                client.interface(withName: $0)
            }) ?? client.interface(),
            let name = interface.interfaceName
        else {
            return nil
        }

        // Move blocking SystemConfiguration and ifaddrs work to a background
        // GCD queue to avoid blocking the Swift cooperative thread pool
        let (addrInfo, networkDetails) = await withCheckedContinuation {
            (
                continuation: CheckedContinuation<
                    (
                        (ip: String?, subnet: String?),
                        (router: String?, mtu: String)
                    ), Never
                >
            ) in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let addr = self.getInterfaceAddressInfo(for: name)
                let details = self.getSystemConfigurationInfo(for: name)
                continuation.resume(returning: (addr, details))
            }
        }

        // Run public IP lookups in parallel (non-blocking async network calls)
        async let ipV4 = getPublicIp(apiUrl: kIpifyV4Url)
        async let ipV6 = getPublicIp(apiUrl: kIpifyV6Url)

        return BasicNetModel(
            mtu: networkDetails.mtu,
            localIp: addrInfo.ip ?? "0.0.0.0",
            routerIp: networkDetails.router ?? "0.0.0.0",
            subnetMask: addrInfo.subnet ?? "255.255.255.0",
            publicIpV4: await ipV4 ?? "",
            publicIpV6: await ipV6 ?? "",
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
                        informationElementData: network
                            .informationElementData
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

    /// Get our public IP from the specified API provider (via API URL)
    private func getPublicIp(apiUrl: String) async -> String? {
        guard let url = URL(string: apiUrl) else { return nil }

        do {
            // Fetch data
            let (data, _) = try await URLSession.shared.data(from: url)

            // Decode JSON
            let result = try JSONDecoder().decode(Ipify.self, from: data)
            return result.ip
        } catch {
            print("Failed to fetch IP: \(error.localizedDescription)")
            return nil
        }
    }

    /// Uses System Configuration to find the Gateway (Router) and MTU
    private func getSystemConfigurationInfo(for interfaceName: String) -> (
        router: String?, mtu: String
    ) {
        var router: String?
        var mtu = "Unknown"

        guard
            let dynamicStore = SCDynamicStoreCreate(
                nil,
                "MacNetTools" as CFString,
                nil,
                nil
            )
        else {
            return (nil, mtu)
        }

        // Get Router/Gateway (Global IPv4 State)
        if let dict = SCDynamicStoreCopyValue(
            dynamicStore,
            "State:/Network/Global/IPv4" as CFString
        ) as? [String: Any],
            let gateway = dict["Router"] as? String
        {
            router = gateway
        }

        // Get MTU for the specific interface
        guard
            let interfaces = SCNetworkInterfaceCopyAll()
                as? [SCNetworkInterface]
        else {
            return (router, mtu)  // Safely fallback to returning what we have so far
        }

        for interface in interfaces {
            // Compare the interface's BSD name (e.g., "en0") to the requested interfaceName
            if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                bsdName == interfaceName
            {

                var currentMTU: Int32 = 0

                // SCNetworkInterfaceCopyMTU returns a Bool and populates our currentMTU reference
                if SCNetworkInterfaceCopyMTU(interface, &currentMTU, nil, nil) {
                    mtu = String(currentMTU)
                }

                break  // Exit the loop once the target interface is found and processed
            }
        }

        return (router, mtu)
    }

    /// Uses low-level C API getifaddrs to find IP and Subnet
    private func getInterfaceAddressInfo(for interfaceName: String) -> (
        ip: String?, subnet: String?
    ) {
        var address: String?
        var subnet: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        // Retrieve the current interfaces - returns 0 on success
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (nil, nil)
        }

        // Ensure memory is freed when the function returns
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addr = interface.ifa_addr.pointee

            // Check for IPv4 (AF_INET)
            guard addr.sa_family == UInt8(AF_INET) else { continue }

            // Match the interface name (e.g., "en0")
            let name = String(cString: interface.ifa_name)
            guard name == interfaceName else { continue }

            // Ensure the interface is UP and RUNNING
            let flags = Int32(interface.ifa_flags)
            guard (flags & IFF_UP) != 0 else { continue }

            // Get the IP Address
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                interface.ifa_addr,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                socklen_t(0),
                NI_NUMERICHOST
            ) == 0 {
                address = String(cString: hostname)
            }

            // Get the Subnet Mask
            if let netmask = interface.ifa_netmask {
                var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    netmask,
                    socklen_t(netmask.pointee.sa_len),
                    &netmaskName,
                    socklen_t(netmaskName.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST
                ) == 0 {
                    subnet = String(cString: netmaskName)
                }
            }

            // Break early if we found a valid active address to avoid duplicates
            if address != nil { break }
        }

        return (address, subnet)
    }

    // MARK: - WiFi Security Stuff

    private func extractCipherInfo(from ies: [(id: UInt8, payload: Data)]) -> (
        group: String?, pairwise: [String], akms: [String]
    )? {
        // Priority 1: Modern RSN (WPA2/WPA3) - ID 48
        if let rsn = ies.first(where: { $0.id == 48 }) {
            // RSN payload: Bytes 0-1 are Version. Group Cipher starts at Byte 2.
            return parseSecurityStructure(payload: rsn.payload, baseOffset: 2)
        }

        // Priority 2: Legacy Vendor Specific WPA1 - ID 221
        // WPA1 OUI is 00:50:F2, Type is 1.
        if let wpa1 = ies.first(where: {
            $0.id == 221 && $0.payload.starts(with: [0x00, 0x50, 0xF2, 0x01])
        }) {
            // WPA1 payload: Bytes 0-3 are OUI+Type. Bytes 4-5 are Version. Group Cipher starts at Byte 6.
            return parseSecurityStructure(payload: wpa1.payload, baseOffset: 6)
        }

        return nil
    }

    private func parseInformationElements(_ ieData: Data) -> [(
        id: UInt8, payload: Data
    )] {
        var result: [(UInt8, Data)] = []
        var i = 0
        while i + 1 < ieData.count {
            let id = ieData[i]
            let len = Int(ieData[i + 1])
            let start = i + 2
            let end = start + len
            guard end <= ieData.count else { break }
            result.append((id, ieData.subdata(in: start..<end)))
            i = end
        }
        return result
    }

    // MARK: - OUI Translators

    private func cipherName(_ oui: [UInt8], _ type: UInt8) -> String {
        if oui == [0x00, 0x0F, 0xAC] {  // IEEE Standard
            switch type {
            case 1: return "WEP-40"
            case 2: return "TKIP"
            case 4: return "CCMP-128 (AES)"
            case 5: return "WEP-104"
            case 6: return "BIP-CMAC-128"
            case 8: return "GCMP-256"
            case 9: return "GCMP-128"
            case 10: return "BIP-GMAC-128"
            case 11: return "BIP-GMAC-256"
            case 12: return "BIP-CMAC-256"
            default: return "RSN-Cipher-\(type)"
            }
        } else if oui == [0x00, 0x50, 0xF2] {  // Microsoft / Legacy WPA
            switch type {
            case 2: return "TKIP (WPA)"
            case 4: return "CCMP (WPA)"
            default: return "WPA-Cipher-\(type)"
            }
        }
        return String(
            format: "%02X:%02X:%02X:%02X",
            oui[0],
            oui[1],
            oui[2],
            type
        )
    }

    private func akmName(_ oui: [UInt8], _ type: UInt8) -> String {
        if oui == [0x00, 0x0F, 0xAC] {  // IEEE Standard
            switch type {
            case 1: return "802.1X (EAP)"
            case 2: return "PSK (WPA2)"
            case 3: return "FT-802.1X"
            case 4: return "FT-PSK"
            case 5: return "802.1X-SHA256"
            case 6: return "PSK-SHA256"
            case 8: return "SAE (WPA3)"
            case 9: return "FT-SAE"
            case 11: return "802.1X-Suite-B-192"
            case 18: return "OWE"
            default: return "AKM-\(type)"
            }
        } else if oui == [0x00, 0x50, 0xF2] {  // Microsoft / Legacy WPA
            switch type {
            case 1: return "802.1X (WPA)"
            case 2: return "PSK (WPA)"
            default: return "WPA-AKM-\(type)"
            }
        }
        return String(
            format: "%02X:%02X:%02X:%02X",
            oui[0],
            oui[1],
            oui[2],
            type
        )
    }

    // MARK: - Security Structure Extractor

    /// Extracts Group Cipher, Pairwise Ciphers, and AKMs starting from a specific byte offset.
    private func parseSecurityStructure(payload: Data, baseOffset: Int) -> (
        group: String?, pairwise: [String], akms: [String]
    )? {
        // Need at least 4 bytes for the Group cipher (3 for OUI, 1 for Type)
        guard payload.count >= baseOffset + 4 else { return nil }

        // 1. Parse Group Cipher
        let groupOui = [
            payload[baseOffset], payload[baseOffset + 1],
            payload[baseOffset + 2],
        ]
        let groupType = payload[baseOffset + 3]
        let group = cipherName(groupOui, groupType)

        var offset = baseOffset + 4

        // Helper function to extract lists of suites (Pairwise or AKM)
        func extractSuites(count: Int, nameResolver: ([UInt8], UInt8) -> String)
            -> [String]
        {
            var suites: [String] = []
            for _ in 0..<count {
                guard offset + 3 < payload.count else { break }
                let oui = [
                    payload[offset], payload[offset + 1], payload[offset + 2],
                ]
                let type = payload[offset + 3]
                suites.append(nameResolver(oui, type))
                offset += 4
            }
            return suites
        }

        // 2. Parse Pairwise Ciphers
        var pairwise: [String] = []
        if offset + 1 < payload.count {
            let pairCount =
                Int(payload[offset]) | (Int(payload[offset + 1]) << 8)
            offset += 2
            pairwise = extractSuites(count: pairCount, nameResolver: cipherName)
        }

        // 3. Parse AKMs
        var akms: [String] = []
        if offset + 1 < payload.count {
            let akmCount =
                Int(payload[offset]) | (Int(payload[offset + 1]) << 8)
            offset += 2
            akms = extractSuites(count: akmCount, nameResolver: akmName)
        }

        return (group, pairwise, akms)
    }

    // MARK: - IE Data Extraction

    /// Extracts the list of secondary channels based on HT (ID 61) and VHT (ID 192) Operation IEs.
    private func extractSecondaryChannels(
        primaryChannel: Int,
        ies: [(id: UInt8, payload: Data)]
    ) -> [Int] {
        guard primaryChannel > 0 else { return [] }
        var channels: [Int] = []

        // Priority 1: VHT Operation IE (802.11ac for 80MHz, 160MHz, 80+80MHz)
        if let vht = ies.first(where: { $0.id == 192 }), vht.payload.count >= 3
        {
            let width = vht.payload[0]
            let center1 = Int(vht.payload[1])
            let center2 = Int(vht.payload[2])

            if width == 1 || width == 2 || width == 3 {
                // width 1 = 80MHz (4 channels)
                if width == 1 {
                    channels.append(contentsOf: [
                        center1 - 6, center1 - 2, center1 + 2, center1 + 6,
                    ])
                }
                // width 2 = 160MHz (8 channels)
                else if width == 2 {
                    let offsets = [-14, -10, -6, -2, 2, 6, 10, 14]
                    channels.append(contentsOf: offsets.map { center1 + $0 })
                }
                // width 3 = 80+80MHz (4 channels + 4 channels)
                else if width == 3 {
                    channels.append(contentsOf: [
                        center1 - 6, center1 - 2, center1 + 2, center1 + 6,
                    ])
                    channels.append(contentsOf: [
                        center2 - 6, center2 - 2, center2 + 2, center2 + 6,
                    ])
                }

                // Filter out the primary channel, leaving only the secondaries
                return channels.filter { $0 != primaryChannel }.sorted()
            }
        }

        // Priority 2: HT Operation IE (802.11n for 40MHz)
        // If VHT is missing or width == 0 (which means 20/40 MHz fallback), we use HT.
        if let ht = ies.first(where: { $0.id == 61 }), ht.payload.count >= 2 {
            let offset = ht.payload[1] & 0x03
            if offset == 1 {
                // Secondary is "Above" (+4)
                return [primaryChannel + 4]
            } else if offset == 3 {
                // Secondary is "Below" (-4)
                return [primaryChannel - 4]
            }
        }

        // Returns empty if it's strictly a 20MHz network
        return []
    }

    /// Extracts BSS Load element (IE ID 11) from pre-parsed Information Elements.
    private func extractBSSLoad(from ies: [(id: UInt8, payload: Data)])
        -> BSSLoadInfo?
    {
        guard let ie = ies.first(where: { $0.id == 11 }),
            ie.payload.count >= 5
        else { return nil }

        // 802.11 IEs use little-endian byte order for multi-byte fields
        let stationCount =
            Int(ie.payload[0]) | (Int(ie.payload[1]) << 8)
        let utilization = Double(ie.payload[2]) / 255.0 * 100.0
        let capacity =
            Int(ie.payload[3]) | (Int(ie.payload[4]) << 8)

        return BSSLoadInfo(
            stationCount: stationCount,
            channelUtilization: utilization,
            availableCapacity: capacity
        )
    }

    /// Extracts the secondary channel offset from HT Operation IE (ID 61).
    private func extractSecondaryChannelOffset(
        from ies: [(id: UInt8, payload: Data)]
    ) -> String? {
        // HT Operation IE: byte 0 = primary channel, byte 1 bits 0-1 = secondary channel offset
        guard let ie = ies.first(where: { $0.id == 61 }),
            ie.payload.count >= 2
        else { return nil }

        let offset = ie.payload[1] & 0x03
        switch offset {
        case 0: return "None"
        case 1: return "Above"
        case 3: return "Below"
        default: return "Reserved"
        }
    }

    /// Extracts unique Vendor Specific IEs (IE ID 221) with resolved vendor names
    /// using a built-in OUI database (like Aruba Network Utility).
    private func extractVendorSpecificIEs(
        from ies: [(id: UInt8, payload: Data)]
    ) -> [VendorSpecificIE] {
        var result: [VendorSpecificIE] = []
        var seenOUIs: Set<String> = []

        for ie in ies where ie.id == 221 && ie.payload.count >= 3 {
            let oui = String(
                format: "%02X:%02X:%02X",
                ie.payload[0],
                ie.payload[1],
                ie.payload[2]
            )
            guard !seenOUIs.contains(oui) else { continue }
            seenOUIs.insert(oui)

            let vendorName = knownOUIs[oui] ?? oui
            result.append(
                VendorSpecificIE(oui: oui, vendorName: vendorName)
            )
        }
        return result
    }

    // MARK: - Vendor specific info

    /// Dynamically fetches the vendor name from a BSSID using a public API
    func fetchVendorName(bssid: String?) async -> String {
        guard let bssid = bssid, !bssid.isEmpty else {
            return "BSSID unknown, can't get vendor"
        }

        if let cached = await vendorCache.get(bssid),
            cached != kUnknownVendor && cached != kVendorLookupFailed
        {
            return cached
        }

        guard let url = URL(string: "https://api.macvendors.com/\(bssid)")
        else { return "Invalid BSSID" }

        do {
            let (data, res) = try await URLSession.shared.data(from: url)
            let name =
                (res as? HTTPURLResponse)?.statusCode == 200
                ? String(data: data, encoding: .utf8) ?? kUnknownVendor
                : kUnknownVendor

            await vendorCache.set(name, for: bssid)
            return name
        } catch {
            return kVendorLookupFailed
        }
    }
}
