import Foundation

@MainActor
@Observable
class WiFiViewModel {
  var wiFiModel: WiFiModel?

  private let wiFiService = WiFiService()
  private let locationPermissionService = LocationPermissionService()

  @discardableResult
  func updateWiFi() async -> WiFiModel? {
    locationPermissionService.requestPermission()
    let newModel = await wiFiService.getWiFiModel()

    if let newModel, let existing = self.wiFiModel, existing == newModel {
      return existing
    }

    self.wiFiModel = newModel
    return wiFiModel
  }
}
