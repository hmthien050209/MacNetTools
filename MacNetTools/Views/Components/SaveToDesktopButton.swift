import SwiftUI

struct SaveToDesktopButton: View {
  let content: String
  let prefix: String
  var isDisabled: Bool = false
  var helpText: String = "Save as a .log file on your Desktop"

  @State private var isSaved = false

  var body: some View {
    Button {
      saveLogToDesktop(content: content, prefix: prefix)
      flashFeedback($isSaved)
    } label: {
      Label(
        isSaved ? "Saved!" : "Save to Desktop",
        systemImage: isSaved
          ? "checkmark.circle.fill"
          : "square.and.arrow.down"
      )
      .contentTransition(.symbolEffect(.replace))
    }
    .disabled(isDisabled || isSaved)
    .help(helpText)
    .controlSize(.small)
  }
}
