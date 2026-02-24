import Foundation

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

/// Pure-function helpers for parsing 802.11 Information Elements.
enum WiFiIEParser {

    // MARK: - Top-level parsers

    static func parseInformationElements(_ ieData: Data) -> [(
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

    static func extractCipherInfo(from ies: [(id: UInt8, payload: Data)]) -> (
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

    /// Extracts BSS Load element (IE ID 11) from pre-parsed Information Elements.
    static func extractBSSLoad(from ies: [(id: UInt8, payload: Data)])
        -> BSSLoadInfo?
    {
        guard let ie = ies.first(where: { $0.id == 11 }),
            ie.payload.count >= 5
        else { return nil }

        // 802.11 IEs use little-endian byte order for multi-byte fields
        let stationCount = Int(ie.payload[0]) | (Int(ie.payload[1]) << 8)
        let utilization = Double(ie.payload[2]) / 255.0 * 100.0
        let capacity = Int(ie.payload[3]) | (Int(ie.payload[4]) << 8)

        return BSSLoadInfo(
            stationCount: stationCount,
            channelUtilization: utilization,
            availableCapacity: capacity
        )
    }

    /// Extracts the secondary channel offset from HT Operation IE (ID 61).
    static func extractSecondaryChannelOffset(
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

    /// Extracts the list of secondary channels based on HT (ID 61) and VHT (ID 192) Operation IEs.
    static func extractSecondaryChannels(
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

    /// Extracts unique Vendor Specific IEs (IE ID 221) with resolved vendor names
    /// using a built-in OUI database (like Aruba Network Utility).
    static func extractVendorSpecificIEs(from ies: [(id: UInt8, payload: Data)])
        -> [VendorSpecificIE]
    {
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
            result.append(VendorSpecificIE(oui: oui, vendorName: vendorName))
        }
        return result
    }

    // MARK: - Private helpers

    /// Extracts Group Cipher, Pairwise Ciphers, and AKMs starting from a specific byte offset.
    nonisolated private static func parseSecurityStructure(
        payload: Data,
        baseOffset: Int
    ) -> (
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

        // Helper function to extract lists of security suites (Pairwise ciphers or AKMs)
        func extractSecuritySuites(
            count: Int,
            nameResolver: ([UInt8], UInt8) -> String
        ) -> [String] {
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
            pairwise = extractSecuritySuites(
                count: pairCount,
                nameResolver: cipherName
            )
        }

        // 3. Parse AKMs
        var akms: [String] = []
        if offset + 1 < payload.count {
            let akmCount =
                Int(payload[offset]) | (Int(payload[offset + 1]) << 8)
            offset += 2
            akms = extractSecuritySuites(count: akmCount, nameResolver: akmName)
        }

        return (group, pairwise, akms)
    }

    // MARK: - OUI translators

    nonisolated private static func cipherName(_ oui: [UInt8], _ type: UInt8)
        -> String
    {
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

    nonisolated private static func akmName(_ oui: [UInt8], _ type: UInt8)
        -> String
    {
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
}
