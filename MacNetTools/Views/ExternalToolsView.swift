import SwiftUI

struct ExternalToolsView : View {
    @State private var viewModel = ExternalToolsViewModel()
    @State private var tracerouteTarget = "1.1.1.1"
    var logViewModel: LogViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("External Tools")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Traceroute")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                TextField("Target host", text: $tracerouteTarget)
                    .textFieldStyle(.roundedBorder)
                
                Button {
                    runTraceroute()
                } label: {
                    Label("Run traceroute", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.tracerouteAvailable || tracerouteTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Speedtest")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Button {
                    runSpeedtest()
                } label: {
                    Label("Run speedtest", systemImage: "gauge")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.speedtestAvailable)
            }
            
            Spacer()
            
            Text(toolAvailabilityText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: 300, alignment: .topLeading)
    }
    
    private var toolAvailabilityText: String {
        var messages: [String] = []
        messages.append(viewModel.tracerouteAvailable ? "Traceroute detected" : "Traceroute not found in PATH")
        messages.append(viewModel.speedtestAvailable ? "Speedtest available" : "Speedtest CLI not detected")
        return messages.joined(separator: " · ")
    }
    
    private func runTraceroute() {
        let target = tracerouteTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        
        logViewModel?.append("Running traceroute to \(target)...")
        Task {
            let lines = await viewModel.runTraceroute(target: target)
            await MainActor.run {
                lines.forEach { line in
                    logViewModel?.append(line)
                }
            }
        }
    }
    
    private func runSpeedtest() {
        logViewModel?.append("Running speedtest...")
        Task {
            let lines = await viewModel.runSpeedtest()
            await MainActor.run {
                lines.forEach { line in
                    logViewModel?.append(line)
                }
            }
        }
    }
}

#Preview {
    ExternalToolsView()
}
