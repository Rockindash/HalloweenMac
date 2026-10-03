import SwiftUI

/// The app: a window you open from the Applications folder, and a 🎃 in the menu bar. The pumpkins
/// themselves live in a see-through AppKit window above the Dock (see Overlay/), because SwiftUI
/// windows can't float over the Dock or let clicks pass through.
@main
struct FallDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra(isInserted: $model.showMenuBarIcon) {
            MenuContent(model: model)
        } label: {
            Text("🎃")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel.shared
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Opened by "Open at Login", rather than by someone opening the app?
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        if !Settings.hasSeenWelcome {
            model.showWelcome()
        } else if !launchedAtLogin {
            model.showMainWindow()
        }
    }

    /// Opening the app again (from Applications, Spotlight or Launchpad) while it's running shows its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.showMainWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
