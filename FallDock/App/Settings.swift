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
        static let bats = "bats"
        static let ghost = "ghost"
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
        // The menu used to pick a number of pumpkins; now it picks how full the Dock is. The old
        // setting is removed once carried over, so it's only ever there from Fall Dock. (Registered
        // defaults are shared by the whole app, so whether "fullness" was set can't be told reliably.)
        if defaults.object(forKey: Key.pumpkinCount) != nil {
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
            Key.bats: true,
            Key.ghost: true,
            // Fall stays on the Dock until the person picks Halloween or the calendar.
            Key.theme: ThemeChoice.keep(.fall).rawValue,
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
                    Key.squirrel, Key.showMenuBarIcon, Key.theme, Key.wallpaperEnabled, Key.wallpaperMode,
                    Key.bats, Key.ghost]
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

    /// Bats fluttering past (Halloween's version of falling leaves).
    static var bats: Bool {
        get { defaults.bool(forKey: Key.bats) }
        set { defaults.set(newValue, forKey: Key.bats) }
    }

    /// The friendly ghost that floats by (Halloween's version of the squirrel).
    static var ghost: Bool {
        get { defaults.bool(forKey: Key.ghost) }
        set { defaults.set(newValue, forKey: Key.ghost) }
    }

    /// The current theme's visitor: the squirrel in fall, the ghost at Halloween.
    static var visitor: Bool { theme == .halloween ? ghost : squirrel }

    /// The season or festival on the Dock. Each one has its own art, extras and desktop pictures.
    enum Theme: String, CaseIterable {
        /// The original look, and still the one Dockorate starts with.
        case fall
        case halloween

        var title: String {
            switch self {
            case .fall: return "Fall"
            case .halloween: return "Halloween"
            }
        }

        var symbol: String {
            switch self {
            case .fall: return "leaf.fill"
            case .halloween: return "moon.stars.fill"
            }
        }

        /// What grows on the Dock, as a page heading.
        var headline: String {
            switch self {
            case .fall: return "Pumpkins, Hay and Falling Leaves"
            case .halloween: return "Jack-o'-Lanterns, Candy and a Friendly Ghost"
            }
        }

        var subtitle: String {
            switch self {
            case .fall: return "Pumpkins, hay bales, a latte and falling leaves."
            case .halloween: return "Glowing jack-o'-lanterns, tombstones, candy, bats and a friendly ghost."
            }
        }

        /// This theme's extras, in the order their tiles show.
        var extras: [DecorKind] {
            switch self {
            case .fall: return [.hayBale, .leafPile, .acorns, .mug, .lantern, .apples]
            case .halloween: return [.crypt, .tombstone, .blackCat, .cauldron, .candy, .candles, .skull]
            }
        }

        /// What some pumpkins sit up high on.
        var perch: DecorKind { self == .halloween ? .crypt : .hayBale }

        /// The order extras fill the gaps between pumpkins; it starts at a random point each time the
        /// pumpkins are regrown, so the special ones turn up in different spots.
        var gapCycle: [DecorKind] {
            switch self {
            case .fall:
                return [.leafPile, .acorns, .mug, .apples, .leafPile, .lantern, .acorns, .apples, .leafPile, .acorns]
            case .halloween:
                return [.tombstone, .candy, .cauldron, .skull, .blackCat, .candles, .candy, .tombstone, .skull, .candy]
            }
        }

        /// Extras special enough to show up at most once every eight gaps.
        var specials: Set<DecorKind> { self == .halloween ? [.cauldron, .blackCat] : [.mug, .lantern] }

        var vineTitle: String { self == .halloween ? "Graveyard dirt" : "Vine" }
        var vineDetail: String {
            self == .halloween ? "Purple dirt along the top of the Dock, with cobwebs at both ends."
                               : "Curling along the top of the Dock, behind the pumpkins."
        }
        var extrasTitle: String { self == .halloween ? "Spooky extras" : "Cozy extras" }
        var extrasDetail: String {
            self == .halloween ? "Tombstones, candy, a cauldron and more between the pumpkins."
                               : "Hay bales, leaf piles and more between the pumpkins."
        }
        var visitorTitle: String { self == .halloween ? "Ghost" : "Squirrel" }

        /// When the calendar puts it on the Dock, as (month, day) pairs, both days included. Halloween
        /// takes over for its fortnight; Fall is on the rest of the time.
        var window: (start: (month: Int, day: Int), end: (month: Int, day: Int))? {
            switch self {
            case .fall: return nil
            case .halloween: return ((10, 15), (11, 1))
            }
        }

        func isOn(_ date: Date, calendar: Calendar = .current) -> Bool {
            guard let window else { return false }
            let day = calendar.dateComponents([.month, .day], from: date)
            let today = (day.month ?? 1) * 100 + (day.day ?? 1)
            let start = window.start.month * 100 + window.start.day, end = window.end.month * 100 + window.end.day
            return start <= end ? (start...end).contains(today) : today >= start || today <= end
        }
    }

    /// How the Dock picks its theme: keeping one all year, or changing with the calendar.
    enum ThemeChoice: Hashable {
        case keep(Theme)
        /// Halloween while it's on, Fall the rest of the year.
        case calendar

        static var allCases: [ThemeChoice] { Theme.allCases.map(keep) + [.calendar] }

        /// Saved as the theme's name, or "automatic" (what the Halloween branch called the calendar).
        var rawValue: String {
            switch self {
            case let .keep(theme): return theme.rawValue
            case .calendar: return "automatic"
            }
        }

        init?(rawValue: String) {
            if let theme = Theme(rawValue: rawValue) { self = .keep(theme) }
            else if rawValue == "automatic" { self = .calendar }
            else { return nil }
        }

        var title: String {
            switch self {
            case let .keep(theme): return theme.title
            case .calendar: return "Change with the Calendar"
            }
        }

        func theme(on date: Date, calendar: Calendar = .current) -> Theme {
            switch self {
            case let .keep(theme): return theme
            case .calendar: return Theme.allCases.first { $0.isOn(date, calendar: calendar) } ?? .fall
            }
        }

        /// The next time the calendar changes the theme, and to what (nil when it never changes).
        func next(after date: Date, calendar: Calendar = .current) -> (theme: Theme, date: Date)? {
            guard self == .calendar else { return nil }
            let now = theme(on: date, calendar: calendar)
            for days in 1...366 {
                guard let day = calendar.date(byAdding: .day, value: days, to: date) else { break }
                let theme = theme(on: day, calendar: calendar)
                if theme != now { return (theme, calendar.startOfDay(for: day)) }
            }
            return nil
        }
    }

    static var themeChoice: ThemeChoice {
        get { defaults.string(forKey: Key.theme).flatMap(ThemeChoice.init(rawValue:)) ?? .keep(.fall) }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// The theme on the Dock right now.
    static var theme: Theme { themeChoice.theme(on: Date()) }

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
