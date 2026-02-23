import Foundation

@Observable
class BasicNetViewModel {
    var basicNetModel: BasicNetModel?
    
    private let coreWlanService = CoreWLANService()
    private let locationPermissionService = LocationPermissionService()
    
    @discardableResult
    func updateBasicNet() async -> BasicNetModel? {
        locationPermissionService.requestPermission()
        basicNetModel = await coreWlanService.getBasicNetModel()
        return basicNetModel
    }
}
