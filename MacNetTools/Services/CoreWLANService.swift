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

class CoreWLANService {
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

        // Additional calculations
        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let signalNoiseRatio = rssi - noise

        // WiFi encryption info
        var encryptionInfo: String? = nil

        if let ssid = interface.ssid(),
            let iface = CWWiFiClient.shared().interface(),
            let networks = try? iface.scanForNetworks(
                withSSID: ssid.data(using: .utf8)
            ),
            let currentNet = networks.first(where: {
                $0.bssid == interface.bssid()
            }),
            let securityInfo = extractCipherInfo(from: currentNet)
        {
            // Safely unwrap and format the arrays
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

        return WiFiModel(
            ssid: interface.ssid() ?? kUnknown,
            connectedBssid: interface.bssid() ?? kUnknown,
            vendor: await fetchVendorName(bssid: interface.bssid()),
            channel: interface.wlanChannel(),
            phyMode: interface.activePHYMode(),
            security: interface.security(),
            rssi: rssi,
            noise: noise,
            signalNoiseRatio: signalNoiseRatio,
            countryCode: interface.countryCode() ?? kUnknown,
            availableBssidsWithVendors: await getBSSIDsWithVendorsForSameSSID(
                interface.ssid() ?? ""
            ),
            txRateMbps: interface.transmitRate(),
            interfaceName: interface.interfaceName,
            encryptionInfo: encryptionInfo ?? kUnknown,
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

        let addrInfo = getInterfaceAddressInfo(for: name)
        let networkDetails = getSystemConfigurationInfo(for: name)

        return BasicNetModel(
            mtu: networkDetails.mtu,
            localIp: addrInfo.ip ?? "0.0.0.0",
            routerIp: networkDetails.router ?? "0.0.0.0",
            subnetMask: addrInfo.subnet ?? "255.255.255.0",
            publicIpV4: await getPublicIp(apiUrl: kIpifyV4Url) ?? "",
            publicIpV6: await getPublicIp(apiUrl: kIpifyV6Url) ?? "",
        )
    }

    // MARK: - Helpers

    // Finds all BSSIDs for the same SSID as the connected network
    private func getBSSIDsWithVendorsForSameSSID(_ ssid: String) async
        -> [String]
    {
        guard let iface = CWWiFiClient.shared().interface() else { return [] }

        do {
            let networks = try iface.scanForNetworks(
                withSSID: ssid.data(using: .utf8)
            )
            var results: [String] = []

            for network in networks {
                if let bssid = network.bssid {
                    let vendor = await fetchVendorName(bssid: bssid)
                    let rssi = network.rssiValue
                    let noise = network.noiseMeasurement
                    let snr = rssi - noise
                    results.append("\(bssid) (\(vendor), RSSI: \(rssi) dBm, Noise: \(noise) dBm, SNR: \(snr) dB")
                }
            }

            return results
        } catch {
            print("Scan failed: \(error.localizedDescription)")
            return []
        }
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

    private func extractCipherInfo(from network: CWNetwork) -> (
        group: String?, pairwise: [String], akms: [String]
    )? {
        guard let ie = network.informationElementData else { return nil }
        let ies = parseInformationElements(ie)

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
