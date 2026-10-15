import SpriteKit
import XCTest
@testable import Dockorate

/// The second theme: picking Fall or Halloween (or the calendar), what each grows on the Dock, and
/// the crossfade between them. Fall, the original, must stay exactly as it was.
final class ThemeTests: SettingsTestCase {
    private func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @MainActor private func harvest(width: CGFloat = 1600) -> PumpkinScene {
        let scene = PumpkinScene(size: CGSize(width: width + 40, height: 220))
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: width, height: 60),
                        pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        return scene
    }

    @MainActor private func pumpkins(in scene: PumpkinScene) -> [PumpkinNode] {
        scene.pumpkinLayer.children.compactMap { $0 as? PumpkinNode }
    }

    // MARK: Picking a theme

    func testFallIsTheThemeUntilAnotherIsPicked() {
        XCTAssertEqual(Settings.themeChoice, .keep(.fall))
        XCTAssertEqual(Settings.theme, .fall)
        XCTAssertEqual(Settings.Theme.allCases.first, .fall, "Fall comes first everywhere")
    }

    func testDockorate10sFallChoiceIsKept() {
        // Dockorate 1.0 saved its only theme as "fall".
        defaults.set("fall", forKey: "theme")
        XCTAssertEqual(Settings.themeChoice, .keep(.fall))
    }

    func testChoicesAreSavedAndReadBack() {
        for choice in Settings.ThemeChoice.allCases {
            Settings.themeChoice = choice
            XCTAssertEqual(Settings.themeChoice, choice)
            XCTAssertEqual(Settings.ThemeChoice(rawValue: choice.rawValue), choice)
            XCTAssertFalse(choice.title.isEmpty)
        }
        XCTAssertEqual(Settings.ThemeChoice(rawValue: "automatic"), .calendar, "what the Halloween branch saved")
        defaults.set("spring-that-does-not-exist", forKey: "theme")
        XCTAssertEqual(Settings.themeChoice, .keep(.fall))
    }

    func testKeepingAThemeIgnoresTheCalendar() {
        for day in [date(1, 10), date(10, 31), date(12, 25)] {
            XCTAssertEqual(Settings.ThemeChoice.keep(.fall).theme(on: day), .fall)
            XCTAssertEqual(Settings.ThemeChoice.keep(.halloween).theme(on: day), .halloween)
        }
        XCTAssertNil(Settings.ThemeChoice.keep(.halloween).next(after: date(10, 1)))
    }

    func testTheCalendarBringsHalloweenFromOctober15ToNovember1() {
        let calendar = Settings.ThemeChoice.calendar
        XCTAssertEqual(calendar.theme(on: date(10, 14)), .fall)
        XCTAssertEqual(calendar.theme(on: date(10, 15)), .halloween)
        XCTAssertEqual(calendar.theme(on: date(10, 31)), .halloween)
        XCTAssertEqual(calendar.theme(on: date(11, 1)), .halloween)
        XCTAssertEqual(calendar.theme(on: date(11, 2)), .fall)
        XCTAssertEqual(calendar.theme(on: date(3, 3)), .fall, "Fall the rest of the year")
        XCTAssertEqual(calendar.theme(on: date(10, 20, year: 2028)), .halloween, "every year, leap years too")
    }

    func testTheCalendarKnowsWhatComesNext() throws {
        let calendar = Settings.ThemeChoice.calendar
        let toHalloween = try XCTUnwrap(calendar.next(after: date(10, 1)))
        XCTAssertEqual(toHalloween.theme, .halloween)
        XCTAssertEqual(Calendar.current.dateComponents([.month, .day], from: toHalloween.date), DateComponents(month: 10, day: 15))
        let backToFall = try XCTUnwrap(calendar.next(after: date(10, 20)))
        XCTAssertEqual(backToFall.theme, .fall)
        XCTAssertEqual(Calendar.current.dateComponents([.month, .day], from: backToFall.date), DateComponents(month: 11, day: 2))
    }

    func testScheduleWords() {
        XCTAssertEqual(ThemeSchedule.summary(.keep(.fall)), "Fall stays on your Dock all year.")
        XCTAssertTrue(ThemeSchedule.summary(.calendar, now: date(10, 1)).hasPrefix("Fall now, then Halloween on"))
        XCTAssertTrue(ThemeSchedule.window(.halloween).contains(" to "))
    }

    func testResetEverythingGoesBackToFall() {
        Settings.themeChoice = .keep(.halloween)
        Settings.bats = false
        Settings.ghost = false
        Settings.resetAll()
        Settings.registerDefaults()
        XCTAssertEqual(Settings.themeChoice, .keep(.fall))
        XCTAssertTrue(Settings.bats)
        XCTAssertTrue(Settings.ghost)
    }

    func testEachThemeHasItsOwnVisitor() {
        Settings.squirrel = false
        Settings.ghost = true
        Settings.themeChoice = .keep(.fall)
        XCTAssertFalse(Settings.visitor, "the squirrel's switch in fall")
        Settings.themeChoice = .keep(.halloween)
        XCTAssertTrue(Settings.visitor, "the ghost's switch at Halloween")
    }

    // MARK: What each theme grows

    func testEveryThemeHasItsOwnExtras() {
        let fall = Set(Settings.Theme.fall.extras), halloween = Set(Settings.Theme.halloween.extras)
        XCTAssertTrue(fall.isDisjoint(with: halloween))
        XCTAssertEqual(fall.union(halloween), Set(DecorKind.allCases), "every extra belongs to a theme")
        for theme in Settings.Theme.allCases {
            XCTAssertTrue(Set(theme.gapCycle).isSubset(of: theme.extras), "\(theme)")
            XCTAssertTrue(theme.specials.isSubset(of: theme.extras), "\(theme)")
            XCTAssertTrue(theme.extras.contains(theme.perch), "\(theme)")
            XCTAssertFalse(theme.title.isEmpty)
            XCTAssertFalse(theme.headline.isEmpty)
        }
    }

    @MainActor func testFallHarvestIsUnchanged() {
        Settings.themeChoice = .keep(.fall)
        let scene = harvest()
        XCTAssertTrue(Set(scene.gapKinds).isSubset(of: Settings.Theme.fall.extras))
        XCTAssertTrue(pumpkins(in: scene).allSatisfy { PumpkinKind.fall.contains($0.kind) })
        XCTAssertFalse(pumpkins(in: scene).contains { $0.isLantern }, "no jack-o'-lanterns in fall")
        let perches = scene.pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.gap < 0 }
        XCTAssertFalse(perches.isEmpty)
        XCTAssertTrue(perches.allSatisfy { $0.kind == .hayBale })
        XCTAssertTrue(scene.hasVine)
    }

    @MainActor func testHalloweenGrowsJackOLanternsAndSpookyExtras() {
        Settings.themeChoice = .keep(.halloween)
        let scene = harvest()
        XCTAssertGreaterThan(scene.pumpkinCount, 2)
        XCTAssertFalse(scene.gapKinds.isEmpty)
        XCTAssertTrue(Set(scene.gapKinds).isSubset(of: Settings.Theme.halloween.extras))
        XCTAssertTrue(pumpkins(in: scene).allSatisfy { PumpkinKind.halloween.contains($0.kind) })
        XCTAssertTrue(pumpkins(in: scene).filter(\.kind.isCarvable).allSatisfy(\.isLantern), "orange pumpkins are carved")
        let perches = scene.pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.gap < 0 }
        XCTAssertTrue(perches.allSatisfy { $0.kind == .crypt }, "crypt pedestals instead of hay bales")
        XCTAssertTrue(scene.hasVine, "graveyard dirt along the Dock")
    }

    @MainActor func testSmashingAJackOLanternWorks() {
        Settings.themeChoice = .keep(.halloween)
        Settings.sound = false
        let scene = harvest()
        var smashes = 0
        scene.onSmash = { smashes += 1 }
        let lantern = try! XCTUnwrap(pumpkins(in: scene).first { $0.isLantern })
        scene.smash(lantern)
        XCTAssertEqual(smashes, 1)
        XCTAssertNotNil(scene.action(forKey: "respawn-\(lantern.slot)"))
    }

    // MARK: Changing theme

    @MainActor func testChangingThemeCrossfades() {
        Settings.themeChoice = .keep(.fall)
        let scene = harvest()
        let oldPumpkins = pumpkins(in: scene)
        XCTAssertFalse(oldPumpkins.isEmpty)

        Settings.themeChoice = .keep(.halloween)
        scene.crossfadeNextHarvest = true
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: 1600, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: true)

        XCTAssertFalse(scene.crossfadeNextHarvest, "only the one change crossfades")
        let outgoing = scene["//outgoing-harvest"]
        XCTAssertFalse(outgoing.isEmpty, "the old harvest is still there, fading")
        XCTAssertTrue(oldPumpkins.allSatisfy { $0.isDetached }, "the old pumpkins can't be clicked")
        XCTAssertTrue(oldPumpkins.allSatisfy { $0.parent?.name == "outgoing-harvest" })
        let newPumpkins = pumpkins(in: scene)
        XCTAssertEqual(newPumpkins.count, scene.pumpkinCount)
        XCTAssertTrue(newPumpkins.allSatisfy { PumpkinKind.halloween.contains($0.kind) })
        XCTAssertTrue(newPumpkins.allSatisfy { $0.action(forKey: "grow") != nil }, "the new harvest grows in")
    }

    @MainActor func testFirstHarvestJustAppears() {
        let scene = PumpkinScene(size: CGSize(width: 1640, height: 220))
        scene.crossfadeNextHarvest = true
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: 1600, height: 60), pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        XCTAssertTrue(scene["//outgoing-harvest"].isEmpty, "nothing to fade away")
    }

    @MainActor func testWindowHarvestGrowsBothThemes() {
        for theme in Settings.Theme.allCases {
            Settings.themeChoice = .keep(theme)
            let live = LiveHarvest()
            live.layout(size: CGSize(width: 700, height: 300), regrow: true)
            XCTAssertGreaterThan(live.scene.pumpkinCount, 0, "\(theme)")
        }
    }

    // MARK: Art

    @MainActor func testHalloweenArtDraws() {
        XCTAssertGreaterThan(ExtraArt.ghost().size.width, 0)
        XCTAssertGreaterThan(ExtraArt.jackOLantern().size.width, 0)
        XCTAssertGreaterThan(ThemePreview.image(for: .halloween).size.width, 0)
        for kind in Settings.Theme.halloween.extras {
            XCTAssertGreaterThan(ExtraArt.image(for: kind).size.width, 0, "\(kind)")
        }
    }
}
