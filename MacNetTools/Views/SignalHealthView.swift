import SwiftUI

struct SignalHealthView: View {
    let health: SignalHealth
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.custom(kMonoFontName, size: kSpacing))

            Text(health.label)
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(health.color.opacity(0.2))
                .foregroundStyle(health.color)
                .clipShape(Capsule())
        }
    }
}
