import SpriteKit
import XCTest
@testable import Dockorate

/// Haunting while you're away: when the ghosts gather, when they scatter, and what shows on the Dock.
final class HauntingTests: SettingsTestCase {
    // MARK: When

    /// Feeds the clock idle times one second apart, the way the overlay checks.
    private func run(_ clock: inout HauntingClock, idle: [TimeInterval], allowed: Bool = true, from start: TimeInterval = 0) -> [HauntingClock.Change?] {
        idle.enumerated().map { clock.update(idle: $1, now: start + TimeInterval($0), allowed: allowed) }
    }

    func testTheDockIsHauntedAfterTwoMinutesAway() {
        var clock = HauntingClock()
        XCTAssertEqual(run(&clock, idle: [5, 60, 119]), [nil, nil, nil], "not before two minutes")
        XCTAssertFalse(clock.isHaunting)
        XCTAssertEqual(clock.update(idle: 120, now: 3, allowed: true), .gather)
        XCTAssertTrue(clock.isHaunting)
        XCTAssertEqual(run(&clock, idle: [121, 122, 300], from: 4), [nil, nil, nil], "it stays haunted while nobody's there")
    }

    func testAnyInputScattersTheGhosts() {
        var clock = HauntingClock()
        XCTAssertEqual(run(&clock, idle: [130, 131]), [.gather, nil])
        XCTAssertEqual(clock.update(idle: 0.4, now: 2, allowed: true), .scatter, "someone touched the Mac")
        XCTAssertFalse(clock.isHaunting)
        XCTAssertEqual(run(&clock, idle: [1.4, 2.4, 60], from: 3), [nil, nil, nil], "and it waits another two minutes")
    }

    func testNeverHauntedWhenItCantBe() {
        var clock = HauntingClock()
        XCTAssertEqual(run(&clock, idle: [200, 300, 400], allowed: false), [nil, nil, nil])
        XCTAssertFalse(clock.isHaunting)
    }

    func testGhostsLeaveWhenHauntingStopsBeingAllowed() {
        var clock = HauntingClock()
        XCTAssertEqual(clock.update(idle: 200, now: 0, allowed: true), .gather)
        // Switched off, the theme changed, or the Dock went away.
        XCTAssertEqual(clock.update(idle: 201, now: 1, allowed: false), .scatter)
        XCTAssertFalse(clock.isHaunting)
    }

    func testTryItHauntsAfterAMomentHandsOff() {
        var clock = HauntingClock()
        clock.tryIt(now: 0)
        XCTAssertTrue(clock.isWaitingToTry)
        XCTAssertEqual(run(&clock, idle: [0.2, 1.2, 2.2]), [nil, nil, nil], "the click on Try It itself doesn't count")
        XCTAssertEqual(clock.update(idle: HauntingClock.tryItAfter, now: 3, allowed: true), .gather)
        XCTAssertFalse(clock.isWaitingToTry, "Try It is used up")
        XCTAssertEqual(clock.update(idle: 0.1, now: 4, allowed: true), .scatter)
        // Back to the usual two minutes.
        XCTAssertNil(clock.update(idle: 10, now: 14, allowed: true))
    }

    func testTryItGivesUpIfHandsNeverComeOff() {
        var clock = HauntingClock()
        clock.tryIt(now: 0)
        // Someone keeps working for over a minute.
        for second in 1...61 { XCTAssertNil(clock.update(idle: 0.5, now: TimeInterval(second), allowed: true)) }
        XCTAssertFalse(clock.isWaitingToTry)
        XCTAssertNil(clock.update(idle: 5, now: 66, allowed: true), "no longer haunts after just a moment")
    }

    func testTryItDoesNothingOutsideHalloween() {
        var clock = HauntingClock()
        clock.tryIt(now: 0)
        XCTAssertNil(clock.update(idle: 5, now: 1, allowed: false))
        XCTAssertFalse(clock.isWaitingToTry)
    }

    func testIdleTimeCanBeRead() {
        XCTAssertGreaterThanOrEqual(HauntingClock.secondsSinceInput(), 0)
    }

    // MARK: The switch

    func testHauntingIsOnToStartWithAndResetPutsItBack() {
        XCTAssertTrue(Settings.haunting)
        Settings.haunting = false
        XCTAssertFalse(Settings.haunting)
        Settings.resetAll()
        XCTAssertTrue(Settings.haunting)
    }

    // MARK: On the Dock

