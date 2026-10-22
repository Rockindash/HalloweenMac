import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// Everything the menu and the app window show and change. Choices are saved in `Settings`.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    private let overlay = OverlayController()
    private let welcome = WelcomeWindow()
    private let mainWindow = MainWindow()
    private let wallpaper = WallpaperController()
    private var activity: NSObjectProtocol?
    private var licenseWatch: AnyCancellable?
    private var calendarTimer: Timer?
    private var dayWatch: NSObjectProtocol?

    let license = LicenseManager()
    let updater = Updater()

    /// Each theme's own count of smashes.
    @Published private(set) var smashCounts: [Settings.Theme: Int]
    /// The count for the theme on the Dock.
    var smashCount: Int { smashCounts[theme] ?? 0 }
    var totalSmashCount: Int { smashCounts.values.reduce(0, +) }
    /// The app's window is in full screen (its pages then start below the toolbar).
    @Published var isFullScreen = false
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

    /// The theme picked on the Themes page: Fall or Halloween all year, or changing with the calendar.
    @Published var themeChoice: Settings.ThemeChoice {
        didSet {
            Settings.themeChoice = themeChoice
            themeMayHaveChanged()
        }
    }

    /// The themes Change Automatically takes turns with.
    @Published private(set) var rotation: Set<Settings.Theme> {
        didSet {
            Settings.rotation = rotation
            themeMayHaveChanged()
        }
    }

    /// How many days before its day each festival goes on the Dock.
    @Published var festivalLead: Int {
        didSet {
            Settings.festivalLead = festivalLead
            themeMayHaveChanged()
        }
    }

    /// Whether `theme` can leave the rotation: any festival can, and any season but the last one left.
    func canLeaveRotation(_ theme: Settings.Theme) -> Bool { Settings.canLeave(theme, rotation) }

    /// Puts `theme` in the rotation or takes it out.
    func setInRotation(_ theme: Settings.Theme, _ isIn: Bool) {
        if isIn { rotation.insert(theme) } else if canLeaveRotation(theme) { rotation.remove(theme) }
    }

    /// The theme on the Dock right now.
    @Published private(set) var theme: Settings.Theme

    /// Switches the Dock, the desktop picture and the window to the theme that's on now, if it changed:
    /// after a new pick, or when the calendar turns the page.
    private func themeMayHaveChanged() {
        let now = Settings.theme
        guard now != theme else { return }
        theme = now
        overlay.changeTheme()
        wallpaper.refresh()
    }

    @Published var bats: Bool {
        didSet { Settings.bats = bats }
    }

    @Published var ghost: Bool {
        didSet { Settings.ghost = ghost; overlay.refresh(force: true) }
    }

    /// Haunting while you're away (Halloween). Switched off mid-haunting, the ghosts scatter at once.
    @Published var haunting: Bool {
        didSet { Settings.haunting = haunting; overlay.checkHaunting() }
    }

    /// Spirits of quit apps (Halloween).
    @Published var spirits: Bool {
        didSet { Settings.spirits = spirits }
    }

    /// Try It: haunt the Dock as soon as the Mac is left alone for a moment.
    func tryHaunting() {
        overlay.tryHaunting()
    }

    /// The desktop picture goes with the theme (the Background page).
    @Published var wallpaperEnabled: Bool {
        didSet { Settings.wallpaperEnabled = wallpaperEnabled; wallpaper.refresh() }
    }

    @Published var wallpaperMode: Settings.WallpaperMode {
        didSet { Settings.wallpaperMode = wallpaperMode; wallpaper.refresh() }
    }

    @Published var fallingLeaves: Bool {
        didSet { Settings.fallingLeaves = fallingLeaves; overlay.updateLeaves() }
    }

    /// How many leaves fall, from a few (0) to lots (1). Applies right away, without regrowing.
    @Published var leafAmount: Double {
        didSet { Settings.leafAmount = leafAmount; overlay.updateLeaves() }
    }

    @Published var leavesFillScreen: Bool {
        didSet { Settings.leavesFillScreen = leavesFillScreen; overlay.updateLeaves() }
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
        smashCounts = Self.savedSmashCounts()
        showPumpkins = Settings.showPumpkins
        showVines = Settings.showVines
        cozyExtras = Settings.cozyExtras
        squirrel = Settings.squirrel
        enabledExtras = Set(DecorKind.allCases.filter(Settings.isEnabled))
        showMenuBarIcon = Settings.showMenuBarIcon
        themeChoice = Settings.themeChoice
        rotation = Settings.rotation
        festivalLead = Settings.festivalLead
        theme = Settings.theme
        bats = Settings.bats
        ghost = Settings.ghost
        haunting = Settings.haunting
        spirits = Settings.spirits
        wallpaperEnabled = Settings.wallpaperEnabled
        wallpaperMode = Settings.wallpaperMode
        fallingLeaves = Settings.fallingLeaves
        leafAmount = Settings.leafAmount
        leavesFillScreen = Settings.leavesFillScreen
        sound = Settings.sound
        fullness = Settings.fullness
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func start() {
        overlay.onSmash = { [weak self] in self?.recordSmash() }
        overlay.isLicensed = license.isActive
        // The harvest comes and goes with the license, and the window and menu follow it too.
        licenseWatch = license.$key.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] key in
            guard let self else { return }
            self.objectWillChange.send()
            self.overlay.isLicensed = key != nil
            self.wallpaper.isLicensed = key != nil
        }
        license.start()
        // A menu bar app is never "active", so macOS may put it to sleep (App Nap) and slow
        // its timers to once every few seconds. Opt out so the pumpkins keep up with the Dock.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Keeping the pumpkins in step with the Dock"
        )
        overlay.onResume = { [weak self] in self?.isPaused = false }
        overlay.onAppearanceChange = { [weak self] in
            self?.appearance = Palette.appearance
            self?.wallpaper.refresh()
        }
        // In UI tests the harvest stays off the Dock: a pumpkin sitting under the app window's
        // lower edge would catch the tests' clicks. (The harvest itself has unit tests.)
        if !AppEnvironment.isUITesting { overlay.start() }
        appearance = Palette.appearance
        // After the overlay, which reads the Mac's Light/Dark setting the pictures follow.
        wallpaper.isLicensed = license.isActive
        wallpaper.start()
        // Changing with the calendar: switch themes when the day changes (at midnight, or on waking
        // up on a new day), with a regular check in case a change is missed.
        dayWatch = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.themeMayHaveChanged() }
        }
        calendarTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.themeMayHaveChanged() }
        }
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
    /// It counts for the theme on the Dock, which is also the one in the app window.
    func recordSmash() {
        Settings.setSmashCount(Settings.smashCount(for: theme) + 1, for: theme)
        smashCounts = Self.savedSmashCounts()
    }

    /// Every theme's count back to zero.
    func resetSmashCount() {
        Settings.Theme.allCases.forEach { Settings.setSmashCount(0, for: $0) }
        smashCounts = Self.savedSmashCounts()
    }

    private static func savedSmashCounts() -> [Settings.Theme: Int] {
        Dictionary(uniqueKeysWithValues: Settings.Theme.allCases.map { ($0, Settings.smashCount(for: $0)) })
    }

    /// Every option back to how it started, the smash count back to zero, and a fresh harvest.
    /// Open at login is left alone: it's a Mac setting the person chose in System Settings too.
    func resetEverything() {
        Settings.resetAll()
        smashCounts = Self.savedSmashCounts()
        showPumpkins = Settings.showPumpkins
        showVines = Settings.showVines
        cozyExtras = Settings.cozyExtras
        squirrel = Settings.squirrel
        enabledExtras = Set(DecorKind.allCases.filter(Settings.isEnabled))
        showMenuBarIcon = Settings.showMenuBarIcon
        themeChoice = Settings.themeChoice
        rotation = Settings.rotation
        festivalLead = Settings.festivalLead
        bats = Settings.bats
        ghost = Settings.ghost
        haunting = Settings.haunting
        spirits = Settings.spirits
        wallpaperEnabled = Settings.wallpaperEnabled
        wallpaperMode = Settings.wallpaperMode
        fallingLeaves = Settings.fallingLeaves
        leafAmount = Settings.leafAmount
        leavesFillScreen = Settings.leavesFillScreen
        sound = Settings.sound
        fullness = Settings.fullness
        overlay.refresh(force: true)
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
        Dockorate guesses how wide your Dock is. To measure it exactly, macOS needs you to allow \
        Dockorate under System Settings → Privacy & Security → Accessibility.

        Dockorate only reads the Dock's size. It never reads your screen or what you type.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            DockLocator.requestAccessibility()
        }
    }

    private func updateLoginItem() {
        // Tests never add Dockorate to the real login items.
        guard !AppEnvironment.isUITesting else { return }
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
