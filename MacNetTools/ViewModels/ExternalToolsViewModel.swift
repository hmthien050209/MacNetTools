import Foundation

@Observable
class ExternalToolsViewModel {
    private let service = ExternalToolsService()
    private let sessionManager = ToolSessionManager.shared

    // Availability states
    var tracerouteAvailable = false
    var speedtestAvailable = false
    var pingAvailable = false

    func checkTools() async {
        tracerouteAvailable = await service.isToolAvailable("traceroute")
        speedtestAvailable = await service.isToolAvailable("speedtest")
        pingAvailable = await service.isToolAvailable("ping")
    }

    func startTraceroute(target: String) -> String {
        let result = service.runCommandStreaming(
            "traceroute",
            arguments: [target]
        )
        return sessionManager.registerSession(
            name: "Traceroute: \(target)",
            sessionResult: result
        )
    }

    func startSpeedtest() -> String {
        let result = service.runCommandStreaming("speedtest", arguments: [])
        return sessionManager.registerSession(
            name: "Speedtest",
            sessionResult: result
        )
    }

    func startPing(target: String) -> String {
        let result = service.runCommandStreaming(
            "ping",
            arguments: ["-c", "10", target]  // Default to 10 pings
        )
        return sessionManager.registerSession(
            name: "Ping: \(target)",
            sessionResult: result
        )
    }

    func stopTool(id: String) {
        sessionManager.sessions[id]?.stop()
        sessionManager.removeSession(id: id)
    }
}
