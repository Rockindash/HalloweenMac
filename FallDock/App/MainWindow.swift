import AppKit
import SwiftUI

/// The app's own window, opened from the Applications folder or the 🎃 menu: Home, Customize and
/// Settings in a sidebar (see MainView.swift). While it's open Fall Dock shows in the Dock and the
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

    private func build(model: AppModel) {
        let host = NSHostingController(rootView: MainView(model: model))
        // The window can't shrink below what the pages need.
        host.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Fall Dock"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 1040, height: 780))
        window.contentMinSize = MainView.minSize
        window.center()
        window.setFrameAutosaveName("FallDockMainWindow")
        // A size saved by an older version may be smaller than the pages now need.
        let size = window.contentRect(forFrameRect: window.frame).size
        if size.width < MainView.minSize.width || size.height < MainView.minSize.height {
            window.setContentSize(NSSize(width: max(size.width, 1040), height: max(size.height, 780)))
            window.center()
        }
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // Back to living in the menu bar only.
        NSApp.setActivationPolicy(.accessory)
    }
}
