import Foundation

struct MainModel {
  var pollIntervalSecs: UInt64
  var lastUpdated: Date
  var basicNet: BasicNetModel
  var wiFi: WiFiModel
  var pings: [PingModel]
  var externalTools: ExternalToolsModel
  var refreshInProgress: Bool
  var currentInterface: String
}
