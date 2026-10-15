import AppKit

/// User preferences, saved between launches.
enum Settings {
    /// Where choices are kept. The tests swap in a place of their own (see `AppEnvironment`).
    static var defaults: UserDefaults = AppEnvironment.isUITesting ? AppEnvironment.uiTestDefaults() : .standard

    private enum Key {
        static let showPumpkins = "showPumpkins"
        static let fallingLeaves = "fallingLeaves"
        static let leafAmount = "leafAmount"
        static let leavesFillScreen = "leavesFillScreen"
        static let showVines = "showVines"
        static let cozyExtras = "cozyExtras"
        static let sound = "sound"
        static let pumpkinCount = "pumpkinCount" // replaced by fullness; read once to carry it over
        static let fullness = "fullness"
        static let smashCount = "smashCount"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let disabledExtras = "disabledExtras"
        static let squirrel = "squirrel"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let theme = "theme"
        static let wallpaperEnabled = "wallpaperEnabled"
        static let wallpaperMode = "wallpaperMode"
        static let wallpaperOriginals = "wallpaperOriginals"
    }

    /// The app was called Fall Dock, with the bundle ID com.amol.falldock, before it shipped. The first
    /// time Dockorate starts, it brings over that app's choices and smash count.
    private static func carryOverFromFallDock() {
        let oldDomain = "com.amol.falldock"
        guard let newDomain = Bundle.main.bundleIdentifier, newDomain != oldDomain,
              (defaults.persistentDomain(forName: newDomain) ?? [:]).isEmpty,
              let old = defaults.persistentDomain(forName: oldDomain), !old.isEmpty else { return }
        defaults.setPersistentDomain(old, forName: newDomain)
    }

    static func registerDefaults() {
        carryOverFromFallDock()
        // The menu used to pick a number of pumpkins; now it picks how full the Dock is.
        // (Checked before registering defaults, which would make every key look set.)
        if defaults.object(forKey: Key.fullness) == nil, defaults.object(forKey: Key.pumpkinCount) != nil {
            let count = defaults.integer(forKey: Key.pumpkinCount)
            defaults.set((count <= 6 ? Fullness.aFew : count >= 12 ? .overflowing : .plenty).rawValue, forKey: Key.fullness)
            defaults.removeObject(forKey: Key.pumpkinCount)
        }
        defaults.register(defaults: [
            Key.showPumpkins: true,
            Key.fallingLeaves: true,
            Key.leafAmount: 0.5,
            Key.leavesFillScreen: false,
            Key.showVines: true,
            Key.cozyExtras: true,
            Key.squirrel: true,
            Key.showMenuBarIcon: true,
            Key.sound: true,
            Key.fullness: Fullness.plenty.rawValue,
            Key.smashCount: 0,
            Key.wallpaperEnabled: false,
            Key.wallpaperMode: WallpaperMode.matchDock.rawValue,
        ])
    }

    /// Puts every option back the way it was on first launch and clears the smash count.
    /// The welcome isn't shown again.
    static func resetAll() {
        let keys = [Key.showPumpkins, Key.fallingLeaves, Key.leafAmount, Key.leavesFillScreen, Key.showVines,
                    Key.cozyExtras, Key.sound, Key.pumpkinCount, Key.fullness, Key.smashCount, Key.disabledExtras,
                    Key.squirrel, Key.showMenuBarIcon, Key.theme, Key.wallpaperEnabled, Key.wallpaperMode]
        keys.forEach(defaults.removeObject(forKey:))
    }

    static var showPumpkins: Bool {
        get { defaults.bool(forKey: Key.showPumpkins) }
        set { defaults.set(newValue, forKey: Key.showPumpkins) }
    }

    static var fallingLeaves: Bool {
        get { defaults.bool(forKey: Key.fallingLeaves) }
        set { defaults.set(newValue, forKey: Key.fallingLeaves) }
    }

    /// How many leaves fall, from a few (0) to lots (1). The middle is the original amount.
    static var leafAmount: Double {
        get { defaults.double(forKey: Key.leafAmount).clamped(to: 0...1) }
        set { defaults.set(newValue.clamped(to: 0...1), forKey: Key.leafAmount) }
    }

    /// How many times more often leaves fall than the original amount: ¼× to 4×.
    static var leafRate: Double { pow(4, leafAmount * 2 - 1) }

    /// Leaves fall across the whole screen the Dock is on, not just above the Dock.
    static var leavesFillScreen: Bool {
        get { defaults.bool(forKey: Key.leavesFillScreen) }
        set { defaults.set(newValue, forKey: Key.leavesFillScreen) }
    }

    static var showVines: Bool {
        get { defaults.bool(forKey: Key.showVines) }
        set { defaults.set(newValue, forKey: Key.showVines) }
    }

    /// Hay bales, leaf piles, acorns, apples, the pumpkin spice latte and lantern, and the squirrel.
    static var cozyExtras: Bool {
        get { defaults.bool(forKey: Key.cozyExtras) }
        set { defaults.set(newValue, forKey: Key.cozyExtras) }
    }

