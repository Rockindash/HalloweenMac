import SwiftUI

/// The app: a window you open from the Applications folder, and a menu in the menu bar. The pumpkins
/// themselves live in a see-through AppKit window above the Dock (see Overlay/), because SwiftUI
/// windows can't float over the Dock or let clicks pass through.
@main
struct FallDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var model = AppModel.shared

    /// SwiftUI writes this back whenever it redraws the menu bar item, even when nothing changed.
    /// Passing every write on would announce a change, redraw, write again, and so on forever,
    /// freezing the app, so only real changes get through.
    private var showMenuBarIcon: Binding<Bool> {
        Binding(get: { model.showMenuBarIcon },
                set: { if $0 != model.showMenuBarIcon { model.showMenuBarIcon = $0 } })
    }

    var body: some Scene {
        MenuBarExtra(isInserted: showMenuBarIcon) {
            MenuContent(model: model)
        } label: {
            // The theme's own thing, drawn plainly like the system's icons: a pumpkin, a jack-o'-lantern or a diya.
            Image(nsImage: ExtraArt.menuBarIcon(model.theme))
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
        // Unit tests run inside the app; it stays out of their way.
        guard !AppEnvironment.isUnitTesting else { return }
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
