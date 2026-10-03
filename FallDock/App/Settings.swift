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
        static let pumpkinCount = "pumpkinCount"
        static let smashCount = "smashCount"
    }

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.showPumpkins: true,
            Key.fallingLeaves: true,
            Key.showVines: true,
            Key.cozyExtras: true,
            Key.sound: true,
            Key.pumpkinCount: 10,
            Key.smashCount: 0,
        ])
        // "Plenty" used to mean 9 pumpkins; it's 10 now.
        if defaults.integer(forKey: Key.pumpkinCount) == 9 {
            defaults.set(10, forKey: Key.pumpkinCount)
        }
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

    static var pumpkinCount: Int {
        get { min(15, max(1, defaults.integer(forKey: Key.pumpkinCount))) }
        set { defaults.set(newValue, forKey: Key.pumpkinCount) }
    }

    static var smashCount: Int {
        get { defaults.integer(forKey: Key.smashCount) }
        set { defaults.set(newValue, forKey: Key.smashCount) }
    }
}
