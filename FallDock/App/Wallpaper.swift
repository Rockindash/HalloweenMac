import AppKit

/// Sets the desktop picture to the theme's light or dark picture while Background is switched on,
/// and puts the person's own picture back when it's switched off.
///
/// macOS only changes the picture of the space that's showing on each display, so it's set again
/// whenever the space, the displays or the Mac's Light/Dark setting change. The person's own picture
/// for each display is saved (in `Settings`) the first time it's replaced, and stays saved until
/// Background is switched on again, so spaces that still show the theme's picture after it's switched
/// off get theirs back as soon as they're visited.
@MainActor
final class WallpaperController {
    /// Whether Dockorate may change the desktop at all (it needs a license).
    var isLicensed = false {
        didSet { if isLicensed != oldValue { refresh() } }
    }

    private var wasOn = false
    private var observers: [NSObjectProtocol] = []
    /// Counts refreshes, so a slow one that finishes after a newer one doesn't undo it.
    private var generation = 0
    private let queue = DispatchQueue(label: "Dockorate.wallpaper", qos: .utility)

    private var isOn: Bool { isLicensed && Settings.wallpaperEnabled }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let onChange: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observers = [
            workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onChange),
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: onChange),
            NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                                   queue: .main, using: onChange),
        ]
        refresh()
    }

    /// The light or dark picture, following the Mac's Light/Dark setting unless one was picked.
    static var appearance: Palette.Appearance {
        switch Settings.wallpaperMode {
        case .matchDock: return Palette.appearance
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Brings every display in line with the current choices.
    func refresh() {
        // Tests never change the real desktop.
        guard !AppEnvironment.isUITesting, !AppEnvironment.isUnitTesting else { return }
        generation += 1
        let on = isOn
        defer { wasOn = on }
        guard on else {
            restore()
            return
        }
        // Just switched on: the pictures showing now are the ones to bring back later.
        if !wasOn { forgetOriginalsNotShowing() }

        let theme = Settings.theme
        let appearance = Self.appearance
        let screens = NSScreen.screens.compactMap { screen -> (key: String, pixels: CGSize)? in
            guard let key = Self.key(for: screen) else { return nil }
            return (key, CGSize(width: screen.frame.width * screen.backingScaleFactor,
                                height: screen.frame.height * screen.backingScaleFactor))
        }
        let thisRefresh = generation
        // Drawing a picture for a big display takes a moment, so it's done in the background.
        queue.async {
            let files = screens.compactMap { screen in
                WallpaperArt.file(for: theme, appearance, pixels: screen.pixels).map { (screen.key, $0) }
            }
            Task { @MainActor [weak self] in
                guard let self, self.generation == thisRefresh, self.isOn else { return }
                self.apply(Dictionary(files, uniquingKeysWith: { a, _ in a }))
            }
        }
    }

    private func apply(_ files: [String: URL]) {
        let workspace = NSWorkspace.shared
        var originals = Settings.wallpaperOriginals
        for screen in NSScreen.screens {
            guard let key = Self.key(for: screen), let file = files[key] else { continue }
            let current = workspace.desktopImageURL(for: screen)
            if current == file { continue }
            if let current, !WallpaperArt.isOurs(current), originals[key] == nil {
                originals[key] = Settings.SavedWallpaper(url: current, options: workspace.desktopImageOptions(for: screen) ?? [:])
            }
            try? workspace.setDesktopImageURL(file, for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true,
            ])
        }
        Settings.wallpaperOriginals = originals
    }

    /// Puts the person's own picture back on every display that's showing one of Dockorate's.
    private func restore() {
        let workspace = NSWorkspace.shared
        let originals = Settings.wallpaperOriginals
        for screen in NSScreen.screens where WallpaperArt.isOurs(workspace.desktopImageURL(for: screen)) {
            // A display that wasn't connected when the picture was saved gets another display's picture.
            guard let saved = Self.key(for: screen).flatMap({ originals[$0] }) ?? originals.values.first else { continue }
            try? workspace.setDesktopImageURL(saved.url, for: screen, options: saved.options)
        }
    }

    /// Drops saved pictures for displays now showing something else, so the newest choice is the one kept.
    private func forgetOriginalsNotShowing() {
        let workspace = NSWorkspace.shared
        var originals = Settings.wallpaperOriginals
        for screen in NSScreen.screens {
            guard let key = Self.key(for: screen), !WallpaperArt.isOurs(workspace.desktopImageURL(for: screen)) else { continue }
            originals[key] = nil
        }
        Settings.wallpaperOriginals = originals
    }

    /// A name for the display that stays the same between launches and when it's plugged in again.
    private static func key(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
