import Foundation

@Observable
class WiFiViewModel {
    var wiFiModel: WiFiModel?
    
    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()
    
    func updateWiFi() {
        locationPermissionService.requestPermission()
        wiFiModel = coreWlanService.getWiFiModel()
    }
}
