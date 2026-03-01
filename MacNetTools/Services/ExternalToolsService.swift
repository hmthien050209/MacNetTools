import Foundation

/// Service for executing and streaming output from system CLI tools.
///
/// This service leverages the `Process` API to run external executables. It
/// handles environment configuration (PATH injection) and bridges file handle
/// reads to `AsyncStream` for reactive UI updates.
class ExternalToolsService {

    /// Verifies if a specific CLI tool is available in the system PATH.
    ///
    /// - Parameter name: The name of the executable (e.g., "ping").
    /// - Returns: True if the tool is found and executable.
    func isToolAvailable(_ name: String) async -> Bool {
        let (task, _) = configureProcess(executable: "which", arguments: [name])

        return await withCheckedContinuation { continuation in
            task.terminationHandler = { (process: Process) in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try task.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Executes a system command and provides a real-time stream of its output.
    ///
    /// This method is non-blocking to the caller. It spawns the process and
    /// returns an `AsyncStream` that yields lines as they are produced by the
    /// executable's stdout/stderr.
    ///
    /// - Parameters:
    ///   - executable: The binary name or path.
    ///   - arguments: CLI arguments.
    /// - Returns: A tuple containing the output stream and a cancellation closure.
    func runCommandStreaming(_ executable: String, arguments: [String]) -> (
        stream: AsyncStream<String>, stop: () -> Void
    ) {
        let (task, pipe) = configureProcess(
            executable: executable,
            arguments: arguments
        )

        let stream = AsyncStream<String> { continuation in
            // Use readabilityHandler for true non-blocking I/O.
            // This avoids tying up cooperative pool threads with blocking read calls.
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF reached, clean up.
                    handle.readabilityHandler = nil
                } else if let line = String(data: data, encoding: .utf8) {
                    // Note: This might yield multiple lines at once or partial lines.
                    // For CLI tools, this is usually acceptable as they are line-buffered.
                    // We trim trailing whitespace to handle the trailing newline.
                    let trimmed = line.trimmingCharacters(in: .newlines)
                    if !trimmed.isEmpty {
                        // Split by newline in case multiple lines were read at once.
                        for subLine in trimmed.components(
                            separatedBy: .newlines
                        ) {
                            continuation.yield(subLine)
                        }
                    }
                }
            }

            task.terminationHandler = { _ in
                // Ensure the readability handler is removed when the task ends.
                pipe.fileHandleForReading.readabilityHandler = nil

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

            do {
                try task.run()
            } catch {
                continuation.yield(
                    "Execution Error: \(error.localizedDescription)"
                )
                continuation.finish()
            }

            // Cleanup logic when the stream consumer cancels or finishes.
            continuation.onTermination = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
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

    /// Configures an Foundation.Process with a sane environment.
    ///
    /// Bridges through `/usr/bin/env` to resolve executables while injecting
    /// common macOS CLI paths (Homebrew, /usr/local, etc.) to ensure portability.
    private func configureProcess(executable: String, arguments: [String]) -> (
        Process, Pipe
    ) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [executable] + arguments

        // Inject standard and non-standard tool paths into the process environment.
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
