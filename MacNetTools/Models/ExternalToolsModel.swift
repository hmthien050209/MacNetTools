import Foundation

struct ExternalToolsModel {
    var speedtestAvailable: Bool
    var tracerouteAvailable: Bool
}

struct ToolSession: Identifiable {
    let id = UUID()
    let name: String
    let stream: AsyncStream<String>
}
