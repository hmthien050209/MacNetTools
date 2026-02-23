import SwiftUI

struct ExternalToolsView: View {
    @State private var viewModel = ExternalToolsViewModel()
    @State private var tracerouteTarget = "1.1.1.1"
    @State private var activeSession: ToolSession?

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

            Grid(alignment: .leading) {
                GridRow {
                    Text("Traceroute")
                    HStack {
                        TextField("Target", text: $tracerouteTarget)
                            .textFieldStyle(.roundedBorder)
                        Button("Run") {
                            let stream = viewModel.startTraceroute(
                                target: tracerouteTarget
                            )
                            activeSession = ToolSession(
                                name: "Traceroute: \(tracerouteTarget)",
                                stream: stream
                            )
                        }
                        .disabled(
                            !viewModel.tracerouteAvailable
                                || tracerouteTarget.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                        )
                    }
                }

                GridRow {
                    Text("Speedtest")
                    Button("Run Speedtest") {
                        let stream = viewModel.startSpeedtest()
                        activeSession = ToolSession(
                            name: "Speedtest",
                            stream: stream
                        )
                    }
                    .disabled(!viewModel.speedtestAvailable)
                }
            }
        }
        .padding()
        .task { await viewModel.checkTools() }
        .sheet(item: $activeSession) { session in
            ToolTerminalView(title: session.name, stream: session.stream) {
                viewModel.stopCurrentTool()
                activeSession = nil
            }
        }
    }

    private var toolAvailabilityText: String {
        var messages: [String] = []
        messages.append(
            viewModel.tracerouteAvailable
                ? "Traceroute detected" : "Traceroute not found in PATH"
        )
        messages.append(
            viewModel.speedtestAvailable
                ? "Speedtest available" : "Speedtest CLI not detected"
        )
        return messages.joined(separator: " · ")
    }
}
