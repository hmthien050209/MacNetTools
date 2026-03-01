import Foundation
import SwiftUI

/// Data model for an active CLI tool session.
struct ToolSession: Identifiable {
    let id: String
    let name: String
    let stream: AsyncStream<String>
    let stop: () -> Void
}

/// A global manager to track and control multiple tool sessions.
@Observable
class ToolSessionManager {
    static let shared = ToolSessionManager()

    /// Dictionary of active sessions keyed by their ID.
    var sessions: [String: ToolSession] = [:]

    private init() {}

    /// Registers a new tool session and returns its unique ID.
    ///
    /// - Parameters:
    ///   - name: The human-readable name of the tool (e.g., "Ping: google.com").
    ///   - sessionResult: The raw streaming result from `ExternalToolsService`.
    /// - Returns: A unique session ID used for window management.
    func registerSession(
        name: String,
        sessionResult: (stream: AsyncStream<String>, stop: () -> Void)
    ) -> String {
        let id = UUID().uuidString
        let session = ToolSession(
            id: id,
            name: name,
            stream: sessionResult.stream,
            stop: sessionResult.stop
        )
        sessions[id] = session
        return id
    }

    /// Removes a session from the manager.
    /// - Parameter id: The ID of the session to remove.
    func removeSession(id: String) {
        sessions.removeValue(forKey: id)
    }
}
