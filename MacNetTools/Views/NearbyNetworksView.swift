import SwiftUI

struct NearbyNetworksView: View {
    var viewModel: WiFiViewModel

    private var nearbyNetworks: [NearbyWiFiNetwork] {
        viewModel.wiFiModel?.nearbyNetworks ?? []
    }

    private var joinedText: String {
        nearbyNetworks.map { network in
            let status = network.isConnected ? "(Connected) " : ""
            return
                "\(status)SSID: \(network.ssid), BSSID: \(network.bssid), Vendor: \(network.vendor), Ch: \(network.channel), RSSI: \(network.rssi)dBm"
        }.joined(separator: "\n")
    }

    var body: some View {
        WiFiNetworkTable(
            title: "Nearby Networks",
            networks: nearbyNetworks,
            joinedText: joinedText,
            savePrefix: "NearbyNetworks"
        )
    }
}

#Preview {
    NearbyNetworksView(viewModel: WiFiViewModel())
}
