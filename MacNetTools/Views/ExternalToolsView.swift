import SwiftUI

struct ExternalToolsView : View {
    @State private var viewModel = ExternalToolsViewModel()
    @State private var tracerouteTarget = "1.1.1.1"
    var logViewModel: LogViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("External Tools")
                    .font(.headline)
                Spacer()
                Text(toolAvailabilityText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Traceroute")
                        .fontWeight(.semibold)
                    HStack {
                        TextField("Target", text: $tracerouteTarget)
                            .textFieldStyle(.roundedBorder)
                        Button("Run") { runTraceroute() }
                            .disabled(!viewModel.tracerouteAvailable || tracerouteTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                GridRow {
                    Text("Speedtest")
                        .fontWeight(.semibold)
                    Button("Run") { runSpeedtest() }
                        .disabled(!viewModel.speedtestAvailable)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
