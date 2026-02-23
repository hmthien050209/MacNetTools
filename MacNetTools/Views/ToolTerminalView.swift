import SwiftUI

struct ToolTerminalView: View {
    let title: String
    let stream: AsyncStream<String>
    var onDismiss: () -> Void

    @State private var outputLines: [String] = []
    @State private var isCopied = false
    @State private var isSaved = false

    private var fullLog: String {
        outputLines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(outputLines.indices, id: \.self) { i in
                            Text(outputLines[i])
                                .font(.custom(kMonoFontName, size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .textSelection(.enabled)
                .background(Color.black)
                .onChange(of: outputLines.count) {
                    proxy.scrollTo(outputLines.indices.last)
                }
            }
            .frame(
                minWidth: 600,
                idealWidth: 700,
                minHeight: 400,
                idealHeight: 500
            )
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .automatic) {
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
                    .disabled(outputLines.isEmpty || isCopied)
                    .help("Copy full log to clipboard")
                }

                ToolbarItem(placement: .automatic) {
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
                    .disabled(outputLines.isEmpty)
                    .help("Save full log as a .log file on your Desktop")
                }

                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .task {
            for await line in stream {
                outputLines.append(line)
            }
        }
        .onDisappear {
            onDismiss()
        }
    }

    private func copyToClipboard() {
        // Handle Clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullLog, forType: .string)

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
        let sanitizedTitle = title.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let filename = "\(sanitizedTitle)_\(timestamp).log"

        // Build Desktop file URL
        let desktopURL = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first!
        let fileURL = desktopURL.appendingPathComponent(filename)

        // Write file
        do {
            try fullLog.write(to: fileURL, atomically: true, encoding: .utf8)
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
}
