import SpriteKit
import XCTest
@testable import Dockorate

/// The art drawn in code, the colors it uses, and the small bits of math the harvest relies on.
final class ArtTests: XCTestCase {
    private var savedAppearance = Palette.Appearance.dark

    override func setUp() {
        super.setUp()
        savedAppearance = Palette.appearance
    }

    override func tearDown() {
        Palette.appearance = savedAppearance
        ArtCache.clear()
        super.tearDown()
    }

    @MainActor func testHexColors() {
        XCTAssertColor(CGColor.hex(0xEB6C15).rgb255, [0xEB, 0x6C, 0x15])
        XCTAssertEqual(CGColor.hex(0x000000, alpha: 0.5).alpha, 0.5, accuracy: 0.001)
    }

    @MainActor func testMixingColors() {
        let black = CGColor.hex(0x000000), white = CGColor.hex(0xFFFFFF)
        XCTAssertColor(black.mixed(with: white, 0).rgb255, [0, 0, 0])
        XCTAssertColor(black.mixed(with: white, 1).rgb255, [255, 255, 255])
        XCTAssertColor(black.mixed(with: white, 0.5).rgb255, [128, 128, 128], tolerance: 1)
    }

    @MainActor func testPaletteFollowsLightAndDark() {
        Palette.appearance = .dark
        XCTAssertColor(Palette.orange.rgb255, rgb255(0xEB6C15))
        XCTAssertColor(Palette.plum.rgb255, rgb255(0x5D1C2B))
        Palette.appearance = .light
        XCTAssertColor(Palette.orange.rgb255, rgb255(0xF58A3A))
        XCTAssertColor(Palette.plum.rgb255, rgb255(0x8A4452))
    }

