import AppKit
import SwiftUI

/// The app's own window, opened from the Applications folder or the 🎃 menu: General, Settings and
/// Dock tabs, plus a tab for the season on the Dock (Fall for now), in the style of System Settings
/// panes of old. While it's open Fall Dock shows in the Dock and the app switcher like any other app.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var tabs: NSTabViewController?
    private weak var model: AppModel?

    func show(model: AppModel) {
        self.model = model
        if window == nil { build(model: model) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// The season changed: its tab follows.
    func themeChanged() {
        guard let model, let tabs, tabs.tabViewItems.count == 4 else { return }
        let selected = tabs.selectedTabViewItemIndex
        tabs.removeTabViewItem(tabs.tabViewItems[3])
        tabs.addTabViewItem(themeItem(model: model))
        tabs.selectedTabViewItemIndex = selected
    }

    private func build(model: AppModel) {
        let tabs = TabsController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(item(GeneralTab(model: model), title: "General", symbol: "house"))
        tabs.addTabViewItem(item(SettingsTab(model: model), title: "Settings", symbol: "gearshape"))
        tabs.addTabViewItem(item(DockTab(model: model), title: "Dock", symbol: "dock.rectangle"))
        tabs.addTabViewItem(themeItem(model: model))
        // Open on the tab that was showing last time.
        tabs.selectedTabViewItemIndex = min(UserDefaults.standard.integer(forKey: TabsController.lastTabKey), tabs.tabViewItems.count - 1)

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("FallDockMain")
        window.title = tabs.tabViewItems[tabs.selectedTabViewItemIndex].label
        self.window = window
        self.tabs = tabs
    }

    private func themeItem(model: AppModel) -> NSTabViewItem {
        item(ThemeTab(model: model), title: model.theme.title, symbol: model.theme.symbol)
    }

    private func item<Content: View>(_ view: Content, title: String, symbol: String) -> NSTabViewItem {
        let host = NSHostingController(rootView: view.frame(width: 560))
        host.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    func windowWillClose(_ notification: Notification) {
        // Back to living in the menu bar only.
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Tabs that name the window after the one showing, and remember it for next time.
final class TabsController: NSTabViewController {
    static let lastTabKey = "mainWindowTab"

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let tabViewItem else { return }
        view.window?.title = tabViewItem.label
        UserDefaults.standard.set(tabView.indexOfTabViewItem(tabViewItem), forKey: Self.lastTabKey)
    }
}
