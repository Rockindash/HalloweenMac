import CoreGraphics
import Foundation

/// User preferences, saved between launches.
enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let showPumpkins = "showPumpkins"
        static let fallingLeaves = "fallingLeaves"
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
    }

    static func registerDefaults() {
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
            Key.showVines: true,
            Key.cozyExtras: true,
            Key.squirrel: true,
            Key.bats: true,
            Key.ghost: true,
            Key.theme: ThemeChoice.automatic.rawValue,
            Key.showMenuBarIcon: true,
            Key.sound: true,
            Key.fullness: Fullness.plenty.rawValue,
            Key.smashCount: 0,
        ])
    }

    static var showPumpkins: Bool {
        get { defaults.bool(forKey: Key.showPumpkins) }
        set { defaults.set(newValue, forKey: Key.showPumpkins) }
    }

    static var fallingLeaves: Bool {
        get { defaults.bool(forKey: Key.fallingLeaves) }
        set { defaults.set(newValue, forKey: Key.fallingLeaves) }
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

    /// The current season's drifting things: falling leaves in fall, bats at Halloween.
    static var ambient: Bool { theme == .halloween ? bats : fallingLeaves }

    /// The current season's visitor: the squirrel in fall, the ghost at Halloween.
    static var visitor: Bool { theme == .halloween ? ghost : squirrel }

    /// The season or festival on the Dock. Each one has its own art, extras and tab in the app window.
    enum Theme: String, CaseIterable {
        case fall, halloween

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

        var subtitle: String {
            switch self {
            case .fall: return "Pumpkins, hay and falling leaves"
            case .halloween: return "Jack-o'-lanterns, candy and a friendly ghost"
            }
        }

        /// This season's extras, in the order their tiles show.
        var extras: [DecorKind] {
            switch self {
            case .fall: return [.hayBale, .leafPile, .acorns, .mug, .lantern, .apples]
            case .halloween: return [.stump, .tombstone, .blackCat, .cauldron, .candy, .candles, .skull]
            }
        }

        /// What some pumpkins sit up high on.
        var perch: DecorKind { self == .halloween ? .stump : .hayBale }

        /// The order extras fill the gaps between pumpkins; it starts at a random point each time the
        /// pumpkins are regrown.
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

        var vineTitle: String { self == .halloween ? "Purple dirt" : "Vine" }
        var vineDetail: String { self == .halloween ? "With cobwebs at both ends" : "Curling along the Dock" }
        var ambientTitle: String { self == .halloween ? "Bats" : "Falling leaves" }
        var ambientDetail: String { self == .halloween ? "Fluttering past" : "Drifting down" }
        var extrasTitle: String { self == .halloween ? "Spooky extras" : "Cozy extras" }
        var visitorTitle: String { self == .halloween ? "Ghost" : "Squirrel" }

        /// The season for a date when the choice is Automatic: Halloween from mid-October to
        /// November 1st, fall the rest of the time (for now).
        static func forDate(_ date: Date) -> Theme {
            let day = Calendar.current.dateComponents([.month, .day], from: date)
            if (day.month == 10 && (day.day ?? 0) >= 15) || (day.month == 11 && day.day == 1) { return .halloween }
            return .fall
        }
    }

    /// The season picked in the app window: one season, or Automatic to follow the calendar.
    enum ThemeChoice: String, CaseIterable {
        case automatic, fall, halloween

        var title: String {
            switch self {
            case .automatic: return "Automatic"
            case .fall: return Theme.fall.title
            case .halloween: return Theme.halloween.title
            }
        }

        var symbol: String {
            switch self {
            case .automatic: return "calendar"
            case .fall: return Theme.fall.symbol
            case .halloween: return Theme.halloween.symbol
            }
        }
    }

    static var themeChoice: ThemeChoice {
        get { defaults.string(forKey: Key.theme).flatMap(ThemeChoice.init(rawValue:)) ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// The season on the Dock right now.
    static var theme: Theme {
        switch themeChoice {
        case .automatic: return Theme.forDate(Date())
        case .fall: return .fall
        case .halloween: return .halloween
        }
    }
}
