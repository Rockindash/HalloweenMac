import SpriteKit
import XCTest
@testable import Dockorate

/// Spirits of quit apps: remembering where icons were and which spirits left, and what shows on the Dock.
final class SpiritsTests: SettingsTestCase {
    private let notes = URL(fileURLWithPath: "/System/Applications/Notes.app")
    private let mail = URL(fileURLWithPath: "/System/Applications/Mail.app")

    // MARK: Remembering

    func testTheSameAppAlwaysGetsTheSameKey() {
        XCTAssertEqual(SpiritLedger.key(for: notes), SpiritLedger.key(for: URL(fileURLWithPath: "/System/Applications/Notes.app/")))
        XCTAssertEqual(SpiritLedger.key(for: notes), SpiritLedger.key(for: URL(string: "file:///System/Applications/Notes.app/")!),
                       "the Dock hands over a file URL with a trailing slash")
        XCTAssertNotEqual(SpiritLedger.key(for: notes), SpiritLedger.key(for: mail))
    }

    func testAQuitAppsSpiritLeavesFromWhereItsIconWas() {
        var ledger = SpiritLedger()
        let key = SpiritLedger.key(for: notes)
        ledger.noteIcons([key: CGRect(x: 400, y: 0, width: 60, height: 60)])
        // Once it quits, its icon leaves the Dock, but its spot is remembered.
        ledger.noteIcons([SpiritLedger.key(for: mail): CGRect(x: 500, y: 0, width: 60, height: 60)])
        XCTAssertEqual(ledger.quit(key, now: 0), 430)
    }

    func testAnAppWithoutAKnownIconStillHasASpirit() {
        var ledger = SpiritLedger()
        XCTAssertNil(ledger.quit(SpiritLedger.key(for: notes), now: 0), "no spot known (no Accessibility), so the scene picks one")
    }

    func testReopeningSoonBringsTheSpiritBack() {
        var ledger = SpiritLedger()
        let key = SpiritLedger.key(for: notes)
        _ = ledger.quit(key, now: 100)
        XCTAssertTrue(ledger.launched(key, now: 160))
        XCTAssertFalse(ledger.launched(key, now: 170), "it only comes back once")
    }

    func testASpiritGoneTooLongStaysGone() {
        var ledger = SpiritLedger()
        let key = SpiritLedger.key(for: notes)
        _ = ledger.quit(key, now: 0)
        XCTAssertFalse(ledger.launched(key, now: SpiritLedger.remembers + 1))
    }

    func testOpeningAnAppThatNeverQuitBringsNothing() {
        var ledger = SpiritLedger()
        _ = ledger.quit(SpiritLedger.key(for: mail), now: 0)
        XCTAssertFalse(ledger.launched(SpiritLedger.key(for: notes), now: 1))
    }

    func testWithoutAccessibilityIconSpotsAreWorkedOutFromTheDock() {
        let dock = CGRect(x: 100, y: 0, width: 800, height: 70)
        let xs = SpiritLedger.estimatedIconX(kept: ["com.apple.Safari", "com.apple.mail"],
                                             open: ["com.apple.finder", "com.apple.mail", "com.apple.calculator", "com.amol.dockorate"],
                                             dockFrame: dock, tileSize: 50)
        let pitch: CGFloat = 50 + 5
        XCTAssertEqual(xs["com.apple.finder"]!, dock.minX + 10 + pitch / 2, accuracy: 0.01, "Finder comes first")
        XCTAssertEqual(xs["com.apple.Safari"]!, xs["com.apple.finder"]! + pitch, accuracy: 0.01, "then the kept apps, in order")
        XCTAssertEqual(xs["com.apple.mail"]!, xs["com.apple.Safari"]! + pitch, accuracy: 0.01, "a kept app that's open stays in its place")
        XCTAssertEqual(xs["com.apple.calculator"]!, xs["com.apple.mail"]! + pitch + 14, accuracy: 0.01, "open apps come after the divider")
        XCTAssertEqual(xs["com.amol.dockorate"]!, xs["com.apple.calculator"]! + pitch, accuracy: 0.01, "in the order they opened")
        XCTAssertNotEqual(xs["com.apple.calculator"], xs["com.amol.dockorate"], "a quit app's spirit doesn't come from Dockorate's icon")
    }

