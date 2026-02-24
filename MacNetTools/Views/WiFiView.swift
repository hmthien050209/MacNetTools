import CoreWLAN
import SwiftUI

enum SignalHealth {
    case excellent, good, fair, poor, unusable

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unusable: return "Unusable"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .mint
        case .fair: return .yellow
        case .poor: return .orange
        case .unusable: return .red
        }
    }
}

struct WiFiView: View {
    var viewModel: WiFiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WiFi")
                .font(.headline)

            if let model = viewModel.wiFiModel {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: 8,
                    verticalSpacing: 6
                ) {
                    InfoGridRow(label: "SSID", value: model.ssid)
                    InfoGridRow(label: "BSSID", value: model.connectedBssid)
                    InfoGridRow(label: "Vendor", value: model.vendor)
                    InfoGridRow(
                        label: "Interface",
                        value: model.interfaceName ?? kUnknown
                    )
                    InfoGridRow(
                        label: "Channel",
                        value: channelDescription(model.channel)
                    )
                    InfoGridRow(
                        label: "Security",
                        value: readableSecurity(model.security)
                    )

                    InfoGridRow(label: "RSSI") {
                        SignalHealthView(
                            health: health(forRssi: model.rssi),
                            value: "\(model.rssi) dBm"
                        )
                    }

                    InfoGridRow(label: "Noise", value: "\(model.noise) dBm")

                    InfoGridRow(label: "SNR") {
                        SignalHealthView(
                            health: health(forSnr: model.signalNoiseRatio),
                            value: "\(model.signalNoiseRatio) dB"
                        )
                    }

                    InfoGridRow(
                        label: "TX Rate",
                        value: "\(Int(model.txRateMbps)) Mbps"
                    )
                    InfoGridRow(label: "Country", value: model.countryCode)
                    InfoGridRow(
                        label: "Encryption",
                        value: model.encryptionInfo
                    )
                }
            } else {
                Text("No WiFi data")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func readableSecurity(_ security: CWSecurity) -> String {
        switch security {
        case .none: return "Open"
        case .WEP: return "WEP"
        case .wpaPersonal: return "WPA Personal"
        case .wpaPersonalMixed: return "WPA/WPA2 Personal"
        case .wpa2Personal: return "WPA2 Personal"
        case .personal: return "Personal"
        case .dynamicWEP: return "Dynamic WEP"
        case .wpaEnterprise: return "WPA Enterprise"
        case .wpaEnterpriseMixed: return "WPA/WPA2 Enterprise"
        case .wpa2Enterprise: return "WPA2 Enterprise"
        case .enterprise: return "Enterprise"
        case .wpa3Personal: return "WPA3 Personal"
        case .wpa3Enterprise: return "WPA3 Enterprise"
        case .wpa3Transition: return "WPA2/WPA3 Personal"
        case .OWE: return "OWE (Enhanced Open)"
        case .oweTransition: return "OWE Transition"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Viet Nam regulatory standard mapping

    private func channelDescription(_ channel: CWChannel?) -> String {
        guard let channel else { return "Unknown" }

        // Use CoreWLAN's built-in band detection
        let band: String
        switch channel.channelBand {
        case .band2GHz:
            band = "2.4 GHz"
        case .band5GHz:
            band = "5 GHz"
        case .band6GHz:
            band = "6 GHz"
        case .bandUnknown:
            band = "Unknown"
        @unknown default:
            band = "Unknown"
        }

        let width = bandwidth(for: channel.channelWidth)
        let unii = uniiBand(for: channel.channelNumber, band: band)
        let dfsStatus = isDFS(for: channel.channelNumber) ? "DFS" : "Non-DFS"

        return
            "\(channel.channelNumber) (\(band), \(width), \(unii), \(dfsStatus))"
    }

    private func uniiBand(for channel: Int, band: String) -> String {
        switch band {
        case "2.4 GHz":
            return "ISM"
        case "5 GHz":
            switch channel {
            case 36...48: return "UNII-1"
            case 52...64: return "UNII-2A"
            case 100...140: return "UNII-2C"  // Note: 144 is often excluded in ETSI/VN
            case 149...165: return "UNII-3"
            default: return "Unknown"
            }
        case "6 GHz":
            switch channel {
            // Vietnam is currently prioritizing the lower 6GHz band
            case 1...93: return "UNII-5"
            default: return "6GHz (Other)"
            }
        default:
            return "Unknown"
        }
    }

    private func isDFS(for channel: Int) -> Bool {
        // Standard DFS ranges for Region 3 / Vietnam
        return (52...64).contains(channel) || (100...140).contains(channel)
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

    // MARK: - Health Calculation

    private func health(forRssi rssi: Int) -> SignalHealth {
        // Enterprise surveying standards (Cisco/Aruba/Ekahau)
        if rssi >= -55 { return .excellent }
        if rssi >= -67 { return .good }  // -67 dBm is the VoIP/Roaming boundary
        if rssi >= -75 { return .fair }
        if rssi >= -85 { return .poor }
        return .unusable
    }

    private func health(forSnr snr: Int) -> SignalHealth {
        // Tuned for modern 802.11ax/be MCS rate requirements
        if snr >= 35 { return .excellent }  // Needed for 1024+ QAM
        if snr >= 25 { return .good }
        if snr >= 15 { return .fair }
        if snr >= 10 { return .poor }
        return .unusable
    }
}

#Preview {
    WiFiView(viewModel: WiFiViewModel())
}
