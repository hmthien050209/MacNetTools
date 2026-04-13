import CoreWLAN
import Foundation
import SwiftUI

struct BSSIDsWithSameSSIDView: View {
  var viewModel: WiFiViewModel

  private var bssidsWithMetadata: [NearbyWiFiNetwork] {
    viewModel.wiFiModel?.availableBssidsWithVendors ?? []
  }

  @State private var joinedText: String = ""

  var body: some View {
    SSIDNetworkTreeView(
      title: viewModel.wiFiModel?.ssid != nil
        ? "BSSIDs for \"\(viewModel.wiFiModel!.ssid)\""
        : "No SSID detected",
      networks: bssidsWithMetadata,
      joinedText: joinedText,
      savePrefix: "BSSIDs_\(viewModel.wiFiModel?.ssid ?? "unknown")"
    )
    .task(id: bssidsWithMetadata) {
      joinedText = bssidsWithMetadata.map { network in
        let status = network.isConnected ? "(Connected) " : ""
        return
          "\(status)SSID: \(network.ssid), BSSID: \(network.bssid), Vendor: \(network.vendor), Ch: \(network.channel), RSSI: \(network.rssi)dBm"
      }.joined(separator: "\n")
    }
  }
}

#Preview {
  BSSIDsWithSameSSIDView(viewModel: WiFiViewModel())
}
