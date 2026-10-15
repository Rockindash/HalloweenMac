import XCTest
@testable import Dockorate

/// A test case whose `Settings` live in a fresh, empty place of their own, so tests never read or
/// change the real app's choices and never depend on each other.
class SettingsTestCase: XCTestCase {
    private var suiteNames: [String] = []
    private var realDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        realDefaults = Settings.defaults
        useFreshDefaults()
        Settings.registerDefaults()
    }

    override func tearDown() {
        for name in suiteNames {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        suiteNames = []
        Settings.defaults = realDefaults
        super.tearDown()
    }

    /// Swaps in an empty place for settings, with nothing registered yet: like a Mac that has never run the app.
    func useFreshDefaults() {
        let name = "DockorateTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        Settings.defaults = defaults
    }

    /// The test's own defaults, to set values the way an older version of the app would have.
    var defaults: UserDefaults { Settings.defaults }
}

extension CGColor {
    /// The color as 0–255 red, green and blue, for comparing with hex values.
    var rgb255: [Int] {
        let srgb = converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? self
        return (srgb.components ?? []).prefix(3).map { Int(($0 * 255).rounded()) }
    }
}

func rgb255(_ hex: UInt32) -> [Int] {
    [Int((hex >> 16) & 0xFF), Int((hex >> 8) & 0xFF), Int(hex & 0xFF)]
}

/// Whether two colors are within `tolerance` (0–255) on every channel.
func XCTAssertColor(_ actual: [Int], _ expected: [Int], tolerance: Int = 2, _ message: String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    let close = actual.count == expected.count && zip(actual, expected).allSatisfy { abs($0 - $1) <= tolerance }
    XCTAssertTrue(close, "\(actual) is not \(expected). \(message)", file: file, line: line)
}
