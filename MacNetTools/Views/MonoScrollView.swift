import SwiftUI

/// A styled scrollable panel that renders a list of plain-text lines using the
/// app's monospace font.  Pass `scrollTrigger` (e.g. `lines.count`) to
/// automatically scroll to the bottom whenever new lines are appended.
struct MonoScrollView: View {
    let lines: [String]
    var scrollTrigger: Int? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.custom(kMonoFontName, size: kMonoFontSize))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .onChange(of: scrollTrigger) { _, _ in
                if let last = lines.indices.last {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = lines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
        .background(.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2))
        )
    }
}
