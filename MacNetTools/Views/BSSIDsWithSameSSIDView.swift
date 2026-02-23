import CoreWLAN
import Foundation
import SwiftUI

private struct BSSIDEntry: Identifiable, Hashable {
    let id = UUID()
    let bssid: String
}

struct BSSIDsWithSameSSIDView: View {
    var viewModel: WiFiViewModel

    @State private var isCopied = false

    private var entries: [BSSIDEntry] {
        viewModel.wiFiModel?.availableBssids.map { BSSIDEntry(bssid: $0) } ?? []
    }

    private var joinedText: String {
        entries.map(\.bssid).joined(separator: "\n")
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

                if !entries.isEmpty {
                    Button {
                        copyToClipboard(joinedText)
                        flashFeedback($isCopied)
                    } label: {
                        Label(
                            isCopied ? "Copied!" : "Copy All",
                            systemImage: isCopied
                                ? "checkmark.circle.fill"
                                : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundStyle(isCopied ? .secondary : .primary)
                    .disabled(isCopied)
                    .controlSize(.small)
                    .help("Copy all BSSIDs to clipboard")
                }
            }

            // Scrollable content
            if entries.isEmpty {
                Text("No other BSSIDs detected for this SSID")
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.top, 6)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(entries) { entry in
                                Text(entry.bssid)
                                    .font(
                                        .custom(
                                            kMonoFontName,
                                            size: kMonoFontSize
                                        )
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .textSelection(.enabled)
                                    .id(entry.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .onAppear {
                            if let last = entries.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(minHeight: 100, maxHeight: 250)
                .background(.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview {
    BSSIDsWithSameSSIDView(viewModel: WiFiViewModel())
}
