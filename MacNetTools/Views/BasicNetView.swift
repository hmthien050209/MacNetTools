import SwiftUI

struct BasicNetView: View {
    var viewModel: BasicNetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Basic Network Information")
                .font(.headline)

            if let model = viewModel.basicNetModel {
                Grid(
                    alignment: .leading,
                    horizontalSpacing: 8,
                    verticalSpacing: 6
                ) {
                    InfoGridRow(label: "Local IP", value: model.localIp)
                    InfoGridRow(label: "Subnet Mask", value: model.subnetMask)
                    InfoGridRow(label: "Router", value: model.routerIp)
                    InfoGridRow(label: "MTU", value: model.mtu)
                    InfoGridRow(
                        label: "Public IPv4",
                        value: model.publicIpV4.isEmpty ? kUnknown : model.publicIpV4
                    )
                    InfoGridRow(
                        label: "Public IPv6",
                        value: model.publicIpV6.isEmpty ? kUnknown : model.publicIpV6
                    )
                }
            } else {
                Text("No network data")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    BasicNetView(viewModel: BasicNetViewModel())
}
