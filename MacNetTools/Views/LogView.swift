import SwiftUI

struct LogView: View {
    var logViewModel: LogViewModel
    @State private var searchText = ""
    @State private var isCopied = false
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
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(
                            isCopied ? "Copied!" : "Copy All",
                            systemImage: isCopied
                                ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundStyle(isCopied ? .secondary : .primary)
                    .disabled(filtered.isEmpty || isCopied)
                    .help("Copy full log to clipboard")
                    .controlSize(.small)
                    Button {
                        saveToDesktop()
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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(filtered) { entry in
                            Text(entry.message)
                                .font(.custom(kMonoFontName, size: 11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .onChange(of: filtered.count) { _, _ in
                        if let last = filtered.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2))
            )
        }
        .frame(
            minWidth: 400,
            maxWidth: .infinity,
            maxHeight: 400,
            alignment: .topLeading
        )
    }

    private func copyToClipboard() {
        // Handle Clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(joinLog(), forType: .string)

        // Update UI State
        withAnimation(.spring()) {
            isCopied = true
        }

        // Revert after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isCopied = false
            }
        }
    }

    private func saveToDesktop() {
        // Prepare sanitized file name
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        var timestamp = dateFormatter.string(from: Date())
        timestamp =
            timestamp
            .replacingOccurrences(
                of: "[:.]",
                with: "",
                options: .regularExpression
            )
        let filename = "MacNetTools_\(timestamp).log"

        // Build Desktop file URL
        let desktopURL = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        // Write file
        do {
            try joinLog().write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save log: \(error)")
        }

        // Update UI State
        withAnimation(.spring()) {
            isSaved = true
        }

        // Revert after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isSaved = false
            }
        }
    }

    private func joinLog() -> String {
        return logViewModel.entries.map { $0.message }.joined(separator: "\n")
    }
}

#Preview {
    LogView(logViewModel: LogViewModel())
}
