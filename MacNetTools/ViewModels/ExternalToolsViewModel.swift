import Foundation

@Observable
class ExternalToolsViewModel {
    private let service = ExternalToolsService()
    
    var tracerouteAvailable: Bool = false
    var speedtestAvailable: Bool = false
    
    init() {
        tracerouteAvailable = service.isToolAvailable("traceroute")
        // Some macOS installs use "speedtest" (Ookla) while others rely on "networkQuality"
        speedtestAvailable = service.isToolAvailable("speedtest") || service.isToolAvailable("networkQuality")
    }
    
    func runTraceroute(target: String) -> [String] {
        service.runCommand("traceroute", arguments: [target])
    }
    
    func runSpeedtest() -> [String] {
        if service.isToolAvailable("speedtest") {
            return service.runCommand("speedtest", arguments: [])
        }
        if service.isToolAvailable("networkQuality") {
            return service.runCommand("networkQuality", arguments: [])
        }
        return ["No speedtest tool available on this system."]
    }
}
