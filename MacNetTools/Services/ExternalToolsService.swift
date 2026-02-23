import Foundation

class ExternalToolsService {
    func isToolAvailable(_ name: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", name]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
        } catch {
            return false
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func runCommand(_ executable: String, arguments: [String]) -> [String] {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [executable] + arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            return ["\(executable) failed to launch: \(error.localizedDescription)"]
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        
        guard let output = String(data: data, encoding: .utf8) else {
            return ["No output from \(executable)"]
        }
        
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        
        return lines.isEmpty ? ["No output from \(executable)"] : lines
    }
}
