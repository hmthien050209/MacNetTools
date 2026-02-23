import Foundation

@Observable
class WiFiViewModel {
    var wiFiModel: WiFiModel?

    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()

    @discardableResult
    func updateWiFi() -> WiFiModel? {
        locationPermissionService.requestPermission()
        wiFiModel = coreWlanService.getWiFiModel()
        return wiFiModel
    }
}
