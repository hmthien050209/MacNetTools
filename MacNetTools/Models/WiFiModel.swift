import CoreWLAN

extension Array where Element == NearbyWiFiNetwork {
  func groupedBySSID() -> [SSIDGroup] {
    var groups: [String: [NearbyWiFiNetwork]] = [:]
    for network in self {
      groups[network.ssid, default: []].append(network)
    }
    return groups.map { SSIDGroup(ssid: $0.key, networks: $0.value) }
      .sorted {
        if $0.hasConnectedNetwork != $1.hasConnectedNetwork {
          return $0.hasConnectedNetwork
        }
        return $0.strongestRssi > $1.strongestRssi
      }
  }
}

struct BSSLoadInfo {
  var stationCount: Int
  var channelUtilization: Double
  var availableCapacity: Int
}

struct VendorSpecificIE: Identifiable {
  let id = UUID()
  var oui: String
  var vendorName: String
}

struct NearbyWiFiNetwork: Identifiable, Sendable, Equatable {
  var id: String { bssid }
  var ssid: String
  var bssid: String
  var vendor: String
  var channel: Int
  var band: String
  var phyMode: String
  var rssi: Int
  var isConnected: Bool

  static func == (lhs: NearbyWiFiNetwork, rhs: NearbyWiFiNetwork) -> Bool {
    lhs.bssid == rhs.bssid
      && lhs.ssid == rhs.ssid
      && lhs.vendor == rhs.vendor
      && lhs.channel == rhs.channel
      && lhs.band == rhs.band
      && lhs.phyMode == rhs.phyMode
      && lhs.rssi == rhs.rssi
      && lhs.isConnected == rhs.isConnected
  }
}

struct SSIDGroup: Identifiable, Sendable {
  var id: String { ssid }
  var ssid: String
  var networks: [NearbyWiFiNetwork]

  var strongestRssi: Int {
    networks.map(\.rssi).max() ?? 0
  }

  var meanRssi: Double {
    guard !networks.isEmpty else { return 0 }
    return Double(networks.map(\.rssi).reduce(0, +)) / Double(networks.count)
  }

  var hasConnectedNetwork: Bool {
    networks.contains(where: { $0.isConnected })
  }
}

struct WiFiModel: Equatable {
  var ssid: String
  var connectedBssid: String
  var vendor: String
  var channelDescription: String
  var phyModeDescription: String
  var securityDescription: String
  var rssi: Int
  var noise: Int
  var signalNoiseRatio: Int
  var countryCode: String
  var availableBssidsWithVendors: [NearbyWiFiNetwork]
  var txRateMbps: Double
  var interfaceName: String?
  var encryptionInfo: String
  var bssLoadStationCount: Int
  var bssLoadUtilization: Double
  var bssLoadCapacity: Int
  var vendorSpecificIEs: [VendorSpecificIE]
  var secondaryChannelOffset: String?
  var secondaryChannels: [Int]
  var nearbyNetworks: [NearbyWiFiNetwork]

  static func == (lhs: WiFiModel, rhs: WiFiModel) -> Bool {
    lhs.ssid == rhs.ssid
      && lhs.connectedBssid == rhs.connectedBssid
      && lhs.vendor == rhs.vendor
      && lhs.channelDescription == rhs.channelDescription
      && lhs.phyModeDescription == rhs.phyModeDescription
      && lhs.securityDescription == rhs.securityDescription
      && lhs.rssi == rhs.rssi
      && lhs.noise == rhs.noise
      && lhs.signalNoiseRatio == rhs.signalNoiseRatio
      && lhs.countryCode == rhs.countryCode
      && lhs.txRateMbps == rhs.txRateMbps
      && lhs.interfaceName == rhs.interfaceName
      && lhs.encryptionInfo == rhs.encryptionInfo
      && lhs.bssLoadStationCount == rhs.bssLoadStationCount
      && lhs.bssLoadUtilization == rhs.bssLoadUtilization
      && lhs.bssLoadCapacity == rhs.bssLoadCapacity
      && lhs.secondaryChannelOffset == rhs.secondaryChannelOffset
      && lhs.secondaryChannels == rhs.secondaryChannels
      && lhs.availableBssidsWithVendors == rhs.availableBssidsWithVendors
      && lhs.nearbyNetworks == rhs.nearbyNetworks
  }
}