    @MainActor func testSeededRandomRepeats() {
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42), c = SeededRandom(seed: 43)
        let first = (0..<5).map { _ in a.next() }
        XCTAssertEqual(first, (0..<5).map { _ in b.next() }, "the same pumpkin looks the same every time")
        XCTAssertNotEqual(first, (0..<5).map { _ in c.next() })
        for _ in 0..<100 {
            XCTAssertTrue((0.2...0.3).contains(a.float(0.2...0.3)))
        }
    }

    @MainActor func testEveryPumpkinDrawsInBothLooks() {
        for appearance in [Palette.Appearance.light, .dark] {
            Palette.appearance = appearance
            ArtCache.clear()
            for kind in PumpkinKind.allCases {
                let size = PumpkinArt.size(of: kind, height: 60)
                XCTAssertGreaterThan(size.width, 0, "\(kind)")
                XCTAssertGreaterThan(size.height, 0, "\(kind)")
                let texture = PumpkinArt.texture(kind: kind, height: 60, variant: 0, scale: 1)
                XCTAssertGreaterThan(texture.size().width, 0, "\(kind) drew nothing")
            }
        }
    }

    @MainActor func testEveryExtraDraws() {
        for kind in DecorKind.allCases {
            let size = CozyArt.size(of: kind, unit: 60)
            XCTAssertGreaterThan(size.width, 0, "\(kind)")
            XCTAssertGreaterThan(CozyArt.texture(kind, unit: 60, variant: 0, scale: 1).size().width, 0, "\(kind)")
            XCTAssertGreaterThan(ExtraArt.image(for: kind).size.width, 0, "\(kind) tile")
            XCTAssertFalse(kind.title.isEmpty)
        }
        XCTAssertGreaterThan(ExtraArt.squirrel().size.width, 0)
        XCTAssertGreaterThan(ExtraArt.pumpkin().size.width, 0)
        XCTAssertGreaterThan(ExtraArt.menuBarPumpkin().size.width, 0)
    }

    @MainActor func testThemePreviewsDraw() {
        for theme in Settings.Theme.allCases {
            XCTAssertGreaterThan(ThemePreview.image(for: theme).size.width, 0)
        }
    }

    // MARK: The Dock's magnification

    @MainActor func testNoMagnificationLeavesEverythingAlone() {
        let magnifier = DockMagnifier(enabled: false, tile: 48, large: 128)
        XCTAssertEqual(magnifier.maxScale, 1)
        XCTAssertEqual(magnifier.scale(at: 0, strength: 1), 1)
        XCTAssertEqual(magnifier.lift(at: 0, strength: 1), 0)
        XCTAssertEqual(magnifier.shift(at: 30, strength: 1), 0)
    }

    @MainActor func testMagnificationPeaksUnderThePointer() {
        let magnifier = DockMagnifier(enabled: true, tile: 48, large: 96)
        XCTAssertEqual(magnifier.maxScale, 2)
        XCTAssertEqual(magnifier.scale(at: 0, strength: 1), 2, accuracy: 0.0001)
        XCTAssertEqual(magnifier.lift(at: 0, strength: 1), 48, accuracy: 0.0001)
        XCTAssertEqual(magnifier.scale(at: magnifier.reach, strength: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(magnifier.scale(at: 0, strength: 0), 1, accuracy: 0.0001, "faded out")
        // Shrinks smoothly with distance, the same on both sides.
        XCTAssertGreaterThan(magnifier.scale(at: 20, strength: 1), magnifier.scale(at: 60, strength: 1))
        XCTAssertEqual(magnifier.scale(at: -40, strength: 1), magnifier.scale(at: 40, strength: 1), accuracy: 0.0001)
    }

    @MainActor func testMagnificationPushesThingsAwayFromThePointer() {
        let magnifier = DockMagnifier(enabled: true, tile: 48, large: 96)
        XCTAssertGreaterThan(magnifier.shift(at: 50, strength: 1), 0)
        XCTAssertLessThan(magnifier.shift(at: -50, strength: 1), 0)
        XCTAssertEqual(magnifier.shift(at: 50, strength: 1), -magnifier.shift(at: -50, strength: 1), accuracy: 0.0001)
        XCTAssertEqual(magnifier.shift(at: 500, strength: 1), magnifier.shift(at: 900, strength: 1), accuracy: 0.0001,
                       "past the magnified icons everything moves the same amount")
    }

    @MainActor func testMagnifierNeverShrinksIcons() {
        XCTAssertEqual(DockMagnifier(enabled: true, tile: 64, large: 32).maxScale, 1)
    }

    // MARK: The app window

    @MainActor func testEveryHomeCardHasItsOwnPicture() {
        for theme in Settings.Theme.allCases {
            for appearance in [Palette.Appearance.light, .dark] {
                let art = HomePage.cardArt(for: theme, appearance)
                XCTAssertEqual(art.count, 4, "one for each card on Home")
                XCTAssertEqual(Set(art).count, 4, "\(theme) uses a picture twice on Home: \(art)")
            }
        }
    }

    @MainActor func testGreetingChangesThroughTheDay() {
        func at(_ hour: Int) -> String {
            HomePage.greeting(at: Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: Date())!)
        }
        XCTAssertEqual(at(4), "Good Evening")
        XCTAssertEqual(at(5), "Good Morning")
        XCTAssertEqual(at(11), "Good Morning")
        XCTAssertEqual(at(12), "Good Afternoon")
        XCTAssertEqual(at(16), "Good Afternoon")
        XCTAssertEqual(at(17), "Good Evening")
        XCTAssertEqual(at(23), "Good Evening")
    }

    @MainActor func testEveryPageHasATitleAndSymbol() {
        XCTAssertEqual(Page.allCases.map(\.title), ["Home", "Themes", "Customize", "Background", "Settings"])
        for page in Page.allCases {
            XCTAssertNotNil(NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil), "\(page.symbol)")
        }
    }

    @MainActor func testHarvestStatesReadWell() {
        let states: [HarvestState] = [.showing, .dockHidden, .paused, .hidden, .unlicensed]
        XCTAssertEqual(Set(states.map(\.title)).count, states.count)
    }
}
