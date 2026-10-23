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
        for theme in Settings.Theme.allCases {
            XCTAssertEqual(Settings.smashCount(for: theme), 0)
        }
        XCTAssertFalse(Settings.hasSeenWelcome)
        XCTAssertEqual(Settings.theme, .fall)
        for kind in DecorKind.allCases {
            XCTAssertTrue(Settings.isEnabled(kind), "\(kind) should start switched on")
        }
    }

    func testEachThemeCountsItsOwnSmashes() {
        Settings.setSmashCount(12, for: .fall)
        Settings.setSmashCount(3, for: .halloween)
        XCTAssertEqual(Settings.smashCount(for: .fall), 12)
        XCTAssertEqual(Settings.smashCount(for: .halloween), 3, "Halloween's smashes don't add to Fall's")
        XCTAssertEqual(Set(Settings.Theme.allCases.map(Settings.smashCountKey)).count, Settings.Theme.allCases.count,
                       "every theme is saved under its own name")
    }

    func testDockorate10sSmashCountStaysWithFall() {
        // 1.0 had only Fall, and saved its count as "smashCount".
        defaults.set(42, forKey: "smashCount")
        XCTAssertEqual(Settings.smashCount(for: .fall), 42)
        XCTAssertEqual(Settings.smashCount(for: .halloween), 0)
    }

    func testSmashCountWords() {
        XCTAssertEqual(Settings.Theme.fall.smashedTitle(0), "0 Pumpkins Smashed")
        XCTAssertEqual(Settings.Theme.fall.smashedTitle(1), "1 Pumpkin Smashed")
        XCTAssertEqual(Settings.Theme.halloween.smashedTitle(0), "0 Lanterns Smashed")
        XCTAssertEqual(Settings.Theme.halloween.smashedTitle(1), "1 Lantern Smashed")
        XCTAssertEqual(Settings.Theme.halloween.smashedTitle(3), "3 Lanterns Smashed")
        XCTAssertEqual(Settings.Theme.fall.smashed(2), "2 pumpkins")
        XCTAssertEqual(Settings.Theme.halloween.smashed(1), "1 jack-o'-lantern")
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
        Settings.setSmashCount(42, for: .fall)
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
        XCTAssertEqual(Settings.smashCount(for: .fall), 42)
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
        Settings.setSmashCount(7, for: .fall)
        Settings.setSmashCount(5, for: .halloween)
        Settings.setEnabled(.apples, false)
        Settings.wallpaperEnabled = true
        Settings.wallpaperMode = .light
        Settings.hasSeenWelcome = true

        Settings.resetAll()

        XCTAssertTrue(Settings.showPumpkins)
        XCTAssertTrue(Settings.showVines)
        XCTAssertEqual(Settings.fullness, .plenty)
        XCTAssertEqual(Settings.smashCount(for: .fall), 0)
        XCTAssertEqual(Settings.smashCount(for: .halloween), 0, "every theme's count is cleared")
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

    func testDiwaliKeepsItsOwnSmashCount() {
        Settings.setSmashCount(5, for: .fall)
        Settings.setSmashCount(2, for: .diwali)
        XCTAssertEqual(Settings.smashCount(for: .diwali), 2)
        XCTAssertEqual(Settings.smashCount(for: .fall), 5, "lighting diyas doesn't add to Fall's count")
        XCTAssertEqual(Settings.smashCount(for: .halloween), 0)
        Settings.resetAll()
        XCTAssertEqual(Settings.smashCount(for: .diwali), 0, "Reset Everything clears Diwali's count too")
    }

    func testDiwalisCountSaysTheDiyasWereLit() {
        XCTAssertEqual(Settings.Theme.diwali.smashedTitle(0), "0 Diyas Lit")
        XCTAssertEqual(Settings.Theme.diwali.smashedTitle(1), "1 Diya Lit")
        XCTAssertEqual(Settings.Theme.diwali.smashedTitle(40), "40 Diyas Lit")
        XCTAssertEqual(Settings.Theme.diwali.smashed(1), "1 diya")
        XCTAssertEqual(Settings.Theme.diwali.smashed(3), "3 diyas")

        // The menu bar switch names the icon that's there.
        XCTAssertEqual(Settings.Theme.fall.thing, "pumpkin")
        XCTAssertEqual(Settings.Theme.halloween.thing, "jack-o'-lantern")
        XCTAssertEqual(Settings.Theme.diwali.thing, "diya")
    }
}
