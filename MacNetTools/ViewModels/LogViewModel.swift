import Foundation

@Observable
class LogViewModel {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var entries: [String] = []
    
    func append(_ message: String) {
        let timestamp = Self.formatter.string(from: Date())
        entries.append("[\(timestamp)] \(message)")
    }
    
    func clear() {
        entries.removeAll()
    }
}
