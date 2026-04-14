import AppKit
import SwiftUI

func copyToClipboard(_ text: String) {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  pasteboard.setString(text, forType: .string)
}

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
  guard
    let desktopURL = FileManager.default.urls(
      for: .desktopDirectory,
      in: .userDomainMask
    ).first
  else {
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

func flashFeedback(_ binding: Binding<Bool>, delay: Double = 2.0) {
  withAnimation(.spring()) { binding.wrappedValue = true }
  DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
    withAnimation { binding.wrappedValue = false }
  }
}
