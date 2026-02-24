import CoreWLAN

struct BSSLoadInfo {
    var stationCount: Int
    /// Channel utilization as a percentage (0–100).
    var channelUtilization: Double
    /// Available admission capacity in units of 32 µs/s.
    var availableCapacity: Int
}

struct VendorSpecificIE: Identifiable {
    let id = UUID()
    var oui: String
    var vendorName: String
}

struct WiFiModel {
    var ssid: String
    var connectedBssid: String
    var vendor: String
    var channel: CWChannel?
    var phyMode: CWPHYMode
    var security: CWSecurity
    var rssi: Int
    var noise: Int
    var signalNoiseRatio: Int
    var countryCode: String
    /// All available BSSIDs with vendors for the current SSID.
    var availableBssidsWithVendors: [String]
    /// Negotiated WiFi transmit rate (Mbps)
    var txRateMbps: Double
    /// Interface name (e.g. en0) for status bar.
    var interfaceName: String?
    var encryptionInfo: String
    /// BSS Load element data from the connected AP (IE 11).
    var bssLoad: BSSLoadInfo?
    /// Decoded vendor-specific Information Elements (IE 221).
    var vendorSpecificIEs: [VendorSpecificIE]
}

struct Ipify: Decodable {
    var ip: String
}
