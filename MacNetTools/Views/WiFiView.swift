import CoreWLAN
import SwiftUI

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
                    InfoGridRow(
                        label: "Interface",
                        value: model.interfaceName ?? kUnknown
                    )

                    InfoGridRow(label: "SSID", value: model.ssid)

                    InfoGridRow(label: "BSSID", value: model.connectedBssid)

                    InfoGridRow(label: "Vendor", value: model.vendor)

                    InfoGridRow(
                        label: "PHY mode",
                        value: model.phyMode.description
                    )

                    InfoGridRow(
                        label: "Channel",
                        value: model.channel?.detailedDescription ?? kUnknown
                    )

                    if let sco = model.secondaryChannelOffset {
                        InfoGridRow(
                            label: "Secondary Channel Offset",
                            value: sco
                        )

                        InfoGridRow(
                            label: "Secondary Channels",
                            value: model.secondaryChannels.map { String($0) }
                                .joined(separator: ", ")
                        )
                    }

                    InfoGridRow(label: "RSSI") {
                        SignalHealthPatch(
                            health: SignalHealth.from(rssi: model.rssi),
                            value: "\(model.rssi) dBm"
                        )
                    }

                    InfoGridRow(label: "Noise", value: "\(model.noise) dBm")

                    InfoGridRow(label: "SNR") {
                        SignalHealthPatch(
                            health: SignalHealth.from(
                                snr: model.signalNoiseRatio
                            ),
                            value: "\(model.signalNoiseRatio) dB"
                        )
                    }

                    InfoGridRow(
                        label: "TX Rate",
                        value: "\(Int(model.txRateMbps)) Mbps"
                    )

                    InfoGridRow(label: "Country", value: model.countryCode)

                    InfoGridRow(
                        label: "Security",
                        value: model.security.description
                    )

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
}

#Preview {
    WiFiView(viewModel: WiFiViewModel())
}
