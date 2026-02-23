import Foundation

struct MainModel {
    var pollIntervalSecs: UInt64
    var lastUpdated: Date
    var basicNet: BasicNetModel
    var wiFi: WiFiModel
    var pings: Array<PingModel>
    var externalTools: ExternalToolsModel
    /// True while a data refresh is running in the background.
    var refreshInProgress: Bool
    /// Current network interface (e.g. en0) for status bar.
    var currentInterface: String
}
