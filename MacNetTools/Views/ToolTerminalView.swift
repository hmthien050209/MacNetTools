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
                                .font(
                                    .custom(kMonoFontName, size: kMonoFontSize)
                                )
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
                        copyToClipboard(fullLog)
                        flashFeedback($isCopied)
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
                        saveLogToDesktop(content: fullLog, prefix: title)
                        flashFeedback($isSaved)
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
}
