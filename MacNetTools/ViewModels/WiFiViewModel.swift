import Foundation

@Observable
class WiFiViewModel {
    var wiFiModel: WiFiModel?

    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()

    @discardableResult
    func updateWiFi() async -> WiFiModel? {
        locationPermissionService.requestPermission()
        let newModel = await coreWlanService.getWiFiModel()
        
        self.wiFiModel = newModel
        
        return wiFiModel
    }
}
