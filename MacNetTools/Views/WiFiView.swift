import SwiftUI

struct WiFiView: View {
    @State private var viewModel = WiFiViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if let model = viewModel.wiFiModel {
                InfoRow(label: "SSID", value: model.ssid)
                InfoRow(label: "BSSID", value: model.connectedBssid)
            } else {
                ContentUnavailableView("No WiFi Data", systemImage: "wifi.slash")
            }
            
            Button("Update") {
                viewModel.updateWiFi()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(minWidth: 300) // Good practice for macOS windows
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
