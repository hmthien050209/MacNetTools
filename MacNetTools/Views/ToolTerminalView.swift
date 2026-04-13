import SwiftUI

struct ToolTerminalView: View {
  let sessionId: String
  @Environment(\.dismiss) private var dismiss
  private let sessionManager = ToolSessionManager.shared

  @State private var outputLines: [String] = []
  @State private var isRunning = true

  private var session: ToolSession? {
    sessionManager.sessions[sessionId]
  }

  private var fullLog: String {
    outputLines.joined(separator: "\n")
  }

  var body: some View {
    NavigationStack {
      MonoTextView(lines: outputLines, isTerminalStyle: true)
        .textSelection(.enabled)
        .frame(
          minWidth: 600,
          idealWidth: 700,
          minHeight: 400,
          idealHeight: 500
        )
        .navigationTitle(session?.name ?? "Tool Terminal")
        .toolbar {
          ToolbarItem(placement: .automatic) {
            if isRunning {
              Button(action: {
                session?.stop()
                isRunning = false
              }) {
                Label("Stop", systemImage: "stop.fill")
                  .foregroundColor(.red)
              }
              .help("Interrupt the running command")
            }
          }

          ToolbarItem(placement: .automatic) {
            CopyButton(
              text: fullLog,
              isDisabled: outputLines.isEmpty,
              helpText: "Copy full log to clipboard"
            )
          }

          ToolbarItem(placement: .automatic) {
            SaveToDesktopButton(
              content: fullLog,
              prefix: session?.name ?? "Tool",
              isDisabled: outputLines.isEmpty,
              helpText: "Save full log as a .log file on your Desktop"
            )
          }

          ToolbarItem(placement: .automatic) {
            Button("Done") {
              dismiss()
            }
            .keyboardShortcut(.defaultAction)
          }
        }
    }
    .task {
      guard let stream = session?.stream else { return }
      for await line in stream {
        outputLines.append(line)
      }
      isRunning = false
    }
    .onDisappear {
      sessionManager.removeSession(id: sessionId)
    }
  }
}
