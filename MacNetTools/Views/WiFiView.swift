import SwiftUI

struct WiFiView: View {
    @State private var viewModel = WiFiViewModel()
    var logViewModel: LogViewModel?
    
    var body: some View {
        VStack(spacing: 20) {
            if let model = viewModel.wiFiModel {
                InfoRow(label: "SSID", value: model.ssid)
                InfoRow(label: "BSSID", value: model.connectedBssid)
                InfoRow(label: "Interface", value: model.interfaceName ?? kUnknown)
                InfoRow(label: "Channel", value: "\(model.channel?.channelNumber ?? 0)")
                InfoRow(label: "Security", value: String(describing: model.security))
                InfoRow(label: "RSSI / Noise", value: "\(model.rssi) / \(model.noise) dBm")
                InfoRow(label: "SNR", value: "\(model.signalNoiseRatio) dB")
                InfoRow(label: "TX Rate", value: "\(Int(model.txRateMbps)) Mbps")
            } else {
                ContentUnavailableView("No WiFi Data", systemImage: "wifi.slash")
            }
            
            Button("Update") {
                let previous = viewModel.wiFiModel
                if let model = viewModel.updateWiFi() {
                    if let previous, previous.ssid != model.ssid {
                        logViewModel?.append("SSID changed to \(model.ssid)")
                    }
                    if let previous, previous.connectedBssid != model.connectedBssid {
                        logViewModel?.append("BSSID changed to \(model.connectedBssid)")
                    }
                    logViewModel?.append("WiFi details refreshed")
                } else {
                    logViewModel?.append("Failed to fetch WiFi information")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: 450)
    }
}

// Helper view to keep the main body clean and avoid "Optional(...)" text
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .fontWeight(.bold)
            Spacer()
            Text(value)
                .textSelection(.enabled) // Allows users to copy the BSSID
        }
    }
}

#Preview {
    WiFiView()
}
