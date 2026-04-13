import SwiftUI

struct MonoScrollView: View {
  let lines: [String]
  var scrollTrigger: Int? = nil

  var body: some View {
    MonoTextView(lines: lines, scrollTrigger: scrollTrigger)
      .frame(minHeight: 100, maxHeight: .infinity)
      .background(.gray.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray.opacity(0.2))
      )
  }
}
