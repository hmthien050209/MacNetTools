import SwiftUI

struct BasicNetView: View {
    var viewModel: BasicNetViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Basic Network")
                .font(.headline)
            
            if let model = viewModel.basicNetModel {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    infoRow("Local IP", model.localIp)
                    infoRow("Subnet Mask", model.subnetMask)
                    infoRow("Router", model.routerIp)
                    infoRow("MTU", model.mtu)
                    infoRow("Public IPv4", model.publicIpV4.isEmpty ? kUnknown : model.publicIpV4)
                    infoRow("Public IPv6", model.publicIpV6.isEmpty ? kUnknown : model.publicIpV6)
                }
            } else {
                Text("No network data")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
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

#Preview {
    BasicNetView(viewModel: BasicNetViewModel())
}
