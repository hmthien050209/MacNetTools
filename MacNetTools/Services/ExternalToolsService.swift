import Foundation

class ExternalToolsService {
    func isToolAvailable(_ name: String) async -> Bool {
        await Task.detached(priority: .background) {
            self.checkToolAvailable(name)
        }.value
    }
    
    func runCommand(_ executable: String, arguments: [String]) async -> [String] {
        await Task.detached(priority: .background) {
            self.executeCommand(executable, arguments: arguments)
        }.value
    }
    
    func runCommandStreaming(_ executable: String, arguments: [String]) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task.detached(priority: .background) {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                task.arguments = [executable] + arguments
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    if let chunk = String(data: data, encoding: .utf8) {
                        chunk
                            .split(separator: "\n", omittingEmptySubsequences: false)
                            .forEach { continuation.yield(String($0)) }
                    }
                }
                
                task.terminationHandler = { _ in
                    continuation.finish()
                }
                
                do {
                    try task.run()
                } catch {
                    continuation.yield("\(executable) failed to launch: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func checkToolAvailable(_ name: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", name]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
        } catch {
            return false
        }
        
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func executeCommand(_ executable: String, arguments: [String]) -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [executable] + arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
        } catch {
            return ["\(executable) failed to launch: \(error.localizedDescription)"]
        }
        
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let output = String(data: data, encoding: .utf8) else {
            return ["No output from \(executable)"]
        }
        
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }
        
        return lines.isEmpty ? ["No output from \(executable)"] : lines
    }
}
