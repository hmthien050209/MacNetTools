import SwiftUI

struct IEDataView: View {
    var viewModel: WiFiViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
            Text("WiFi IE Data")
                .font(.headline)

            // BSS Load Section
            Text("BSS Load")
                .font(.subheadline)

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

                    /// Calculates the percentage of available medium time.
                    ///
                    /// Per IEEE 802.11-2024, Section 9.4.2.26 (BSS Load element):
                    /// The "Available Admission Capacity" field is a 2-octet unsigned integer that
                    /// indicates the remaining amount of medium time available via explicit
                    /// admission control, in units of 32 microseconds per second.
                    ///
                    /// Calculation:
                    /// 1 second = 1,000,000 microseconds.
                    /// 1,000,000 μs / 32 μs per unit = 31,250 total units per second.
                    /// (Raw Value / 31,250) * 100 = Percentage of available medium time.
                    InfoGridRow(
                        label: "Available Capacity",
                        value: String(
                            format: "%.1f%%",
                            Double(bssLoad.availableCapacity) / 31250.0
                                * 100.0
                        )
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

            // Vendor Specific Section
            Text("Vendor Specific")
                .font(.subheadline)

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
