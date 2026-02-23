import Foundation

class ExternalToolsService {
    // MARK: - Public API

    func isToolAvailable(_ name: String) async -> Bool {
        let (task, _) = configureProcess(executable: "which", arguments: [name])

        return await withCheckedContinuation { continuation in
            task.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try task.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    func runCommandStreaming(_ executable: String, arguments: [String]) -> (
        stream: AsyncStream<String>, stop: () -> Void
    ) {
        let (task, pipe) = configureProcess(
            executable: executable,
            arguments: arguments
        )

        let stream = AsyncStream<String> { continuation in
            do {
                try task.run()

                Task.detached(priority: .background) {
                    // Stream the program output
                    for try await line in pipe.fileHandleForReading.bytes.lines
                    {
                        // Yield the line as is (Swift has already stripped the \n)
                        continuation.yield(line)
                    }

                    // Wait for the process to actually exit to get the status
                    // This ensures we don't say "Finished" while the OS is still cleaning up
                    task.waitUntilExit()

                    // Provide a more descriptive closing message
                    let exitCode = task.terminationStatus
                    if exitCode == 0 {
                        continuation.yield("- Process completed successfully -")
                    } else {
                        continuation.yield(
                            "- Process terminated with exit code \(exitCode) -"
                        )
                    }

                    continuation.finish()
                }
            } catch {
                continuation.yield("Error: \(error.localizedDescription)")
                continuation.finish()
            }

            continuation.onTermination = { _ in
                if task.isRunning { task.terminate() }
            }
        }

        return (
            stream: stream,
            stop: {
                if task.isRunning { task.terminate() }
            }
        )
    }

    // MARK: - Private Helpers

    /// Configures a Process to run via /usr/bin/env with an injected PATH.
    private func configureProcess(executable: String, arguments: [String]) -> (
        Process, Pipe
    ) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [executable] + arguments

        // Setup Environment with common CLI paths
        var env = ProcessInfo.processInfo.environment
        let extraPaths =
            "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let currentPath = env["PATH"] ?? ""
        env["PATH"] =
            currentPath.isEmpty ? extraPaths : "\(currentPath):\(extraPaths)"
        task.environment = env

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        return (task, pipe)
    }
}
