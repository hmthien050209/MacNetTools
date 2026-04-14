import Foundation

/// Service for executing and streaming output from system CLI tools.
class ExternalToolsService {

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
      pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
          handle.readabilityHandler = nil
        } else if let line = String(data: data, encoding: .utf8) {
          let trimmed = line.trimmingCharacters(in: .newlines)
          if !trimmed.isEmpty {
            for subLine in trimmed.components(
              separatedBy: .newlines
            ) {
              continuation.yield(subLine)
            }
          }
        }
      }

      task.terminationHandler = { _ in
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

  private func configureProcess(executable: String, arguments: [String]) -> (
    Process, Pipe
  ) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    task.arguments = [executable] + arguments

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
