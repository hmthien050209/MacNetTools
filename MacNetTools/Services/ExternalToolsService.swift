import Foundation

// Making this nonisolated ensures it doesn't accidentally
// run on the MainActor unless explicitly told to.
class ExternalToolsService {
    
    func isToolAvailable(_ name: String) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", name]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            // Non-blocking wait using the modern async API
            while task.isRunning {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s check
            }
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func runCommandStreaming(_ executable: String, arguments: [String]) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Process()
            // Using /usr/bin/env to find the executable automatically in PATH
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [executable] + arguments
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                
                Task {
                    // Non-blocking iteration over lines
                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                }
            } catch {
                continuation.yield("Error: \(error.localizedDescription)")
                continuation.finish()
            }
        }
    }
}
