import Foundation

struct LogEntry: Identifiable {
    let id: UUID
    let message: String
    
    init(id: UUID = UUID(), message: String) {
        self.id = id
        self.message = message
    }
}

struct LogModel {
    var logEntries: Array<LogEntry>
}

enum LogScope {
    case sys
    case net
    case wifi
    case traceroute
    case speedtest
}
