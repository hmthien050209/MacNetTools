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
    
    // MARK: - Helpers
    private func resolveSpeedtestCommand() async -> String? {
        let speedtestTool = await service.isToolAvailable("speedtest")
        if speedtestTool { return "speedtest" }
        
        let networkQuality = await service.isToolAvailable("networkQuality")
        return networkQuality ? "networkQuality" : nil
    }
}
