import CoreWLAN
import Foundation

// MARK: - CoreWLAN Formatting Extensions

extension CWPHYMode: @retroactive CustomStringConvertible {
    /// Returns a standardized human-readable string for the PHY mode.
    public var description: String {
        switch self {
        case .modeNone: return "None"
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n (Wi-Fi 4)"
        case .mode11ac: return "802.11ac (Wi-Fi 5)"
        case .mode11ax: return "802.11ax (Wi-Fi 6/6E)"
        @unknown default:
            if self.rawValue == 7 { return "802.11be (Wi-Fi 7)" }
            return "Unknown (\(self.rawValue))"
        }
    }
}

extension CWSecurity: @retroactive CustomStringConvertible {
    /// Returns a standardized human-readable string for the security/encryption type.
    public var description: String {
        switch self {
        case .none: return "Open"
        case .WEP: return "WEP"
        case .wpaPersonal: return "WPA Personal"
        case .wpaPersonalMixed: return "WPA/WPA2 Personal"
        case .wpa2Personal: return "WPA2 Personal"
        case .personal: return "Personal"
        case .dynamicWEP: return "Dynamic WEP"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA/WPA2 Enterprise"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .enterprise: return "Enterprise"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA2/WPA3 Personal"
        case .OWE: return "OWE (Enhanced Open)"
        case .oweTransition: return "OWE Transition"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

extension CWChannel {
    /// Returns a comprehensive description of the channel including band and width.
    public var detailedDescription: String {
        let band = self.channelBand.description
        let width = self.channelWidth.description
        let unii = uniiBand
        let dfs = isDFS ? "DFS" : "Non-DFS"
        return "\(self.channelNumber) (\(band), \(width), \(unii), \(dfs))"
    }

    /// Maps the channel number to its UNII band name.
    public var uniiBand: String {
        switch self.channelBand {
        case .band2GHz:
            return "ISM"
        case .band5GHz:
            switch self.channelNumber {
            case 36...48: return "UNII-1"
            case 52...64: return "UNII-2A"
            case 100...140: return "UNII-2C"
            case 149...165: return "UNII-3"
            default: return "Unknown"
            }
        case .band6GHz:
            switch self.channelNumber {
            case 1...93: return "UNII-5"
            default: return "6GHz (Other)"
            }
        default:
            return "Unknown"
        }
    }

    /// Determines if the channel is in a DFS (Dynamic Frequency Selection) range.
    public var isDFS: Bool {
        return (52...64).contains(self.channelNumber) || (100...140).contains(self.channelNumber)
    }
}

extension CWChannelBand: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        case .bandUnknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

extension CWChannelWidth: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .width20MHz: return "20 MHz"
        case .width40MHz: return "40 MHz"
        case .width80MHz: return "80 MHz"
        case .width160MHz: return "160 MHz"
        case .widthUnknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Signal Health Calculations

extension SignalHealth {
    /// calculates health based on RSSI (Enterprise standards).
    public static func from(rssi: Int) -> SignalHealth {
        if rssi >= -55 { return .excellent }
        if rssi >= -67 { return .good }
        if rssi >= -75 { return .fair }
        if rssi >= -85 { return .poor }
        return .unusable
    }

    /// calculates health based on SNR (MCS rate requirements).
    public static func from(snr: Int) -> SignalHealth {
        if snr >= 35 { return .excellent }
        if snr >= 25 { return .good }
        if snr >= 15 { return .fair }
        if snr >= 10 { return .poor }
        return .unusable
    }
}
