import Foundation

@Observable
class BasicNetViewModel {
    var basicNetModel: BasicNetModel?
    
    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()
    
    func updateBasicNet() {
        locationPermissionService.requestPermission()
        basicNetModel = coreWlanService.getBasicNetModel()
    }
}
