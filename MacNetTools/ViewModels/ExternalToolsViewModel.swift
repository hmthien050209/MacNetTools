import Foundation

@Observable
class ExternalToolsViewModel {
    private let service = ExternalToolsService()
    
    var tracerouteAvailable: Bool = false
    var speedtestAvailable: Bool = false
    private var preferredSpeedtestCommand: String?
    
    init() {
        // Kick off check in background immediately
        Task {
            let trace = await service.isToolAvailable("traceroute")
            let speedCmd = await resolveSpeedtestCommand()
            
            // Hop back to MainActor only to update UI state
            await MainActor.run {
                self.tracerouteAvailable = trace
                self.preferredSpeedtestCommand = speedCmd
                self.speedtestAvailable = speedCmd != nil
            }
        }
    }
    
    func runTracerouteStream(target: String) -> AsyncStream<String> {
        service.runCommandStreaming("traceroute", arguments: [target])
    }
    
    func runSpeedtestStream() -> AsyncStream<String> {
        guard let cmd = preferredSpeedtestCommand else {
            return AsyncStream { $0.yield("No tool found"); $0.finish() }
        }
        return service.runCommandStreaming(cmd, arguments: [])
    }
    
    private func resolveSpeedtestCommand() async -> String? {
        if await service.isToolAvailable("speedtest") { return "speedtest" }
        if await service.isToolAvailable("networkQuality") { return "networkQuality" }
        return nil
    }
}
