import SwiftUI

/// A labeled key-value row for display inside a `Grid`.
struct InfoGridRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .fontWeight(.semibold)
            Text(value)
                .font(.custom(kMonoFontName, size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
