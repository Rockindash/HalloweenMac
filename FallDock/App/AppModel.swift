import AppKit
import ServiceManagement
import SwiftUI

/// Everything the menu and the app window show and change. Choices are saved in `Settings`.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    private let overlay = OverlayController()
    private let welcome = WelcomeWindow()
    private let mainWindow = MainWindow()
    private var activity: NSObjectProtocol?
    private var seasonTimer: Timer?

    @Published private(set) var smashCount: Int
    @Published private(set) var isPaused = false
    /// The Mac's Light or Dark setting, which the art follows.
    @Published private(set) var appearance = Palette.Appearance.dark

    @Published var showPumpkins: Bool {
        didSet { Settings.showPumpkins = showPumpkins; overlay.refresh() }
    }

    @Published var showVines: Bool {
        didSet { Settings.showVines = showVines; overlay.refresh(force: true) }
    }

    @Published var cozyExtras: Bool {
        didSet { Settings.cozyExtras = cozyExtras; overlay.refresh(force: true) }
    }

    @Published var squirrel: Bool {
        didSet { Settings.squirrel = squirrel; overlay.refresh(force: true) }
    }

    /// Which cozy extras are switched on, one by one.
    @Published private(set) var enabledExtras: Set<DecorKind>

    func setExtra(_ kind: DecorKind, enabled: Bool) {
        Settings.setEnabled(kind, enabled)
        if enabled { enabledExtras.insert(kind) } else { enabledExtras.remove(kind) }
        overlay.refresh(force: true)
    }

    @Published var showMenuBarIcon: Bool {
        didSet { Settings.showMenuBarIcon = showMenuBarIcon }
    }

    /// The season picked in the app window: one season, or Automatic to follow the calendar.
    @Published var themeChoice: Settings.ThemeChoice {
        didSet {
            Settings.themeChoice = themeChoice
            seasonChanged()
        }
    }

    /// The season on the Dock right now.
    @Published private(set) var theme: Settings.Theme

    private func seasonChanged() {
        let old = theme
        theme = Settings.theme
        guard theme != old else { return }
        mainWindow.themeChanged()
        overlay.refresh(force: true)
    }

    @Published var bats: Bool {
        didSet { Settings.bats = bats }
    }

    @Published var ghost: Bool {
        didSet { Settings.ghost = ghost; overlay.refresh(force: true) }
    }

    @Published var fallingLeaves: Bool {
        didSet { Settings.fallingLeaves = fallingLeaves }
    }

    @Published var sound: Bool {
        didSet { Settings.sound = sound }
    }

    @Published var fullness: Settings.Fullness {
        didSet { Settings.fullness = fullness; overlay.refresh(force: true) }
    }

    @Published var openAtLogin: Bool {
        didSet { updateLoginItem() }
    }

    var hasAccessibility: Bool { DockLocator.hasAccessibility }

    private init() {
        Settings.registerDefaults()
        smashCount = Settings.smashCount
        showPumpkins = Settings.showPumpkins
        showVines = Settings.showVines
        cozyExtras = Settings.cozyExtras
        squirrel = Settings.squirrel
        enabledExtras = Set(DecorKind.allCases.filter(Settings.isEnabled))
        showMenuBarIcon = Settings.showMenuBarIcon
        themeChoice = Settings.themeChoice
        theme = Settings.theme
        bats = Settings.bats
        ghost = Settings.ghost
        fallingLeaves = Settings.fallingLeaves
        sound = Settings.sound
        fullness = Settings.fullness
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func start() {
        overlay.onSmash = { [weak self] in self?.recordSmash() }
        // A menu bar app is never "active", so macOS may put it to sleep (App Nap) and slow
        // its timers to once every few seconds. Opt out so the pumpkins keep up with the Dock.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping the pumpkins in step with the Dock"
        )
        overlay.onResume = { [weak self] in self?.isPaused = false }
        overlay.onAppearanceChange = { [weak self] in self?.appearance = Palette.appearance }
        overlay.start()
        // With Automatic, the season changes by itself when the date comes round.
        seasonTimer = Timer.scheduledTimer(withTimeInterval: 60 * 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seasonChanged() }
        }
        appearance = Palette.appearance
    }

    func stop() {
        overlay.stop()
    }

    func showWelcome() {
        welcome.show(model: self)
    }

    func showMainWindow() {
        mainWindow.show(model: self)
    }

    var dockStatus: OverlayController.Status { overlay.status }

    /// Measures the Dock again right away.
    func remeasure() {
        overlay.refresh()
    }

    /// A pumpkin was smashed, on the Dock or in the app window's little harvest.
    func recordSmash() {
        Settings.smashCount += 1
        smashCount = Settings.smashCount
    }

    func resetSmashCount() {
        Settings.smashCount = 0
        smashCount = 0
    }

    func pauseForAnHour() {
        overlay.pause(for: 60 * 60)
        isPaused = true
    }

    func resume() {
        overlay.pause(for: nil)
        isPaused = false
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
