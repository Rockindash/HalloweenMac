import SwiftUI

/// The app: a 🎃 in the menu bar. The pumpkins themselves live in a see-through
/// AppKit window above the Dock (see Overlay/), because SwiftUI windows can't float
/// over the Dock or let clicks pass through.
@main
struct FallDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: appDelegate.model)
        } label: {
            Text("🎃")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        if !Settings.hasSeenWelcome {
            model.showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
