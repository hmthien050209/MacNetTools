import Foundation
import SwiftUI

struct ToolSession: Identifiable {
  let id: String
  let name: String
  let stream: AsyncStream<String>
  let stop: () -> Void
}

@Observable
class ToolSessionManager {
  static let shared = ToolSessionManager()

  var sessions: [String: ToolSession] = [:]

  private init() {}

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

  func removeSession(id: String) {
    sessions.removeValue(forKey: id)
  }
}
