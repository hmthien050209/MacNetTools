import SwiftUI

struct WiFiNetworkTable: View {
    var title: String
    var networks: [NearbyWiFiNetwork]
    var joinedText: String
    var savePrefix: String

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                if !networks.isEmpty {
                    CopyButton(
                        text: joinedText,
                        helpText: "Copy all network info to clipboard"
                    )
                    SaveToDesktopButton(
                        content: joinedText,
                        prefix: savePrefix,
                        helpText:
                            "Save all network info as a .log file on your Desktop"
                    )
                }
            }

            // Table content
            if networks.isEmpty {
                Text("No network is detected")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.top, 6)
            } else {
                Table(networks) {
                    TableColumn("SSID") { network in
                        HStack {
                            Text(network.ssid)
                            if network.isConnected {
                                Text("(Connected)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    TableColumn("BSSID", value: \.bssid)
                    TableColumn("Vendor", value: \.vendor)
                    TableColumn("PHY", value: \.phyMode)
                    TableColumn("Band", value: \.band)
                    TableColumn("Channel") { network in
                        Text("\(network.channel)")
                    }
                    TableColumn("RSSI") { network in
                        Text("\(network.rssi) dBm")
                    }
                }
                .frame(minHeight: 200, maxHeight: 400)
                .font(.custom(kMonoFontName, size: kMonoFontSize))
                .tableStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
