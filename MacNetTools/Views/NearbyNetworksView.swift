import SwiftUI

struct NearbyNetworksView: View {
    var viewModel: WiFiViewModel

    private var nearbyNetworksWithMetadata: [String] {
        viewModel.wiFiModel?.nearbyNetworks ?? []
    }

    private var joinedText: String {
        nearbyNetworksWithMetadata.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
            // Header
            HStack {
                Text("Nearby Networks")
                    .font(.headline)

                Spacer()

                if !nearbyNetworksWithMetadata.isEmpty {
                    CopyButton(
                        text: joinedText,
                        helpText:
                            "Copy all nearby networks and related info to clipboard"
                    )
                    SaveToDesktopButton(
                        content: joinedText,
                        prefix:
                            "NearbyNetworks",
                        helpText:
                            "Save all nearby networks and related info as a .log file on your Desktop"
                    )
                }
            }

            // Scrollable content
            if nearbyNetworksWithMetadata.isEmpty {
                Text("No nearby network is detected")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.top, 6)
            } else {
                MonoScrollView(lines: nearbyNetworksWithMetadata)
                    .frame(minHeight: 100, maxHeight: 250)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NearbyNetworksView(viewModel: WiFiViewModel())
}
