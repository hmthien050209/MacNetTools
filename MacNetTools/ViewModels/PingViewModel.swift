import Foundation
import Observation

@Observable
class PingViewModel {
    var pings: [PingModel] = []
    private let service = ExternalToolsService()

    // Updates UI: Ensure this runs on MainActor
    @MainActor
    func addPing(target: String, status: String) {
        if let index = pings.firstIndex(where: { $0.target == target }) {
            let existingId = pings[index].id
            pings[index] = PingModel(
                id: existingId,
                target: target,
                status: status
            )
        } else {
            pings.append(PingModel(target: target, status: status))
        }
    }

    /// Non-streaming version: Collects all lines and then calculates status
    func runPing(target: String) async -> (status: String, logLines: [String]) {
        var lines: [String] = []

        // Consume the stream entirely
        for await line in runPingStream(target: target) {
            if !line.isEmpty { lines.append(line) }
        }

        let status: String
        if let avg = extractAverageLatency(from: lines) {
            status = "\(avg) ms"
        } else if lines.contains(where: { $0.contains("64 bytes from") }) {
            status = "Reachable"
        } else {
            status = "Failed"
        }

        return (status, lines)
    }

    /// Streaming version: Pipes directly from ExternalToolsService
    func runPingStream(target: String) -> AsyncStream<String> {
        // No need to check paths manually; 'env' handles 'ping' location
        let result = service.runCommandStreaming(
            "ping",
            arguments: ["-c", "3", target]
        )
        return result.stream
    }

    // MARK: - Logic
    private func extractAverageLatency(from lines: [String]) -> String? {
        guard
            let summary = lines.first(where: {
                $0.contains("round-trip") || $0.contains("avg")
            })
        else { return nil }
        let parts = summary.split(separator: "=")
        guard let metricsPart = parts.last else { return nil }

        let components =
            metricsPart
            .replacingOccurrences(of: " ms", with: "")
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "/")

        // ping format: min/avg/max/mdev
        return components.indices.contains(1) ? String(components[1]) : nil
    }
}
