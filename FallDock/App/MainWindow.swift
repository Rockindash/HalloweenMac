import AppKit
import SwiftUI

/// The app's own window, opened from the Applications folder or the 🎃 menu: a sidebar of pages
/// (see MainView.swift), like System Settings. While it's open Fall Dock shows in the Dock and the
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
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Fall Dock"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 900, height: 680))
        window.minSize = NSSize(width: 820, height: 600)
        window.center()
        window.setFrameAutosaveName("FallDockMainWindow")
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // Back to living in the menu bar only.
        NSApp.setActivationPolicy(.accessory)
    }
}
