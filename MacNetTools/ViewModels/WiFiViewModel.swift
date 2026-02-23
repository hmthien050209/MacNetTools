import Foundation

@Observable
class WiFiViewModel {
    var wiFiModel: WiFiModel?

    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()

    @discardableResult
    func updateWiFi() async -> WiFiModel? {
        locationPermissionService.requestPermission()
        wiFiModel = await coreWlanService.getWiFiModel()
        return wiFiModel
    }
}
