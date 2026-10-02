import AppKit
import ServiceManagement

@main
enum FallDockMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // A menu bar app: no Dock icon and no main window.
        app.setActivationPolicy(.accessory)
        // NSApplication only holds its delegate weakly, so keep ours alive while the app runs.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayController()
    private var activity: NSObjectProtocol?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎃"
        item.button?.toolTip = "Fall Dock"
        statusItem = item
        rebuildMenu()

        overlay.onSmash = { [weak self] in
            Settings.smashCount += 1
            self?.rebuildMenu()
        }
        // A menu bar app is never "active", so macOS may put it to sleep (App Nap) and slow
        // its timers to once every few seconds. Opt out so the pumpkins keep up with the Dock.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping the pumpkins in step with the Dock"
        )
        overlay.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay.stop()
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let count = Settings.smashCount
        let header = NSMenuItem(title: count == 1 ? "1 pumpkin smashed" : "\(count) pumpkins smashed", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(toggle("Show Pumpkins", on: Settings.showPumpkins, action: #selector(toggleShow)))
        menu.addItem(toggle("Vines", on: Settings.showVines, action: #selector(toggleVines)))
        menu.addItem(toggle("Falling Leaves", on: Settings.fallingLeaves, action: #selector(toggleLeaves)))
        menu.addItem(toggle("Smash Sound", on: Settings.sound, action: #selector(toggleSound)))

        let countItem = NSMenuItem(title: "Number of Pumpkins", action: nil, keyEquivalent: "")
        let countMenu = NSMenu()
        for (n, name) in [(5, "A Few"), (9, "Plenty"), (13, "Overflowing")] {
            let option = toggle("\(name) (\(n))", on: Settings.pumpkinCount == n, action: #selector(setCount(_:)))
            option.tag = n
            countMenu.addItem(option)
        }
        countItem.submenu = countMenu
        menu.addItem(countItem)

        menu.addItem(withTitle: "Grow New Pumpkins", action: #selector(regrow), keyEquivalent: "r").target = self
        menu.addItem(.separator())

        if !DockLocator.hasAccessibility {
            menu.addItem(withTitle: "Fit Pumpkins to Dock Exactly…", action: #selector(askAccessibility), keyEquivalent: "").target = self
        }
        if isRunningAsApp {
            menu.addItem(toggle("Open at Login", on: SMAppService.mainApp.status == .enabled, action: #selector(toggleLogin)))
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Fall Dock", action: #selector(quit), keyEquivalent: "q").target = self

        statusItem?.menu = menu
    }

    private func toggle(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    private var isRunningAsApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    // MARK: Actions

    @objc private func toggleShow() {
        Settings.showPumpkins.toggle()
        overlay.refresh()
        rebuildMenu()
    }

    @objc private func toggleVines() {
        Settings.showVines.toggle()
        overlay.refresh(force: true)
        rebuildMenu()
    }

    @objc private func toggleLeaves() {
        Settings.fallingLeaves.toggle()
        rebuildMenu()
    }

    @objc private func toggleSound() {
        Settings.sound.toggle()
        rebuildMenu()
    }

    @objc private func setCount(_ sender: NSMenuItem) {
        Settings.pumpkinCount = sender.tag
        overlay.refresh(force: true)
        rebuildMenu()
    }

    @objc private func regrow() {
        overlay.refresh(force: true)
    }

    @objc private func askAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Fit pumpkins to your Dock exactly?"
        alert.informativeText = """
        Fall Dock guesses how wide your Dock is. To measure it exactly, macOS needs you to allow \
        Fall Dock under System Settings → Privacy & Security → Accessibility.

        Fall Dock only reads the Dock's size. It never reads your screen or what you type.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            DockLocator.requestAccessibility()
        }
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
