import SwiftUI

struct NearbyNetworksView: View {
  var viewModel: WiFiViewModel

  private var nearbyNetworks: [NearbyWiFiNetwork] {
    viewModel.wiFiModel?.nearbyNetworks ?? []
  }

  @State private var joinedText: String = ""

  var body: some View {
    SSIDNetworkTreeView(
      title: "Nearby Networks",
      networks: nearbyNetworks,
      joinedText: joinedText,
      savePrefix: "NearbyNetworks"
    )
    .task(id: nearbyNetworks) {
      joinedText = nearbyNetworks.map { network in
        let status = network.isConnected ? "(Connected) " : ""
        return
          "\(status)SSID: \(network.ssid), BSSID: \(network.bssid), Vendor: \(network.vendor), Ch: \(network.channel), RSSI: \(network.rssi)dBm"
      }.joined(separator: "\n")
    }
  }
}

#Preview {
  NearbyNetworksView(viewModel: WiFiViewModel())
}
