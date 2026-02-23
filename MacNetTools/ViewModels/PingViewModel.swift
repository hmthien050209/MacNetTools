import Foundation

@Observable
class PingViewModel {
    var pings: [PingModel] = []
    
    func addPing(target: String, status: String) {
        // Replace the existing entry for the same target if present
        if let index = pings.firstIndex(where: { $0.target == target }) {
            pings[index] = PingModel(target: target, status: status)
        } else {
            pings.append(PingModel(target: target, status: status))
        }
    }
    
    func runPing(target: String) -> (status: String, logLines: [String]) {
        let pingPath = FileManager.default.isExecutableFile(atPath: "/sbin/ping") ? "/sbin/ping" : "/bin/ping"
        
        let task = Process()
        task.launchPath = pingPath
        task.arguments = ["-c", "3", target]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            return ("Failed", ["Ping failed to launch: \(error.localizedDescription)"])
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        let output = String(data: data, encoding: .utf8) ?? ""
        let logLines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        
        let status = task.terminationStatus == 0 ? "Reachable" : "Failed (\(task.terminationStatus))"
        return (status, logLines)
    }
}
