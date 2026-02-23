import SwiftUI

struct BasicNetView: View {
    @State private var viewModel = BasicNetViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Network Interface Details")
                .font(.headline)
            
            if let model = viewModel.basicNetModel {
                networkInfoList(model)
            } else {
                ContentUnavailableView(
                    "No Network Data",
                    systemImage: "network",
                    description: Text("Click update to fetch interface details.")
                )
            }
            
            Spacer()
            
            Button {
                viewModel.updateBasicNet()
            } label: {
                Label("Update Network Info", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("r", modifiers: .command) // Bonus: Cmd+R to refresh
        }
        .padding()
        .frame(width: 400, height: 450)
    }
    
    // Helper View to keep the main body clean
    @ViewBuilder
    private func networkInfoList(_ model: BasicNetModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(label: Label("Local Configuration", systemImage: "laptopcomputer")) {
                VStack(spacing: 8) {
                    LabeledContent("Local IP", value: model.localIp)
                    LabeledContent("Subnet Mask", value: model.subnetMask)
                    LabeledContent("Router", value: model.routerIp)
                    LabeledContent("MTU", value: model.mtu)
                }
                .padding(.top, 4)
            }
            
            GroupBox(label: Label("External", systemImage: "globe")) {
                VStack(spacing: 8) {
                    LabeledContent("Public IPv4", value: model.publicIpV4.isEmpty ? "Pending..." : model.publicIpV4)
                    LabeledContent("Public IPv6", value: model.publicIpV6.isEmpty ? "Pending..." : model.publicIpV6)
                }
                .padding(.top, 4)
            }
        }
        .textSelection(.enabled) // Allows users to highlight and copy IPs
    }
}

#Preview {
    BasicNetView()
}
