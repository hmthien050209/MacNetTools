import SwiftUI

struct ExternalToolsView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = ExternalToolsViewModel()
    @State private var tracerouteTarget = "1.1.1.1"
    @State private var pingTarget = "1.1.1.1"

    var body: some View {
        VStack(alignment: .leading, spacing: kSpacing) {
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
                            let sessionId = viewModel.startTraceroute(
                                target: tracerouteTarget
                            )
                            openWindow(value: sessionId)
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
                    Text("Ping")
                    HStack {
                        TextField("Target", text: $pingTarget)
                            .textFieldStyle(.roundedBorder)
                        Button("Run") {
                            let sessionId = viewModel.startPing(
                                target: pingTarget
                            )
                            openWindow(value: sessionId)
                        }
                        .disabled(
                            !viewModel.pingAvailable
                                || pingTarget.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                        )
                    }
                }

                GridRow {
                    Text("Speedtest")
                    Button("Run Speedtest") {
                        let sessionId = viewModel.startSpeedtest()
                        openWindow(value: sessionId)
                    }
                    .disabled(!viewModel.speedtestAvailable)
                }
            }
        }
        .task { await viewModel.checkTools() }
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
