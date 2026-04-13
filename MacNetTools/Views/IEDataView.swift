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

      if let model = viewModel.wiFiModel,
        model.bssLoadStationCount > 0
          || model.bssLoadUtilization > 0 || model.bssLoadCapacity > 0
      {
        Grid(
          alignment: .leading,
          horizontalSpacing: 8,
          verticalSpacing: 6
        ) {
          InfoGridRow(
            label: "Utilization",
            value: String(
              format: "%.1f%%",
              model.bssLoadUtilization
            )
          )

          // IEEE 802.11-2024 Section 9.4.2.26: Available Admission Capacity
          // is in units of 32 µs/s. 1s / 32µs = 31,250 units per second.
          InfoGridRow(
            label: "Available Capacity",
            value: String(
              format: "%.1f%%",
              Double(model.bssLoadCapacity) / 31250.0
                * 100.0
            )
          )

          InfoGridRow(
            label: "Stations",
            value: "\(model.bssLoadStationCount)"
          )
        }
      } else {
        Text("No BSS Load data available")
          .foregroundStyle(.secondary)
      }

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
