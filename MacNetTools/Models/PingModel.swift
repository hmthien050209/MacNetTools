import Foundation

struct PingModel: Identifiable {
    let id: UUID
    /// The ping target
    var target: String
    /// Formatted ping latency (kSpacing3ms, etc.)
    var status: String

    init(id: UUID = UUID(), target: String, status: String) {
        self.id = id
        self.target = target
        self.status = status
    }
}
