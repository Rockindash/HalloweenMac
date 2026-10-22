import SpriteKit
import XCTest
@testable import Dockorate

/// The harvest on the Dock: how many pumpkins fit, where they and the extras go, and what the
/// switches in Customize and Settings change.
// SpriteKit runs on the main thread, so each test does too.
final class HarvestLayoutTests: SettingsTestCase {
    @MainActor private func harvest(width: CGFloat) -> PumpkinScene {
        let scene = PumpkinScene(size: CGSize(width: width + 40, height: 220))
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: width, height: 60),
                        pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        return scene
    }

    @MainActor private func pumpkins(in scene: PumpkinScene) -> [PumpkinNode] {
        scene.pumpkinLayer.children.compactMap { $0 as? PumpkinNode }
    }

    @MainActor private func decorations(in scene: PumpkinScene) -> [DecorNode] {
        scene.pumpkinLayer.children.compactMap { $0 as? DecorNode }
    }

    @MainActor func testPumpkinsLineUpAlongTheDock() {
        let scene = harvest(width: 1000)
        XCTAssertGreaterThan(scene.pumpkinCount, 2)
        XCTAssertEqual(scene.slotX.count, scene.pumpkinCount)
        XCTAssertEqual(pumpkins(in: scene).count, scene.pumpkinCount)
        XCTAssertEqual(scene.slotX, scene.slotX.sorted(), "left to right")
        for x in scene.slotX {
            XCTAssertTrue((20...1020).contains(x), "pumpkin at \(x) is off the Dock")
        }
    }

    @MainActor func testPumpkinsKeepTheirSizeOnAnyDock() {
        XCTAssertEqual(harvest(width: 500).pumpkinHeight, PumpkinScene.itemHeight)
        XCTAssertEqual(harvest(width: 2000).pumpkinHeight, PumpkinScene.itemHeight)
    }

    @MainActor func testLongerDockFitsMore() {
        XCTAssertGreaterThan(harvest(width: 1600).pumpkinCount, harvest(width: 600).pumpkinCount)
    }

    @MainActor func testHowFullChangesHowManyFit() {
        var counts: [Settings.Fullness: Int] = [:]
        for fullness in Settings.Fullness.allCases {
            Settings.fullness = fullness
            counts[fullness] = harvest(width: 1400).pumpkinCount
        }
        XCTAssertLessThan(counts[.aFew]!, counts[.plenty]!)
        XCTAssertLessThanOrEqual(counts[.plenty]!, counts[.overflowing]!)
    }

    @MainActor func testTinyDockGrowsNothingAndDoesNotCrash() {
        let scene = harvest(width: 30)
        XCTAssertEqual(scene.pumpkinCount, 0)
        XCTAssertTrue(pumpkins(in: scene).isEmpty)
        XCTAssertFalse(scene.hasVine)
    }

    @MainActor func testVineFollowsItsSwitch() {
        XCTAssertTrue(harvest(width: 1000).hasVine)
        Settings.showVines = false
        XCTAssertFalse(harvest(width: 1000).hasVine)
    }

    @MainActor func testExtrasSitBetweenPumpkins() {
        let scene = harvest(width: 1400)
        XCTAssertEqual(scene.gapKinds.count, scene.pumpkinCount - 1)
        XCTAssertEqual(scene.gapX.count, scene.gapKinds.count)
        for (i, x) in scene.gapX.enumerated() {
            XCTAssertGreaterThan(x, scene.slotX[i])
            XCTAssertLessThan(x, scene.slotX[i + 1])
        }
        XCTAssertFalse(decorations(in: scene).isEmpty)
    }

    @MainActor func testCozyExtrasOffLeavesJustPumpkins() {
        Settings.cozyExtras = false
        let scene = harvest(width: 1400)
        XCTAssertGreaterThan(scene.pumpkinCount, 0)
        XCTAssertTrue(scene.gapKinds.isEmpty)
        XCTAssertTrue(decorations(in: scene).isEmpty)
        XCTAssertTrue(scene.slotPerch.allSatisfy { $0 == 0 }, "no hay bales")
    }

    @MainActor func testSwitchedOffExtrasNeverGrow() {
        Settings.setEnabled(.acorns, false)
        Settings.setEnabled(.leafPile, false)
        for _ in 0..<5 {
            let kinds = harvest(width: 2400).gapKinds
            XCTAssertFalse(kinds.contains(.acorns))
            XCTAssertFalse(kinds.contains(.leafPile))
        }
    }

    @MainActor func testEveryGapExtraOffStillLeavesHayBales() {
        for kind in Set(Settings.Theme.fall.gapCycle) { Settings.setEnabled(kind, false) }
        let scene = harvest(width: 1400)
        XCTAssertTrue(scene.gapKinds.isEmpty)
        XCTAssertGreaterThan(scene.pumpkinCount, 2)
        XCTAssertGreaterThan(scene.slotPerch[2], 0, "the third pumpkin sits on a hay bale")
    }

    @MainActor func testHayBalesUnderEveryFifthPumpkin() {
        let scene = harvest(width: 2400)
        for (slot, perch) in scene.slotPerch.enumerated() {
            XCTAssertEqual(perch > 0, slot % 5 == 2, "slot \(slot)")
        }
        Settings.setEnabled(.hayBale, false)
        XCTAssertTrue(harvest(width: 2400).slotPerch.allSatisfy { $0 == 0 })
    }

    @MainActor func testLatteAndLanternAreRare() {
        for _ in 0..<10 {
            let kinds = harvest(width: 3000).gapKinds
            for special in [DecorKind.mug, .lantern] {
                let spots = kinds.indices.filter { kinds[$0] == special }
                for (a, b) in zip(spots, spots.dropFirst()) {
                    XCTAssertGreaterThan(b - a, 8, "\(special) twice within eight gaps: \(kinds)")
                }
            }
        }
    }

    @MainActor func testDockGettingLongerKeepsThePumpkinsAndAddsMore() {
        let scene = harvest(width: 800)
        let before = scene.pumpkinCount
        let firstX = scene.slotX.first
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: 1300, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: false)
        XCTAssertGreaterThanOrEqual(scene.pumpkinCount, before)
        XCTAssertNotNil(firstX)
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: 500, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: false)
        XCTAssertLessThanOrEqual(scene.pumpkinCount, before)
        XCTAssertEqual(scene.slotX.count, scene.pumpkinCount)
    }

    @MainActor func testSmashingCountsOnceAndTheSlotGrowsBack() {
        Settings.sound = false
        let scene = harvest(width: 1000)
        var smashes = 0
        scene.onSmash = { smashes += 1 }
        let pumpkin = try! XCTUnwrap(pumpkins(in: scene).first)

        scene.smash(pumpkin)
        XCTAssertEqual(smashes, 1)
        XCTAssertFalse(pumpkin.isInteractive, "a smashed pumpkin can't be clicked again")
        scene.smash(pumpkin)
        XCTAssertEqual(smashes, 1, "smashing the same pumpkin twice counts once")
        XCTAssertNotNil(scene.action(forKey: "respawn-\(pumpkin.slot)"), "a new pumpkin is on its way")
    }

    @MainActor func testRepaintKeepsTheSameHarvest() {
        let scene = harvest(width: 1000)
        let count = scene.pumpkinCount
        let slots = scene.slotX
        scene.repaint()
        XCTAssertEqual(scene.pumpkinCount, count)
        XCTAssertEqual(scene.slotX, slots)
        XCTAssertEqual(pumpkins(in: scene).count, count)
    }

    @MainActor func testWindowHarvestGrows() {
        let live = LiveHarvest()
        live.layout(size: CGSize(width: 700, height: 300), regrow: true)
        XCTAssertGreaterThan(live.scene.pumpkinCount, 0)
    }

    @MainActor func testHarvestTucksAwayAndComesBack() {
        let scene = harvest(width: 1000)
        scene.setTuck(.offScreen, animated: false)
        XCTAssertTrue(scene.isTuckedAway)
        scene.setTuck(.none, animated: false)
        XCTAssertFalse(scene.isTuckedAway)
        XCTAssertFalse(scene.isStuckAway)
    }
}
