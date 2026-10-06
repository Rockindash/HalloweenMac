import AppKit
import SwiftUI

/// The app's own window, opened from the Applications folder or the pumpkin menu: Home, Customize and
/// Settings in a sidebar (see MainView.swift). While it's open Dockorate shows in the Dock and the
/// app switcher like any other app.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil { build(model: model) }
        // Keep the title hidden on every macOS version. (SwiftUI only removes its own title on macOS 15 and later.)
        window?.titleVisibility = .hidden
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
        window.title = "Dockorate"
        // An empty unified toolbar lets the floating sidebar run up to the top of the window, with
        // the close, minimize and zoom buttons inside it, as in the App Store.
        window.toolbar = NSToolbar(identifier: "FallDockMainWindow")
        window.toolbarStyle = .unified
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

    // In full screen macOS draws the toolbar as a solid band across the top, over the page title and
    // the first sidebar row (they run up under the see-through toolbar). The empty toolbar is only
    // there for the windowed look, so hide it in full screen.
    func windowWillEnterFullScreen(_ notification: Notification) {
        window?.toolbar?.isVisible = false
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        window?.toolbar?.isVisible = true
    }

    func windowWillClose(_ notification: Notification) {
        // Back to living in the menu bar only.
        NSApp.setActivationPolicy(.accessory)
    }
}