    func testAWorkedOutSpotIsRememberedAfterTheAppQuits() {
        var ledger = SpiritLedger()
        let key = SpiritLedger.key(for: notes)
        ledger.noteIconX([key: 321])
        XCTAssertEqual(ledger.quit(key, now: 0), 321)
    }

    // MARK: The switch

    func testSpiritsAreOnToStartWithAndResetPutsThemBack() {
        XCTAssertTrue(Settings.spirits)
        Settings.spirits = false
        XCTAssertFalse(Settings.spirits)
        Settings.resetAll()
        XCTAssertTrue(Settings.spirits)
    }

    // MARK: On the Dock

    private var icon: NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), xRadius: 12, yRadius: 12).fill()
            return true
        }
    }

    @MainActor private func dock(_ theme: Settings.Theme) -> PumpkinScene {
        Settings.themeChoice = .keep(theme)
        let scene = PumpkinScene(size: CGSize(width: 1440, height: 68 + 240))
        scene.configure(dockRect: CGRect(x: 120, y: 8, width: 1200, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        return scene
    }

    @MainActor func testASpiritRisesFromItsIcon() {
        let scene = dock(.halloween)
        scene.releaseSpirit(icon: icon, key: "notes", atSceneX: 430)
        XCTAssertEqual(scene.spirits.count, 1)
        let spirit = try! XCTUnwrap(scene.spirits.first)
        XCTAssertEqual(spirit.position.x, 430, accuracy: 0.5, "right where the icon was")
        XCTAssertTrue((scene.dockRect.minY...scene.dockRect.maxY).contains(spirit.position.y), "out of the Dock itself")
        XCTAssertFalse(spirit is DockSprite, "it can't be clicked")
    }

    @MainActor func testWithoutAKnownSpotItRisesFromAmongTheOpenApps() {
        let scene = dock(.halloween)
        scene.releaseSpirit(icon: icon, key: "notes", atSceneX: nil)
        let spirit = try! XCTUnwrap(scene.spirits.first)
        XCTAssertGreaterThan(spirit.position.x, scene.dockRect.midX, "toward the right end, where open apps sit")
        XCTAssertLessThan(spirit.position.x, scene.dockRect.maxX)
    }

    @MainActor func testASpiritComesBackDownIntoItsIcon() {
        let scene = dock(.halloween)
        scene.returnSpirit(icon: icon, key: "notes", toSceneX: 430)
        let spirit = try! XCTUnwrap(scene.spirits.first)
        XCTAssertGreaterThan(spirit.position.y, scene.dockRect.maxY, "it starts up above the Dock")
        XCTAssertLessThanOrEqual(spirit.position.y, scene.size.height)
    }

    @MainActor func testOnlyHalloweenHasSpirits() {
        let scene = dock(.fall)
        scene.releaseSpirit(icon: icon, key: "notes", atSceneX: 430)
        scene.returnSpirit(icon: icon, key: "notes", toSceneX: 430)
        XCTAssertTrue(scene.spirits.isEmpty)
    }

    @MainActor func testSpiritArtDraws() {
        defer { ArtCache.clear() }
        let size = HauntingArt.spiritSize(unit: 90)
        XCTAssertGreaterThan(size.height, size.width, "the tail trails below the icon")
        XCTAssertGreaterThan(HauntingArt.spiritTexture(icon: icon, key: "notes", unit: 90, scale: 1).size().width, 0)
        XCTAssertGreaterThan(HauntingArt.spiritTexture(icon: NSImage(), key: "empty", unit: 90, scale: 1).size().width, 0,
                             "an app without an icon still gets a spirit")
    }
}
