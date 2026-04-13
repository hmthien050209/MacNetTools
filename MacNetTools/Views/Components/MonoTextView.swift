import AppKit
import SwiftUI

struct MonoTextView: NSViewRepresentable {
  let lines: [String]
  var scrollTrigger: Int? = nil
  var isTerminalStyle: Bool = false
  var maxLines: Int = 500

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    guard let textView = scrollView.documentView as? NSTextView else {
      return scrollView
    }

    textView.font = NSFont(name: kMonoFontName, size: kMonoFontSize)
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.drawsBackground = true
    textView.backgroundColor = isTerminalStyle ? NSColor.black : NSColor.controlBackgroundColor
    if isTerminalStyle {
      textView.textColor = NSColor.systemGreen
    }
    textView.textContainerInset = NSSize(width: 8, height: 8)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.widthTracksTextView = true

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    let clipped = lines.suffix(maxLines)
    let content = clipped.joined(separator: "\n")
    textView.string = content

    if !content.isEmpty {
      let range = NSRange(location: content.utf16.count, length: 0)
      textView.scrollRangeToVisible(range)
    }
  }
}
