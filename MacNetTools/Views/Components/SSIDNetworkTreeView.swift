import SwiftUI

/// Hierarchical row model for the SSID-grouped network table.
enum NetworkTableRow: Identifiable {
  case group(SSIDGroup)
  case network(NearbyWiFiNetwork)

  var id: String {
    switch self {
    case .group(let g): return g.ssid
    case .network(let n): return n.bssid
    }
  }

  var ssid: String {
    switch self {
    case .group(let g): return g.ssid
    case .network(let n): return n.ssid
    }
  }

  var bssid: String {
    switch self {
    case .group: return ""
    case .network(let n): return n.bssid
    }
  }

  var vendor: String {
    switch self {
    case .group: return ""
    case .network(let n): return n.vendor
    }
  }

  var phyMode: String {
    switch self {
    case .group: return ""
    case .network(let n): return n.phyMode
    }
  }

  var band: String {
    switch self {
    case .group: return ""
    case .network(let n): return n.band
    }
  }

  var channel: Int {
    switch self {
    case .group: return 0
    case .network(let n): return n.channel
    }
  }

  var rssi: Int {
    switch self {
    case .group(let g): return g.strongestRssi
    case .network(let n): return n.rssi
    }
  }

  var isConnected: Bool {
    switch self {
    case .group(let g): return g.hasConnectedNetwork
    case .network(let n): return n.isConnected
    }
  }

  var meanRssi: Double {
    switch self {
    case .group(let g): return g.meanRssi
    case .network: return Double(rssi)
    }
  }

  var bssidCount: Int {
    switch self {
    case .group(let g): return g.networks.count
    case .network: return 0
    }
  }
}

struct SSIDNetworkTreeView: View {
  var title: String
  var networks: [NearbyWiFiNetwork]
  var joinedText: String
  var savePrefix: String

  private var tableRows: [NetworkTableRow] {
    networks.groupedBySSID().flatMap { group -> [NetworkTableRow] in
      [.group(group)] + group.networks.map { NetworkTableRow.network($0) }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: kSpacing) {
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

      if networks.isEmpty {
        Text("No network is detected")
          .foregroundStyle(.secondary)
          .font(.headline)
          .padding(.top, 6)
      } else {
        Table(tableRows) {
          TableColumn("SSID") { row in
            HStack(spacing: 4) {
              switch row {
              case .group(let g):
                Image(systemName: "wifi")
                  .foregroundStyle(
                    g.hasConnectedNetwork ? .blue : .secondary
                  )
                Text(g.ssid.isEmpty ? "<Hidden Network>" : g.ssid)
                  .fontWeight(.semibold)
                if g.hasConnectedNetwork {
                  Text("(Connected)")
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                Text("\(g.networks.count) BSSID\(g.networks.count == 1 ? "" : "s")")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              case .network(let n):
                if n.isConnected {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                }
                Text(n.ssid)
              }
            }
          }
          .width(min: 150, ideal: 200, max: 300)

          TableColumn("BSSID", value: \.bssid)
            .width(min: 120, ideal: 130, max: 160)

          TableColumn("Vendor", value: \.vendor)
            .width(min: 100, ideal: 150, max: 250)

          TableColumn("PHY") { row in
            if case .network(let n) = row {
              Text(n.phyMode)
            }
          }
          .width(min: 150, ideal: 200, max: 300)

          TableColumn("Band") { row in
            if case .network(let n) = row {
              Text("\(n.band) Ch \(n.channel)")
            }
          }
          .width(min: 80, ideal: 110, max: 140)

          TableColumn("RSSI") { row in
            switch row {
            case .group:
              Text("\(row.rssi) dBm (mean)")
                .foregroundStyle(rssiColor(row.rssi))
                .fontWeight(.semibold)
            case .network:
              Text("\(row.rssi) dBm")
                .foregroundStyle(rssiColor(row.rssi))
            }
          }
          .width(min: 120, ideal: 140, max: 180)
        }
        .frame(minHeight: 200, maxHeight: 400)
        .font(.custom(kMonoFontName, size: kMonoFontSize))
        .tableStyle(.inset)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private func rssiColor(_ rssi: Int) -> Color {
  switch rssi {
  case -50...0:
    return .green
  case -60 ..< -50:
    return .yellow
  case -70 ..< -60:
    return .orange
  default:
    return .red
  }
}
