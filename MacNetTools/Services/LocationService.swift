import CoreLocation
import Foundation

/// A Service responsible solely for handling the "Permission Gate"
/// required for Network Metadata access.
@MainActor
final class LocationPermissionService: NSObject {
    private let manager = CLLocationManager()

    // Use a simple continuation or a state property to notify the app
    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    var isAuthorizedForNetworkMetadata: Bool {
        authorizationStatus == .authorized
            || authorizationStatus == .authorizedAlways
    }
}

extension LocationPermissionService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus

        // Post a notification or update a central state if status changes
        if isAuthorizedForNetworkMetadata {
            print("Ready to read SSID/BSSID")
        }
    }
}
