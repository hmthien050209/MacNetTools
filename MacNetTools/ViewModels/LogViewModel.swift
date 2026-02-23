import Foundation

@Observable
class LogViewModel {
    private var isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withTime, .withColonSeparatorInTime]
        return formatter
    }()

    var entries: [LogEntry] = []

    func filteredEntries(searchText: String) -> [LogEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.message.localizedCaseInsensitiveContains(searchText)
        }
    }

    func append(_ message: String) {
        let timestamp = isoFormatter.string(from: Date())
        entries.append(LogEntry(message: "[\(timestamp)] \(message)"))
    }

    func clear() {
        entries.removeAll()
    }
}
