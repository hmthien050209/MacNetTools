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
        
        self.wiFiModel = newModel
        
        return wiFiModel
    }
}
