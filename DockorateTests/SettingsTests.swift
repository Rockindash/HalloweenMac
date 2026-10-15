import XCTest
@testable import Dockorate

/// The choices people make are kept, start out right, and carry over from older versions.
final class SettingsTests: SettingsTestCase {
    func testFirstLaunchDefaults() {
        XCTAssertTrue(Settings.showPumpkins)
        XCTAssertTrue(Settings.fallingLeaves)
        XCTAssertEqual(Settings.leafAmount, 0.5)
        XCTAssertFalse(Settings.leavesFillScreen)
        XCTAssertTrue(Settings.showVines)
        XCTAssertTrue(Settings.cozyExtras)
        XCTAssertTrue(Settings.squirrel)
        XCTAssertTrue(Settings.showMenuBarIcon)
        XCTAssertTrue(Settings.sound)
        XCTAssertEqual(Settings.fullness, .plenty)
        XCTAssertEqual(Settings.smashCount, 0)
        XCTAssertFalse(Settings.hasSeenWelcome)
        XCTAssertEqual(Settings.theme, .fall)
        for kind in DecorKind.allCases {
            XCTAssertTrue(Settings.isEnabled(kind), "\(kind) should start switched on")
        }
    }

    func testBackgroundIsOffByDefaultAndMatchesTheDock() {
        XCTAssertFalse(Settings.wallpaperEnabled)
        XCTAssertEqual(Settings.wallpaperMode, .matchDock)
        XCTAssertTrue(Settings.wallpaperOriginals.isEmpty)
    }

    func testChoicesAreKept() {
        Settings.showPumpkins = false
        Settings.fallingLeaves = false
        Settings.leavesFillScreen = true
        Settings.showVines = false
        Settings.cozyExtras = false
        Settings.squirrel = false
        Settings.showMenuBarIcon = false
        Settings.sound = false
        Settings.fullness = .overflowing
        Settings.smashCount = 42
        Settings.hasSeenWelcome = true
        Settings.wallpaperEnabled = true
        Settings.wallpaperMode = .dark

        XCTAssertFalse(Settings.showPumpkins)
        XCTAssertFalse(Settings.fallingLeaves)
        XCTAssertTrue(Settings.leavesFillScreen)
        XCTAssertFalse(Settings.showVines)
        XCTAssertFalse(Settings.cozyExtras)
        XCTAssertFalse(Settings.squirrel)
        XCTAssertFalse(Settings.showMenuBarIcon)
        XCTAssertFalse(Settings.sound)
        XCTAssertEqual(Settings.fullness, .overflowing)
        XCTAssertEqual(Settings.smashCount, 42)
        XCTAssertTrue(Settings.hasSeenWelcome)
        XCTAssertTrue(Settings.wallpaperEnabled)
        XCTAssertEqual(Settings.wallpaperMode, .dark)
    }

    func testLeafAmountStaysInRange() {
        Settings.leafAmount = 3
        XCTAssertEqual(Settings.leafAmount, 1)
        Settings.leafAmount = -1
        XCTAssertEqual(Settings.leafAmount, 0)
    }

    func testLeafRateIsOriginalInTheMiddle() {
        Settings.leafAmount = 0.5
        XCTAssertEqual(Settings.leafRate, 1, accuracy: 0.0001)
        Settings.leafAmount = 0
        XCTAssertEqual(Settings.leafRate, 0.25, accuracy: 0.0001)
        Settings.leafAmount = 1
        XCTAssertEqual(Settings.leafRate, 4, accuracy: 0.0001)
    }

    func testExtrasSwitchOnAndOffOneByOne() {
        Settings.setEnabled(.mug, false)
        Settings.setEnabled(.lantern, false)
        XCTAssertFalse(Settings.isEnabled(.mug))
        XCTAssertFalse(Settings.isEnabled(.lantern))
        XCTAssertTrue(Settings.isEnabled(.hayBale))
        Settings.setEnabled(.mug, true)
        XCTAssertTrue(Settings.isEnabled(.mug))
        XCTAssertFalse(Settings.isEnabled(.lantern))
    }

