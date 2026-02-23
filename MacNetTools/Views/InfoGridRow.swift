import SwiftUI

/// A labeled key-value row for display inside a `Grid`.
struct InfoGridRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Text(value)
                .font(.custom(kMonoFontName, size: kSpacing))
                .frame(maxWidth: .infinity, alignment: .leading)
                // Allow the text to grow vertically but not horizontally
                .fixedSize(horizontal: false, vertical: true)
                // Ensure multi-line alignment is consistent
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }
}
