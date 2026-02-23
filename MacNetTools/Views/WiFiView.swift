import SwiftUI
import CoreWLAN

struct WiFiView: View {
    var viewModel: WiFiViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WiFi")
                .font(.headline)
            
            if let model = viewModel.wiFiModel {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    infoRow("SSID", model.ssid)
                    infoRow("BSSID", model.connectedBssid)
                    infoRow("Interface", model.interfaceName ?? kUnknown)
                    infoRow("Channel", model.channel.map { "\($0.channelNumber)" } ?? kUnknown)
                    infoRow("Security", String(describing: model.security))
                    infoRow("RSSI", "\(model.rssi) dBm")
                    infoRow("Noise", "\(model.noise) dBm")
                    infoRow("SNR", "\(model.signalNoiseRatio) dB")
                    infoRow("TX Rate", "\(Int(model.txRateMbps)) Mbps")
                    infoRow("Country", model.countryCode)
                }
            } else {
                Text("No WiFi data")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .fontWeight(.semibold)
            Text(value)
                .font(.custom(kMonoFontName, size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    WiFiView(viewModel: WiFiViewModel())
}
