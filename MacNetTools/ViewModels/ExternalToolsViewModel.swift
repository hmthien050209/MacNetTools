import Foundation

@Observable
class ExternalToolsViewModel {
    private let service = ExternalToolsService()

    // Availability states
    var tracerouteAvailable = false
    var speedtestAvailable = false

    // Active session state
    var activeStopAction: (() -> Void)?

    func checkTools() async {
        tracerouteAvailable = await service.isToolAvailable("traceroute")
        speedtestAvailable = await service.isToolAvailable("speedtest")
    }

    func startTraceroute(target: String) -> AsyncStream<String> {
        let result = service.runCommandStreaming(
            "traceroute",
            arguments: [target]
        )
        self.activeStopAction = result.stop
        return result.stream
    }

    func startSpeedtest() -> AsyncStream<String> {
        let result = service.runCommandStreaming("speedtest", arguments: [])
        self.activeStopAction = result.stop
        return result.stream
    }

    func stopCurrentTool() {
        activeStopAction?()
        activeStopAction = nil
    }
}
