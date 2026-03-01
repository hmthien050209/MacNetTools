import SwiftUI

/// A button that copies `text` to the clipboard and briefly shows "Copied!" feedback.
struct CopyButton: View {
    let text: String
    var isDisabled: Bool = false
    var helpText: String = "Copy all to clipboard"

    @State private var isCopied = false

    var body: some View {
        Button {
            copyToClipboard(text)
            flashFeedback($isCopied)
        } label: {
            Label(
                isCopied ? "Copied!" : "Copy All",
                systemImage: isCopied ? "checkmark.circle.fill" : "doc.on.doc"
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(isCopied ? .secondary : .primary)
        .disabled(isDisabled || isCopied)
        .controlSize(.small)
        .help(helpText)
    }
}
