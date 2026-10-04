import AppKit
import SwiftUI

/// The app's own window, opened from the Applications folder or the 🎃 menu: Home, Customize and
/// Settings tabs in the title bar (see MainView.swift). While it's open Fall Dock shows in the Dock and the
/// app switcher like any other app.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil { build(model: model) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// The season changed. The pages follow the model by themselves.
    func themeChanged() {}

    private func build(model: AppModel) {
        let host = NSHostingController(rootView: MainView(model: model))
        host.sizingOptions = []
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // An empty toolbar makes the title bar tall enough for the tabs, with the window's buttons beside them.
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Fall Dock"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 720, height: 760))
        window.minSize = NSSize(width: 620, height: 560)
        window.center()
        window.setFrameAutosaveName("FallDockWindow")
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // Back to living in the menu bar only.
        NSApp.setActivationPolicy(.accessory)
    }
}