    func testFullnessPacksCloserAsItFills() {
        XCTAssertGreaterThan(Settings.Fullness.aFew.spacing, Settings.Fullness.plenty.spacing)
        XCTAssertGreaterThan(Settings.Fullness.plenty.spacing, Settings.Fullness.overflowing.spacing)
        XCTAssertEqual(Settings.Fullness.allCases.map(\.title), ["A Few", "Plenty", "Overflowing"])
    }

    func testUnknownStoredValuesFallBackSafely() {
        defaults.set(99, forKey: "fullness")
        defaults.set("winter-that-does-not-exist", forKey: "theme")
        defaults.set("sideways", forKey: "wallpaperMode")
        XCTAssertEqual(Settings.fullness, .plenty)
        XCTAssertEqual(Settings.theme, .fall)
        XCTAssertEqual(Settings.wallpaperMode, .matchDock)
    }

    /// Fall Dock's menu picked a number of pumpkins; Dockorate picks how full the Dock is.
    func testOldPumpkinCountCarriesOverAsFullness() {
        for (count, expected) in [(5, Settings.Fullness.aFew), (9, .plenty), (13, .overflowing)] {
            useFreshDefaults()
            defaults.set(count, forKey: "pumpkinCount")
            Settings.registerDefaults()
            XCTAssertEqual(Settings.fullness, expected, "\(count) pumpkins")
            XCTAssertNil(defaults.object(forKey: "pumpkinCount"), "the old setting is removed once carried over")
        }
    }

    func testResetEverythingPutsOptionsBack() {
        Settings.showPumpkins = false
        Settings.showVines = false
        Settings.fullness = .aFew
        Settings.smashCount = 7
        Settings.setEnabled(.apples, false)
        Settings.wallpaperEnabled = true
        Settings.wallpaperMode = .light
        Settings.hasSeenWelcome = true

        Settings.resetAll()

        XCTAssertTrue(Settings.showPumpkins)
        XCTAssertTrue(Settings.showVines)
        XCTAssertEqual(Settings.fullness, .plenty)
        XCTAssertEqual(Settings.smashCount, 0)
        XCTAssertTrue(Settings.isEnabled(.apples))
        XCTAssertFalse(Settings.wallpaperEnabled)
        XCTAssertEqual(Settings.wallpaperMode, .matchDock)
        XCTAssertTrue(Settings.hasSeenWelcome, "the welcome isn't shown again after a reset")
    }

    /// Reset Everything switches Background off, which needs the saved pictures to put them back.
    func testResetEverythingKeepsTheSavedDesktopPictures() {
        let saved = Settings.SavedWallpaper(url: URL(fileURLWithPath: "/Library/Desktop Pictures/Sonoma.heic"), options: [:])
        Settings.wallpaperOriginals = ["display-1": saved]
        Settings.resetAll()
        XCTAssertEqual(Settings.wallpaperOriginals["display-1"]?.url, saved.url)
    }

    func testSavedDesktopPictureKeepsHowItWasFitted() {
        let url = URL(fileURLWithPath: "/Users/someone/Pictures/Beach Day.jpg")
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSNumber(value: NSImageScaling.scaleAxesIndependently.rawValue),
            .allowClipping: NSNumber(value: false),
            .fillColor: NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1),
        ]
        Settings.wallpaperOriginals = ["A": .init(url: url, options: options), "B": .init(url: url, options: [:])]

        let restored = Settings.wallpaperOriginals
        XCTAssertEqual(restored.count, 2)
        let a = try! XCTUnwrap(restored["A"])
        XCTAssertEqual(a.url, url)
        XCTAssertEqual((a.options[.imageScaling] as? NSNumber)?.uintValue, NSImageScaling.scaleAxesIndependently.rawValue)
        XCTAssertEqual((a.options[.allowClipping] as? NSNumber)?.boolValue, false)
        let color = try! XCTUnwrap(a.options[.fillColor] as? NSColor).usingColorSpace(.sRGB)!
        XCTAssertEqual(color.blueComponent, 0.6, accuracy: 0.01)
        XCTAssertTrue(try! XCTUnwrap(restored["B"]).options.isEmpty)
    }

    func testThemesHaveNamesAndSymbols() {
        for theme in Settings.Theme.allCases {
            XCTAssertFalse(theme.title.isEmpty)
            XCTAssertNotNil(NSImage(systemSymbolName: theme.symbol, accessibilityDescription: nil), "\(theme.symbol) isn't an SF Symbol")
        }
    }
}
