import SwiftUI

/// A labeled key-value row for display inside a `Grid`.
struct InfoGridRow<ValueContent: View>: View {
    let label: String
    let valueView: ValueContent

    // Convenience initializer for plain string values
    init(label: String, value: String) where ValueContent == Text {
        self.label = label
        // .font() on a Text view returns a Text view, satisfying ValueContent == Text
        self.valueView = Text(value)
            .font(.custom(kMonoFontName, size: kSpacing))
    }

    // Initializer for custom views (like SignalHealthPatch)
    init(label: String, @ViewBuilder valueView: () -> ValueContent) {
        self.label = label
        self.valueView = valueView()
    }

    var body: some View {
        GridRow(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
                .gridColumnAlignment(.leading)

            valueView
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
    }
}
