import SwiftUI

@main
struct MacNetToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }

        WindowGroup(for: String.self) { $sessionId in
            if let sessionId = sessionId {
                ToolTerminalView(sessionId: sessionId)
            }
        }
    }
}

// Exit on close button click (every windows are closed)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }
}
