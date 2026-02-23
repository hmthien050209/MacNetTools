import CoreWLAN
import Foundation
import SwiftUI

struct BSSIDsWithSameSSIDView: View {
    var viewModel: WiFiViewModel
    @State private var isSaved = false

    private var bssids: [String] {
        viewModel.wiFiModel?.availableBssids ?? []
    }

    private var joinedText: String {
        bssids.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let ssid = viewModel.wiFiModel?.ssid {
                    Text("Other BSSIDs for \"\(ssid)\"")
                        .font(.headline)
                        .bold()
                } else {
                    Text("No SSID detected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !bssids.isEmpty {
                    CopyButton(
                        text: joinedText,
                        helpText: "Copy all BSSIDs to clipboard"
                    )
                    Button {
                        saveLogToDesktop(
                            content: joinedText,
                            prefix: "BSSIDs_\(viewModel.wiFiModel?.ssid ?? "unknown")"
                        )
                        flashFeedback($isSaved)
                    } label: {
                        Label(
                            isSaved ? "Saved!" : "Save to Desktop",
                            systemImage: isSaved
                                ? "checkmark.circle.fill"
                                : "square.and.arrow.down"
                        )
                    }
                    .help("Save all BSSIDs as a .log file on your Desktop")
                    .controlSize(.small)
                }
            }

            // Scrollable content
            if bssids.isEmpty {
                Text("No other BSSIDs detected for this SSID")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.top, 6)
            } else {
                MonoScrollView(lines: bssids)
                    .frame(minHeight: 100, maxHeight: 250)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    BSSIDsWithSameSSIDView(viewModel: WiFiViewModel())
}
