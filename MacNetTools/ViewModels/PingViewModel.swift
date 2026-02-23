import Foundation

@Observable
class PingViewModel {
    var pings: [PingModel] = []
    
    func addPing(target: String, status: String) {
        // Replace the existing entry for the same target if present
        if let index = pings.firstIndex(where: { $0.target == target }) {
            let existingId = pings[index].id
            pings[index] = PingModel(id: existingId, target: target, status: status)
        } else {
            pings.append(PingModel(target: target, status: status))
        }
    }
    
    func runPing(target: String) async -> (status: String, logLines: [String]) {
        await Task.detached(priority: .background) {
            self.executePing(target: target)
        }.value
    }
    
    // MARK: - Helpers
    private func executePing(target: String) -> (status: String, logLines: [String]) {
        let pingPath = FileManager.default.isExecutableFile(atPath: "/sbin/ping") ? "/sbin/ping" : "/bin/ping"
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pingPath)
        task.arguments = ["-c", "3", target]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            return ("Failed", ["Ping failed to launch: \(error.localizedDescription)"])
        }
        
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: data, encoding: .utf8) ?? ""
        let logLines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }
        
        let status: String
        if task.terminationStatus == 0, let avg = extractAverageLatency(from: logLines) {
            status = "\(avg) ms"
        } else if task.terminationStatus == 0 {
            status = "Reachable"
        } else {
            status = "Failed (\(task.terminationStatus))"
        }
        return (status, logLines)
    }
    
    private func extractAverageLatency(from lines: [String]) -> String? {
        guard let summary = lines.first(where: { $0.contains("round-trip") || $0.contains("avg") }) else { return nil }
        guard let metricsPart = summary.split(separator: "=").last else { return nil }
        let components = metricsPart
            .replacingOccurrences(of: " ms", with: "")
            .split(separator: "/")
        // Expecting min/avg/max/stddev
        if components.count >= 2 {
            return String(components[1])
        }
        return nil
    }
}
