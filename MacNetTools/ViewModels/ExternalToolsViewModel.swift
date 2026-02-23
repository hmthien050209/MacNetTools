import Foundation

@Observable
class ExternalToolsViewModel {
    private var availabilityTask: Task<Void, Never>?
    private var preferredSpeedtestCommand: String?
    private let service = ExternalToolsService()
    
    var tracerouteAvailable: Bool = false
    var speedtestAvailable: Bool = false
    
    init() {
        availabilityTask = Task { @MainActor in
            tracerouteAvailable = await service.isToolAvailable("traceroute")
            preferredSpeedtestCommand = await resolveSpeedtestCommand()
            speedtestAvailable = preferredSpeedtestCommand != nil
        }
    }
    
    deinit {
        availabilityTask?.cancel()
    }
    
    func runTraceroute(target: String) async -> [String] {
        await service.runCommand("traceroute", arguments: [target])
    }
    
    func runTracerouteStream(target: String) -> AsyncStream<String> {
        service.runCommandStreaming("traceroute", arguments: [target])
    }
    
    func runSpeedtest() async -> [String] {
        if preferredSpeedtestCommand == nil {
            preferredSpeedtestCommand = await resolveSpeedtestCommand()
            await MainActor.run {
                speedtestAvailable = preferredSpeedtestCommand != nil
            }
        }
        
        guard let command = preferredSpeedtestCommand else {
            return ["No speedtest tool available on this system."]
        }
        
        return await service.runCommand(command, arguments: [])
    }
    
    func runSpeedtestStream() -> AsyncStream<String> {
        if let command = preferredSpeedtestCommand {
            return service.runCommandStreaming(command, arguments: [])
        }
        return AsyncStream { continuation in
            Task.detached {
                let resolved = await self.resolveSpeedtestCommand()
                await MainActor.run {
                    self.preferredSpeedtestCommand = resolved
                    self.speedtestAvailable = resolved != nil
                }
                if let cmd = resolved {
                    for await line in self.service.runCommandStreaming(cmd, arguments: []) {
                        continuation.yield(line)
                    }
                } else {
                    continuation.yield("No speedtest tool available on this system.")
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Helpers
    private func resolveSpeedtestCommand() async -> String? {
        let speedtestTool = await service.isToolAvailable("speedtest")
        if speedtestTool { return "speedtest" }
        
        let networkQuality = await service.isToolAvailable("networkQuality")
        return networkQuality ? "networkQuality" : nil
    }
}