    static var sound: Bool {
        get { defaults.bool(forKey: Key.sound) }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    /// How closely pumpkins and extras are packed. Their size stays the same; a longer Dock fits more of them.
    enum Fullness: Int, CaseIterable {
        case aFew, plenty, overflowing

        var title: String {
            switch self {
            case .aFew: return "A Few"
            case .plenty: return "Plenty"
            case .overflowing: return "Overflowing"
            }
        }

        /// The smallest space between neighbors, as a fraction of a pumpkin's height.
        var spacing: CGFloat {
            switch self {
            case .aFew: return 0.9
            case .plenty: return 0.16
            case .overflowing: return 0.03
            }
        }
    }

    static var fullness: Fullness {
        get { Fullness(rawValue: defaults.integer(forKey: Key.fullness)) ?? .plenty }
        set { defaults.set(newValue.rawValue, forKey: Key.fullness) }
    }

    static var smashCount: Int {
        get { defaults.integer(forKey: Key.smashCount) }
        set { defaults.set(newValue, forKey: Key.smashCount) }
    }

    static var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Key.hasSeenWelcome) }
        set { defaults.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    /// Cozy extras that have been switched off one by one (the rest are on, including any new ones).
    static func isEnabled(_ kind: DecorKind) -> Bool {
        !(defaults.stringArray(forKey: Key.disabledExtras) ?? []).contains(kind.rawValue)
    }

    static func setEnabled(_ kind: DecorKind, _ enabled: Bool) {
        var off = Set(defaults.stringArray(forKey: Key.disabledExtras) ?? [])
        if enabled { off.remove(kind.rawValue) } else { off.insert(kind.rawValue) }
        defaults.set(off.sorted(), forKey: Key.disabledExtras)
    }

    static var squirrel: Bool {
        get { defaults.bool(forKey: Key.squirrel) }
        set { defaults.set(newValue, forKey: Key.squirrel) }
    }

    static var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Key.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: Key.showMenuBarIcon) }
    }

    /// The season or festival on the Dock. Only fall so far; each one gets its own tab in the app window.
    enum Theme: String, CaseIterable {
        case fall

        var title: String {
            switch self {
            case .fall: return "Fall"
            }
        }

        var symbol: String {
            switch self {
            case .fall: return "leaf.fill"
            }
        }
    }

    static var theme: Theme {
        get { defaults.string(forKey: Key.theme).flatMap(Theme.init(rawValue:)) ?? .fall }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    // MARK: Background

    /// Whether the desktop picture is set to go with the theme. Off until the person switches it on.
    static var wallpaperEnabled: Bool {
        get { defaults.bool(forKey: Key.wallpaperEnabled) }
        set { defaults.set(newValue, forKey: Key.wallpaperEnabled) }
    }

    /// Which of the theme's two pictures shows: the one that matches the Dock's Light or Dark look, or always one.
    enum WallpaperMode: String, CaseIterable {
        case matchDock, light, dark
    }

    static var wallpaperMode: WallpaperMode {
        get { defaults.string(forKey: Key.wallpaperMode).flatMap(WallpaperMode.init(rawValue:)) ?? .matchDock }
        set { defaults.set(newValue.rawValue, forKey: Key.wallpaperMode) }
    }

    /// The person's own desktop picture on a display, and how it was fitted to the screen.
    struct SavedWallpaper {
        var url: URL
        var options: [NSWorkspace.DesktopImageOptionKey: Any]

        fileprivate var plist: [String: Any] {
            var plist: [String: Any] = ["url": url.absoluteString]
            if let scaling = options[.imageScaling] as? NSNumber { plist["scaling"] = scaling }
            if let clipping = options[.allowClipping] as? NSNumber { plist["clipping"] = clipping }
            if let color = options[.fillColor] as? NSColor,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
                plist["fillColor"] = data
            }
            return plist
        }

        init(url: URL, options: [NSWorkspace.DesktopImageOptionKey: Any]) {
            self.url = url
            self.options = options
        }

        fileprivate init?(plist: [String: Any]) {
            guard let string = plist["url"] as? String, let url = URL(string: string) else { return nil }
            self.url = url
            options = [:]
            if let scaling = plist["scaling"] as? NSNumber { options[.imageScaling] = scaling }
            if let clipping = plist["clipping"] as? NSNumber { options[.allowClipping] = clipping }
            if let data = plist["fillColor"] as? Data,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                options[.fillColor] = color
            }
        }
    }

    /// The person's own desktop pictures, by display, to put back when Background is switched off.
    /// Not cleared by Reset Everything, which switches Background off and needs these to do it.
    static var wallpaperOriginals: [String: SavedWallpaper] {
        get {
            let stored = defaults.dictionary(forKey: Key.wallpaperOriginals) as? [String: [String: Any]] ?? [:]
            return stored.compactMapValues(SavedWallpaper.init(plist:))
        }
        set { defaults.set(newValue.mapValues(\.plist), forKey: Key.wallpaperOriginals) }
    }
}
