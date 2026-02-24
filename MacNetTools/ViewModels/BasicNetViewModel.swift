import Foundation

@MainActor
@Observable
class BasicNetViewModel {
    var basicNetModel: BasicNetModel?

    private let networkService = NetworkService()
    private let locationPermissionService = LocationPermissionService()

    @discardableResult
    func updateBasicNet() async -> BasicNetModel? {
        locationPermissionService.requestPermission()
        basicNetModel = await networkService.getBasicNetModel()
        return basicNetModel
    }
}
