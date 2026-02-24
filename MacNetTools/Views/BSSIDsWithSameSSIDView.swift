import CoreWLAN
import Foundation
import SwiftUI

struct BSSIDsWithSameSSIDView: View {
    var viewModel: WiFiViewModel
    @State private var isSaved = false

    private var bssidsWithVendors: [String] {
        viewModel.wiFiModel?.availableBssidsWithVendors ?? []
    }

    private var joinedText: String {
        bssidsWithVendors.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
            // Header
            HStack {
                if let ssid = viewModel.wiFiModel?.ssid {
                    Text("BSSIDs for \"\(ssid)\"")
                        .font(.headline)
                } else {
                    Text("No SSID detected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !bssidsWithVendors.isEmpty {
                    CopyButton(
                        text: joinedText,
                        helpText:
                            "Copy all BSSIDs and related info to clipboard"
                    )
                    Button {
                        saveLogToDesktop(
                            content: joinedText,
                            prefix:
                                "BSSIDs_\(viewModel.wiFiModel?.ssid ?? "unknown")"
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
                    .help(
                        "Save all BSSIDs and related info as a .log file on your Desktop"
                    )
                    .controlSize(.small)
                }
            }

            // Scrollable content
            if bssidsWithVendors.isEmpty {
                Text("No BSSIDs detected for this SSID")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.top, 6)
            } else {
                MonoScrollView(lines: bssidsWithVendors)
                    .frame(minHeight: 100, maxHeight: 250)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    BSSIDsWithSameSSIDView(viewModel: WiFiViewModel())
}
