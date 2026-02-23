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
                    infoRow("Channel", channelDescription(model.channel))
                    infoRow("Security", readableSecurity(model.security))
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
    
    private func readableSecurity(_ security: CWSecurity) -> String {
        switch security {
        case .none:
            return "Open"
        case .WEP:
            return "WEP"
        case .wpaPersonal:
            return "WPA Personal"
        case .wpaPersonalMixed:
            return "WPA/WPA2 Personal"
        case .wpa2Personal:
            return "WPA2 Personal"
        case .personal:
            return "Personal"
        case .dynamicWEP:
            return "Dynamic WEP"
        case .wpaEnterprise:
            return "WPA Enterprise"
        case .wpaEnterpriseMixed:
            return "WPA/WPA2 Enterprise"
        case .wpa2Enterprise:
            return "WPA2 Enterprise"
        case .enterprise:
            return "Enterprise"
        case .wpa3Personal:
            return "WPA3 Personal"
        case .wpa3Enterprise:
            return "WPA3 Enterprise"
        case .wpa3Transition:
            return "WPA2/WPA3 Personal"
        case .OWE:
            return "OWE (Enhanced Open)"
        case .oweTransition:
            return "OWE Transition"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func channelDescription(_ channel: CWChannel?) -> String {
        guard let channel else { return kUnknown }
        let band = frequencyBand(for: channel.channelNumber)
        let width = bandwidth(for: channel.channelWidth)
        return "\(channel.channelNumber) (\(band), \(width))"
    }
    
    private func frequencyBand(for channelNumber: Int) -> String {
        if (1...14).contains(channelNumber) { return "2.4 GHz" }
        if channelNumber >= 183 { return "6 GHz" }
        return "5 GHz"
    }
    
    private func bandwidth(for width: CWChannelWidth) -> String {
        switch width {
        case .width20MHz: return "20 MHz"
        case .width40MHz: return "40 MHz"
        case .width80MHz: return "80 MHz"
        case .width160MHz: return "160 MHz"
        case .widthUnknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    WiFiView(viewModel: WiFiViewModel())
}
