import Foundation

@Observable
class LogViewModel {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withTime, .withColonSeparatorInTime]
        return formatter
    }()
    
    var entries: [LogEntry] = []
    
    func append(_ message: String) {
        let timestamp = Self.formatter.string(from: Date())
        entries.append(LogEntry(message: "[\(timestamp)] \(message)"))
    }
    
    func clear() {
        entries.removeAll()
    }
}
