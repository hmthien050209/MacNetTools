import Foundation

struct PingModel: Identifiable {
  let id: UUID
  var target: String
  var status: String

  init(id: UUID = UUID(), target: String, status: String) {
    self.id = id
    self.target = target
    self.status = status
  }
}
