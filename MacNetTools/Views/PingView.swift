import SwiftUI

struct PingView: View {
    var viewModel: PingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pings")
                .font(.headline)

            if viewModel.pings.isEmpty {
                Text("No ping data")
                    .foregroundStyle(.secondary)
            } else {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: kSpacing,
                    verticalSpacing: 6
                ) {
                    GridRow {
                        Text("Target").fontWeight(.semibold)
                        Text("Latency").fontWeight(.semibold)
                    }
                    .padding(.bottom, 2)

                    ForEach(viewModel.pings) { ping in
                        GridRow {
                            Text(ping.target)
                                .font(
                                    .custom(kMonoFontName, size: kMonoFontSize)
                                )
                            Text(ping.status)
                                .font(
                                    .custom(kMonoFontName, size: kMonoFontSize)
                                )
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PingView(viewModel: PingViewModel())
}
