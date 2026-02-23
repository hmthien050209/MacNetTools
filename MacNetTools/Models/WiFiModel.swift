import CoreWLAN

struct WiFiModel {
    var ssid: String
    var connectedBssid: String
    var channel: CWChannel?
    var phyMode: CWPHYMode
    var security: CWSecurity
    var rssi: Int
    var noise: Int
    var signalNoiseRatio: Int
    var countryCode: String
    /// All available BSSIDs for the current SSID.
    var availableBssids: [String]
    /// Negotiated WiFi transmit rate (Mbps)
    var txRateMbps: Double
    /// Interface name (e.g. en0) for status bar.
    var interfaceName: String?
    var encryptionInfo: String
}

struct Ipify: Decodable {
    var ip: String
}
