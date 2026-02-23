import SwiftUI

struct LogView: View {
    var logViewModel: LogViewModel
    @State private var searchText = ""
    @State private var isSaved = false

    var body: some View {
        let filtered = logViewModel.filteredEntries(searchText: searchText)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activity Log")
                        .font(.headline)
                    Spacer()
                    Button("Clear logs") {
                        logViewModel.clear()
                    }
                    .controlSize(.small)
                }

                HStack {
                    TextField("Filter...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                    Button("Clear filter") {
                        searchText = ""
                    }
                    .controlSize(.small)
                }

                HStack {
                    Spacer()
                    Text("(Will exclude filters)")
                        .font(.caption)
                    CopyButton(
                        text: logText,
                        isDisabled: filtered.isEmpty,
                        helpText: "Copy full log to clipboard"
                    )
                    Button {
                        saveLogToDesktop(
                            content: logText,
                            prefix: "MacNetTools"
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
                    .disabled(filtered.isEmpty)
                    .help("Save full log as a .log file on your Desktop")
                    .controlSize(.small)
                }
            }

            MonoScrollView(lines: filtered.map(\.message), scrollTrigger: filtered.count)
        }
        .frame(
            minWidth: 400,
            maxWidth: .infinity,
            maxHeight: 400,
            alignment: .topLeading
        )
    }

    /// All log entries joined into a single string for export.
    private var logText: String {
        logViewModel.entries.map { $0.message }.joined(separator: "\n")
    }
}

#Preview {
    LogView(logViewModel: LogViewModel())
}
