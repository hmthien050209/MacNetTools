import SwiftUI

enum SignalHealth {
    case excellent, good, fair, poor, unusable

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unusable: return "Unusable"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .mint
        case .fair: return .yellow
        case .poor: return .orange
        case .unusable: return .red
        }
    }
}

struct SignalHealthPatch: View {
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
