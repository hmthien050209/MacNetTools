import Foundation

@Observable
class BasicNetViewModel {
    var basicNetModel: BasicNetModel?
    
    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()
    
    @discardableResult
    func updateBasicNet() -> BasicNetModel? {
        locationPermissionService.requestPermission()
        basicNetModel = coreWlanService.getBasicNetModel()
        return basicNetModel
    }
}
