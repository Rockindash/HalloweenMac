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
        static let smashCount = "smashCount" // Fall's; every other theme adds ".<theme>"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let disabledExtras = "disabledExtras"
        static let squirrel = "squirrel"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let theme = "theme"
        static let themesLeftOut = "themesLeftOut"
        static let festivalLead = "festivalLead"
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
            Key.wallpaperEnabled: false,
            Key.wallpaperMode: WallpaperMode.matchDock.rawValue,
        ])
    }

    /// Puts every option back the way it was on first launch and clears the smash count.
    /// The welcome isn't shown again.
    static func resetAll() {
        let keys = [Key.showPumpkins, Key.fallingLeaves, Key.leafAmount, Key.leavesFillScreen, Key.showVines,
                    Key.cozyExtras, Key.sound, Key.pumpkinCount, Key.fullness, Key.smashCount, Key.disabledExtras,
                    Key.squirrel, Key.showMenuBarIcon, Key.theme, Key.themesLeftOut, Key.festivalLead, Key.wallpaperEnabled, Key.wallpaperMode,
                    Key.bats, Key.ghost] + Theme.allCases.map(smashCountKey)
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

    /// Each theme counts its own smashes. Fall keeps the original count, which was all Fall's before
    /// there were other themes.
    static func smashCountKey(for theme: Theme) -> String {
        theme == .fall ? Key.smashCount : "\(Key.smashCount).\(theme.rawValue)"
    }

    static func smashCount(for theme: Theme) -> Int {
        defaults.integer(forKey: smashCountKey(for: theme))
    }

    static func setSmashCount(_ count: Int, for theme: Theme) {
        defaults.set(count, forKey: smashCountKey(for: theme))
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

        /// How many of what gets smashed in this theme, like "1 pumpkin" or "3 jack-o'-lanterns".
        func smashed(_ count: Int) -> String {
            switch self {
            case .fall: return count == 1 ? "1 pumpkin" : "\(count) pumpkins"
            case .halloween: return count == 1 ? "1 jack-o'-lantern" : "\(count) jack-o'-lanterns"
            }
        }

        /// The Home card's title for the count, like "No Pumpkins Smashed Yet" or "3 Jack-o'-Lanterns Smashed".
        func smashedTitle(_ count: Int) -> String {
            let things: String
            switch self {
            case .fall: things = count == 1 ? "Pumpkin" : "Pumpkins"
            case .halloween: things = count == 1 ? "Jack-o'-Lantern" : "Jack-o'-Lanterns"
            }
            return count == 0 ? "No \(things) Smashed Yet" : "\(count) \(things) Smashed"
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
            self == .halloween ? "Purple dirt along the top of the Dock, with a cobweb in each top corner."
                               : "Curling along the top of the Dock, behind the pumpkins."
        }
        var extrasTitle: String { self == .halloween ? "Spooky extras" : "Cozy extras" }
        var extrasDetail: String {
            self == .halloween ? "Tombstones, candy, a cauldron and more between the pumpkins."
                               : "Hay bales, leaf piles and more between the pumpkins."
        }
        var visitorTitle: String { self == .halloween ? "Ghost" : "Squirrel" }

        /// Seasons take turns through the year; a festival takes over for the week before its day.
        enum Kind: CaseIterable {
            case season, festival

            var title: String { self == .season ? "Seasons" : "Festivals" }
        }

        var kind: Kind { self == .halloween ? .festival : .season }

        /// The day a season starts each year, as (month, day). It stays on until the next season starts,
        /// so with Fall the only season so far, Fall is on all year between festivals.
        var seasonStart: (month: Int, day: Int)? {
            switch self {
            case .fall: return (9, 1)
            case .halloween: return nil
            }
        }

        /// A festival's day in `year`. (Some festivals move from year to year, so it's worked out per year.)
        func festivalDay(in year: Int, calendar: Calendar = .current) -> Date? {
            switch self {
            case .fall: return nil
            case .halloween: return calendar.date(from: DateComponents(year: year, month: 10, day: 31))
            }
        }

        /// The days a festival is on the Dock in `year`: from `lead` days before its day (the person's
        /// pick, a week to start with), through the day itself.
        func festivalDays(in year: Int, lead: Int = Settings.festivalLead, calendar: Calendar = .current) -> ClosedRange<Date>? {
            guard let day = festivalDay(in: year, calendar: calendar),
                  let start = calendar.date(byAdding: .day, value: -lead, to: day) else { return nil }
            return calendar.startOfDay(for: start)...calendar.startOfDay(for: day)
        }

        static var seasons: [Theme] { allCases.filter { $0.kind == .season } }
        static var festivals: [Theme] { allCases.filter { $0.kind == .festival } }

        /// The festival whose days `date` falls in, if any, out of `themes`, each going on `lead` days
        /// before its day. If two overlap, the festival that comes first wins.
        static func festival(on date: Date, among themes: Set<Theme> = Set(allCases), lead: Int = Settings.festivalLead,
                             calendar: Calendar = .current) -> Theme? {
            let day = calendar.startOfDay(for: date)
            let year = calendar.component(.year, from: date)
            // A festival early in January starts showing in the last days of December.
            let weeks = festivals.filter(themes.contains).flatMap { theme in
                [year, year + 1].compactMap { theme.festivalDays(in: $0, lead: lead, calendar: calendar) }.map { (theme, $0) }
            }
            return weeks.filter { $0.1.contains(day) }.min { $0.1.upperBound < $1.1.upperBound }?.0
        }

        /// The season on `date`, out of `themes`: the one that started most recently. A season left out
        /// is skipped, so the one before it stays on longer.
        static func season(on date: Date, among themes: Set<Theme> = Set(allCases), calendar: Calendar = .current) -> Theme {
            let parts = calendar.dateComponents([.month, .day], from: date)
            let today = (parts.month ?? 1) * 100 + (parts.day ?? 1)
            let starts = seasons.filter(themes.contains).compactMap { theme in theme.seasonStart.map { (theme, $0.month * 100 + $0.day) } }
                .sorted { $0.1 < $1.1 }
            // Before the first season of the year starts, last year's last season is still on.
            return (starts.last { $0.1 <= today } ?? starts.last)?.0 ?? .fall
        }
    }

    /// How the Dock picks its theme: keeping one all year, or changing automatically.
    enum ThemeChoice: Hashable {
        case keep(Theme)
        /// The season, with each festival taking over for the week before its day.
        case automatic

        static var allCases: [ThemeChoice] { Theme.allCases.map(keep) + [.automatic] }

        /// Saved as the theme's name, or "automatic".
        var rawValue: String {
            switch self {
            case let .keep(theme): return theme.rawValue
            case .automatic: return "automatic"
            }
        }

        init?(rawValue: String) {
            if let theme = Theme(rawValue: rawValue) { self = .keep(theme) }
            else if rawValue == "automatic" { self = .automatic }
            else { return nil }
        }

        var title: String {
            switch self {
            case let .keep(theme): return theme.title
            case .automatic: return "Change Automatically"
            }
        }

        /// The theme on `date`. Changing automatically, it picks from the themes in `rotation`, each
        /// festival going on `lead` days before its day.
        func theme(on date: Date, rotation: Set<Theme> = Settings.rotation, lead: Int = Settings.festivalLead,
                   calendar: Calendar = .current) -> Theme {
            switch self {
            case let .keep(theme): return theme
            case .automatic:
                return Theme.festival(on: date, among: rotation, lead: lead, calendar: calendar)
                    ?? Theme.season(on: date, among: rotation, calendar: calendar)
            }
        }

        /// The next time the theme changes by itself, and to what (nil when it never changes).
        func next(after date: Date, rotation: Set<Theme> = Settings.rotation, lead: Int = Settings.festivalLead,
                  calendar: Calendar = .current) -> (theme: Theme, date: Date)? {
            guard self == .automatic else { return nil }
            let now = theme(on: date, rotation: rotation, lead: lead, calendar: calendar)
            for days in 1...366 {
                guard let day = calendar.date(byAdding: .day, value: days, to: date) else { break }
                let theme = theme(on: day, rotation: rotation, lead: lead, calendar: calendar)
                if theme != now { return (theme, calendar.startOfDay(for: day)) }
            }
            return nil
        }

        /// The next `count` changes, in order (none when one theme is kept).
        func changes(after date: Date, count: Int, rotation: Set<Theme> = Settings.rotation, lead: Int = Settings.festivalLead,
                     calendar: Calendar = .current) -> [(theme: Theme, date: Date)] {
            var changes: [(theme: Theme, date: Date)] = []
            var from = date
            while changes.count < count, let change = next(after: from, rotation: rotation, lead: lead, calendar: calendar) {
                changes.append(change)
                from = change.date
            }
            return changes
        }
    }

    static var themeChoice: ThemeChoice {
        get { defaults.string(forKey: Key.theme).flatMap(ThemeChoice.init(rawValue:)) ?? .keep(.fall) }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// The theme on the Dock right now.
    static var theme: Theme { themeChoice.theme(on: Date()) }

    /// The themes Change Automatically takes turns with. Every theme is in it until the person leaves
    /// one out, so themes added in an update join by themselves. (Saved as the ones left out.) At least
    /// one season always stays in, for the days between festivals: the original, Fall, if none is.
    static var rotation: Set<Theme> {
        get {
            let leftOut = Set((defaults.stringArray(forKey: Key.themesLeftOut) ?? []).compactMap(Theme.init(rawValue:)))
            var themes = Set(Theme.allCases).subtracting(leftOut)
            if !themes.contains(where: { $0.kind == .season }) { themes.insert(.fall) }
            return themes
        }
        set { defaults.set(Theme.allCases.filter { !newValue.contains($0) }.map(\.rawValue), forKey: Key.themesLeftOut) }
    }

    /// The choices for how many days before its day each festival goes on the Dock.
    static let festivalLeads = [3, 7, 14, 21, 30]

    /// How many days before its day each festival goes on the Dock: a week, unless the person picks
    /// another of `festivalLeads`.
    static var festivalLead: Int {
        get {
            let days = defaults.object(forKey: Key.festivalLead) as? Int ?? 7
            return (0...60).contains(days) ? days : 7
        }
        set { defaults.set(newValue, forKey: Key.festivalLead) }
    }

    /// Whether `theme` can leave `rotation`: any festival can, and any season but the last one in it.
    static func canLeave(_ theme: Theme, _ rotation: Set<Theme>) -> Bool {
        theme.kind == .festival || rotation.contains { $0 != theme && $0.kind == .season }
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
