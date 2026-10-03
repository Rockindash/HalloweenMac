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

    /// Hay bales, leaf piles, acorns, apples, the mug and lantern, and the squirrel.
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
}
