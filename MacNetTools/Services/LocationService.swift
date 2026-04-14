import CoreLocation
import Foundation

@MainActor
final class LocationPermissionService: NSObject {
  private let manager = CLLocationManager()

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

    if isAuthorizedForNetworkMetadata {
      print("Ready to read SSID/BSSID")
    }
  }
}
