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
            Key.theme: ThemeChoice.rotate(.everything).rawValue,
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
            case .halloween: return [.crypt, .tombstone, .blackCat, .cauldron, .candy, .candles, .skull]
            }
        }

        /// What some pumpkins sit up high on.
        var perch: DecorKind { self == .halloween ? .crypt : .hayBale }

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

        /// Seasons fill the year; festivals are short and take over the Dock while they're on.
        enum Kind { case season, festival }

        var kind: Kind {
            switch self {
            case .fall: return .season
            case .halloween: return .festival
            }
        }

        /// When it's on, as (month, day) pairs, both days included.
        var window: (start: (Int, Int), end: (Int, Int)) {
            switch self {
            case .fall: return ((9, 1), (11, 30))
            case .halloween: return ((10, 15), (11, 1))
            }
        }

        private var startDay: Int { Date.dayOfYear(window.start.0, window.start.1) }
        private var endDay: Int { Date.dayOfYear(window.end.0, window.end.1) }

        func isOn(_ date: Date) -> Bool {
            let today = date.dayOfYear
            return startDay <= endDay ? (startDay...endDay).contains(today) : today >= startDay || today <= endDay
        }

        /// Days from `date` back to the most recent day it was on (0 while it's on).
        func daysSinceOn(_ date: Date) -> Int {
            isOn(date) ? 0 : (date.dayOfYear - endDay + 365) % 365
        }

        /// Days from `date` to the next day it's on (0 while it's on).
        func daysUntilOn(_ date: Date) -> Int {
            isOn(date) ? 0 : (startDay - date.dayOfYear + 365) % 365
        }

        static func all(_ kind: Kind) -> [Theme] { allCases.filter { $0.kind == kind } }
    }

    /// How the Dock picks its theme: rotating through the calendar, or keeping one theme all year.
    enum ThemeChoice: Hashable {
        case rotate(Rotation)
        case keep(Theme)

        /// What rotates.
        enum Rotation: String, CaseIterable {
            /// Festivals while they're on, the season the rest of the time. Saved as "automatic", what
            /// it was called before the other rotations.
            case everything = "automatic"
            /// Just the seasons, following the calendar.
            case seasons
            /// Just the festivals: the one that's on, or else the next one coming up.
            case festivals

            var title: String {
                switch self {
                case .everything: return "Everything"
                case .seasons: return "Seasons"
                case .festivals: return "Festivals"
                }
            }

            var symbol: String {
                switch self {
                case .everything: return "calendar"
                case .seasons: return "leaf.arrow.triangle.circlepath"
                case .festivals: return "party.popper.fill"
                }
            }

            var detail: String {
                switch self {
                case .everything: return "Seasons, with festivals when they come around"
                case .seasons: return "Follows the seasons, no festivals"
                case .festivals: return "Always the next festival, never a plain season"
                }
            }

            /// The themes it goes through, in calendar order.
            var themes: [Theme] {
                let all: [Theme]
                switch self {
                case .everything: all = Theme.allCases
                case .seasons: all = Theme.all(.season)
                case .festivals: all = Theme.all(.festival)
                }
                return all.sorted { Date.dayOfYear($0.window.start.0, $0.window.start.1) < Date.dayOfYear($1.window.start.0, $1.window.start.1) }
            }

            func theme(on date: Date) -> Theme {
                let festival = Theme.all(.festival).first { $0.isOn(date) }
                // The season that's on, or else the one that ended most recently.
                let season = Theme.all(.season).min { $0.daysSinceOn(date) < $1.daysSinceOn(date) } ?? .fall
                switch self {
                case .everything: return festival ?? season
                case .seasons: return season
                case .festivals:
                    return Theme.all(.festival).min { $0.daysUntilOn(date) < $1.daysUntilOn(date) } ?? season
                }
            }

            /// The next time the theme changes, and to what (nil if it never does).
            func next(after date: Date) -> (theme: Theme, date: Date)? {
                let now = theme(on: date)
                for days in 1...366 {
                    let day = date.addingDays(days)
                    let theme = theme(on: day)
                    if theme != now { return (theme, Calendar.current.startOfDay(for: day)) }
                }
                return nil
            }
        }

        /// The rotations first, then each theme on its own.
        static var allCases: [ThemeChoice] { Rotation.allCases.map(rotate) + Theme.allCases.map(keep) }

        var rawValue: String {
            switch self {
            case let .rotate(rotation): return rotation.rawValue
            case let .keep(theme): return theme.rawValue
            }
        }

        init?(rawValue: String) {
            if let rotation = Rotation(rawValue: rawValue) { self = .rotate(rotation) }
            else if let theme = Theme(rawValue: rawValue) { self = .keep(theme) }
            else { return nil }
        }

        var title: String {
            switch self {
            case let .rotate(rotation): return rotation.title
            case let .keep(theme): return theme.title
            }
        }

        var symbol: String {
            switch self {
            case let .rotate(rotation): return rotation.symbol
            case let .keep(theme): return theme.symbol
            }
        }

        var isRotating: Bool { if case .rotate = self { return true } else { return false } }

        func theme(on date: Date) -> Theme {
            switch self {
            case let .rotate(rotation): return rotation.theme(on: date)
            case let .keep(theme): return theme
            }
        }
    }

    static var themeChoice: ThemeChoice {
        get { defaults.string(forKey: Key.theme).flatMap(ThemeChoice.init(rawValue:)) ?? .rotate(.everything) }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// The season on the Dock right now.
    static var theme: Theme {
        themeChoice.theme(on: Date())
    }
}

extension Date {
    /// Day of a 365-day year (February 29th counts as March 1st), so dates compare the same every year.
    static func dayOfYear(_ month: Int, _ day: Int) -> Int {
        let starts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let month = min(max(month, 1), 12)
        return min(starts[month - 1] + day, 365)
    }

    var dayOfYear: Int {
        let day = Calendar.current.dateComponents([.month, .day], from: self)
        return Date.dayOfYear(day.month ?? 1, day.day ?? 1)
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
