import AppKit
import SwiftUI

/// Copies `text` to the system clipboard.
func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

/// Saves `content` to a `.log` file on the user's Desktop.
/// The filename is formatted as `<prefix>_<sanitizedTimestamp>.log`.
/// Special characters in `prefix` are replaced with underscores.
func saveLogToDesktop(content: String, prefix: String) {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let timestamp = formatter.string(from: Date())
        .replacingOccurrences(of: "[:.]", with: "", options: .regularExpression)
    let sanitizedPrefix = prefix.replacingOccurrences(
        of: "[^A-Za-z0-9_-]",
        with: "_",
        options: .regularExpression
    )
    let filename = "\(sanitizedPrefix)_\(timestamp).log"
    guard let desktopURL = FileManager.default.urls(
        for: .desktopDirectory,
        in: .userDomainMask
    ).first else {
        print("Failed to locate Desktop directory")
        return
    }
    do {
        try content.write(
            to: desktopURL.appendingPathComponent(filename),
            atomically: true,
            encoding: .utf8
        )
    } catch {
        print("Failed to save log: \(error)")
    }
}

/// Temporarily sets `binding` to `true` with a spring animation, then resets it after `delay` seconds.
func flashFeedback(_ binding: Binding<Bool>, delay: Double = 2.0) {
    withAnimation(.spring()) { binding.wrappedValue = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        withAnimation { binding.wrappedValue = false }
    }
}
