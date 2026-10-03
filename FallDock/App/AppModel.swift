import AppKit
import ServiceManagement
import SwiftUI

/// Everything the menu shows and changes. Choices are saved in `Settings`.
@MainActor
final class AppModel: ObservableObject {
    private let overlay = OverlayController()
    private var activity: NSObjectProtocol?

    @Published private(set) var smashCount: Int

    @Published var showPumpkins: Bool {
        didSet { Settings.showPumpkins = showPumpkins; overlay.refresh() }
    }

    @Published var showVines: Bool {
        didSet { Settings.showVines = showVines; overlay.refresh(force: true) }
    }

    @Published var cozyExtras: Bool {
        didSet { Settings.cozyExtras = cozyExtras; overlay.refresh(force: true) }
    }

    @Published var fallingLeaves: Bool {
        didSet { Settings.fallingLeaves = fallingLeaves }
    }

    @Published var sound: Bool {
        didSet { Settings.sound = sound }
    }

    @Published var pumpkinCount: Int {
        didSet { Settings.pumpkinCount = pumpkinCount; overlay.refresh(force: true) }
    }

    @Published var openAtLogin: Bool {
        didSet { updateLoginItem() }
    }

    var hasAccessibility: Bool { DockLocator.hasAccessibility }

    init() {
        Settings.registerDefaults()
        smashCount = Settings.smashCount
        showPumpkins = Settings.showPumpkins
        showVines = Settings.showVines
        cozyExtras = Settings.cozyExtras
        fallingLeaves = Settings.fallingLeaves
        sound = Settings.sound
        pumpkinCount = Settings.pumpkinCount
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func start() {
        overlay.onSmash = { [weak self] in
            Settings.smashCount += 1
            self?.smashCount = Settings.smashCount
        }
        // A menu bar app is never "active", so macOS may put it to sleep (App Nap) and slow
        // its timers to once every few seconds. Opt out so the pumpkins keep up with the Dock.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping the pumpkins in step with the Dock"
        )
        overlay.start()
    }

    func stop() {
        overlay.stop()
    }

    func regrow() {
        overlay.refresh(force: true)
    }

    func askForAccessibility() {
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
    }

    private func updateLoginItem() {
        let enabled = SMAppService.mainApp.status == .enabled
        guard openAtLogin != enabled else { return }
        do {
            if openAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
            openAtLogin = enabled
        }
    }
}
