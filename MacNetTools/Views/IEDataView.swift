import SwiftUI

struct IEDataView: View {
    var viewModel: WiFiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
            // BSS Load Section
            Text("BSS Load")
                .font(.headline)

            if let bssLoad = viewModel.wiFiModel?.bssLoad {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: 8,
                    verticalSpacing: 6
                ) {
                    InfoGridRow(
                        label: "Utilization",
                        value: String(
                            format: "%.1f%%",
                            bssLoad.channelUtilization
                        )
                    )
                    InfoGridRow(
                        label: "Available Capacity",
                        value: "\(bssLoad.availableCapacity)"
                    )
                    InfoGridRow(
                        label: "Stations",
                        value: "\(bssLoad.stationCount)"
                    )
                }
            } else {
                Text("No BSS Load data available")
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Vendor Specific Section
            Text("Vendor Specific")
                .font(.headline)

            if let vendorIEs = viewModel.wiFiModel?.vendorSpecificIEs,
                !vendorIEs.isEmpty
            {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: 8,
                    verticalSpacing: 6
                ) {
                    ForEach(vendorIEs) { ie in
                        InfoGridRow(label: ie.oui, value: ie.vendorName)
                    }
                }
            } else {
                Text("No Vendor Specific IEs detected")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    IEDataView(viewModel: WiFiViewModel())
}