    @MainActor private func halloweenDock(width: CGFloat = 1200) -> PumpkinScene {
        Settings.themeChoice = .keep(.halloween)
        // As tall as the overlay: the Dock, and 240 points of room above it.
        let scene = PumpkinScene(size: CGSize(width: width + 240, height: 68 + 240))
        scene.configure(dockRect: CGRect(x: 120, y: 8, width: width, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        return scene
    }

    @MainActor private func lanterns(in scene: PumpkinScene) -> [PumpkinNode] {
        scene.pumpkinLayer.children.compactMap { $0 as? PumpkinNode }.filter(\.isLantern)
    }

    @MainActor func testGhostsGatherAndEyesOpenOverTheDock() {
        let scene = halloweenDock()
        XCTAssertFalse(scene.isHaunted)
        scene.haunt(animated: false)
        XCTAssertTrue(scene.isHaunted)
        let counts = scene.hauntCounts
        XCTAssertEqual(scene.hauntGhosts.count, counts.ghosts)
        XCTAssertEqual(scene.hauntEyes.count, counts.eyes)
        XCTAssertGreaterThanOrEqual(counts.ghosts, 2)
        XCTAssertGreaterThanOrEqual(counts.eyes, 3)

        let dock = scene.dockRect
        for ghost in scene.hauntGhosts {
            XCTAssertGreaterThan(ghost.position.y, dock.maxY, "ghosts float above the Dock")
            XCTAssertLessThan(ghost.frame.maxY, scene.size.height, "and stay inside the overlay")
            XCTAssertTrue((dock.minX...dock.maxX).contains(ghost.position.x), "gathered over the Dock")
        }
        for eyes in scene.hauntEyes {
            XCTAssertTrue((dock.minX...dock.maxX).contains(eyes.position.x), "eyes along the Dock")
            XCTAssertGreaterThan(eyes.position.y, dock.maxY)
            XCTAssertLessThan(eyes.frame.maxY, scene.size.height)
        }
        XCTAssertFalse(lanterns(in: scene).isEmpty)
        XCTAssertTrue(lanterns(in: scene).allSatisfy(scene.isCandleHaunted), "the candles burn green")
    }

    @MainActor func testHauntingNeverCatchesClicks() {
        let scene = halloweenDock()
        scene.haunt(animated: false)
        for node in scene.hauntGhosts + scene.hauntEyes {
            let target = scene.target(at: node.position)
            XCTAssertFalse(target.map { $0.children.contains(node) || $0 === node } ?? false, "\(node) isn't clickable")
            XCTAssertFalse(node is DockSprite, "the haunting isn't one of the things on the Dock that react")
        }
    }

    @MainActor func testScatteringClearsTheHauntingAtOnce() {
        let scene = halloweenDock()
        scene.haunt(animated: false)
        scene.unhaunt()
        XCTAssertFalse(scene.isHaunted, "nothing counts as haunting while it leaves")
        XCTAssertTrue(scene.hauntGhosts.isEmpty)
        XCTAssertTrue(scene.hauntEyes.isEmpty)
        // And it can be haunted again next time.
        scene.haunt(animated: false)
        XCTAssertTrue(scene.isHaunted)
    }

    @MainActor func testCandlesWarmUpAgainAfterwards() {
        let scene = halloweenDock()
        scene.haunt(animated: false)
        scene.unhaunt(animated: false)
        XCTAssertFalse(lanterns(in: scene).isEmpty)
        XCTAssertTrue(lanterns(in: scene).allSatisfy { !scene.isCandleHaunted($0) }, "orange candles again")
        XCTAssertTrue(scene.effectsLayer.children.filter { $0.name?.hasPrefix("haunt") == true }.isEmpty, "every ghost gone")
    }

    @MainActor func testHauntingTwiceDoesNotDoubleUp() {
        let scene = halloweenDock()
        scene.haunt(animated: false)
        let ghosts = scene.hauntGhosts.count
        scene.haunt(animated: false)
        XCTAssertEqual(scene.hauntGhosts.count, ghosts)
    }

    @MainActor func testOnlyHalloweenIsHaunted() {
        Settings.themeChoice = .keep(.fall)
        let scene = PumpkinScene(size: CGSize(width: 1440, height: 300))
        scene.configure(dockRect: CGRect(x: 120, y: 8, width: 1200, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        scene.haunt(animated: false)
        XCTAssertFalse(scene.isHaunted, "no ghosts in fall")
    }

    @MainActor func testATinyDockIsLeftAlone() {
        let scene = halloweenDock(width: 120)
        scene.haunt(animated: false)
        XCTAssertFalse(scene.isHaunted)
    }

    @MainActor func testHauntingArtDraws() {
        let saved = Palette.appearance
        defer { Palette.appearance = saved; ArtCache.clear() }
        for appearance in [Palette.Appearance.light, .dark] {
            Palette.appearance = appearance
            ArtCache.clear()
            let size = HauntingArt.eyesSize(unit: 60)
            XCTAssertGreaterThan(size.width, size.height, "a pair side by side")
            for kind in 0..<HauntingArt.eyeKinds {
                XCTAssertGreaterThan(HauntingArt.eyesTexture(kind: kind, size: size, scale: 1).size().width, 0, "eyes \(kind)")
            }
            XCTAssertGreaterThan(HauntingArt.wispTexture(unit: 60, scale: 1).size().width, 0)
        }
    }
}
