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
        XCTAssertEqual(Settings.ThemeChoice(rawValue: "automatic"), .automatic, "what the Halloween branch saved too")
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

    private func monthDay(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.month, .day], from: date)
    }

    func testFestivalsGoOnAWeekBeforeTheirDay() {
        let automatic = Settings.ThemeChoice.automatic
        for year in [2026, 2027, 2028, 2031] {
            XCTAssertEqual(automatic.theme(on: date(10, 23, year: year)), .fall, "\(year)")
            XCTAssertEqual(automatic.theme(on: date(10, 24, year: year)), .halloween, "a week before Halloween, \(year)")
            XCTAssertEqual(automatic.theme(on: date(10, 31, year: year)), .halloween, "Halloween itself, \(year)")
            XCTAssertEqual(automatic.theme(on: date(11, 1, year: year)), .fall, "the season again the day after, \(year)")
        }
    }

    func testTheSeasonStaysOnBetweenFestivals() {
        // Fall is the only season so far, so it stays on until the next season is added.
        for (month, day) in [(1, 10), (3, 3), (7, 4), (9, 1), (10, 15), (12, 25)] {
            XCTAssertEqual(Settings.ThemeChoice.automatic.theme(on: date(month, day)), .fall, "\(month)/\(day)")
            XCTAssertEqual(Settings.Theme.season(on: date(month, day)), .fall)
        }
    }

    func testEveryThemeHasAPlaceInTheYear() {
        XCTAssertFalse(Settings.Theme.seasons.isEmpty)
        XCTAssertEqual(Settings.Theme.seasons.first, .fall, "Fall, the original, comes first")
        for theme in Settings.Theme.allCases {
            switch theme.kind {
            case .season:
                XCTAssertNotNil(theme.seasonStart, "\(theme)")
                XCTAssertNil(theme.festivalDay(in: 2026))
            case .festival:
                XCTAssertNil(theme.seasonStart, "\(theme)")
                for year in 2026...2040 {
                    let week = try! XCTUnwrap(theme.festivalWeek(in: year), "\(theme) \(year)")
                    let days = Calendar.current.dateComponents([.day], from: week.lowerBound, to: week.upperBound).day
                    XCTAssertEqual(days, Settings.Theme.festivalLead, "\(theme) \(year)")
                }
            }
        }
        XCTAssertEqual(Settings.Theme.halloween.kind, .festival)
        XCTAssertEqual(Settings.Theme.fall.kind, .season)
    }

    func testChangingAutomaticallyKnowsWhatComesNext() throws {
        let automatic = Settings.ThemeChoice.automatic
        let toHalloween = try XCTUnwrap(automatic.next(after: date(10, 15)))
        XCTAssertEqual(toHalloween.theme, .halloween)
        XCTAssertEqual(monthDay(toHalloween.date), DateComponents(month: 10, day: 24))
        let backToFall = try XCTUnwrap(automatic.next(after: date(10, 26)))
        XCTAssertEqual(backToFall.theme, .fall)
        XCTAssertEqual(monthDay(backToFall.date), DateComponents(month: 11, day: 1))

        let changes = automatic.changes(after: date(10, 15), count: 3)
        XCTAssertEqual(changes.map { $0.theme }, [.halloween, .fall, .halloween])
        XCTAssertEqual(changes.map { monthDay($0.date) },
                       [DateComponents(month: 10, day: 24), DateComponents(month: 11, day: 1), DateComponents(month: 10, day: 24)])
        XCTAssertEqual(Calendar.current.component(.year, from: changes[2].date), 2027)
        XCTAssertTrue(Settings.ThemeChoice.keep(.fall).changes(after: date(10, 15), count: 3).isEmpty)
    }

    @MainActor func testTheYearShowsEachThemeInTurn() {
        let year = ThemeYear.stretches(in: 2026)
        XCTAssertEqual(year.days, 365)
        XCTAssertEqual(year.stretches.map(\.theme), [.fall, .halloween, .fall])
        XCTAssertEqual(year.stretches.first?.first, 0)
        XCTAssertEqual(year.stretches.last?.last, 364)
        for (a, b) in zip(year.stretches, year.stretches.dropFirst()) {
            XCTAssertEqual(a.last + 1, b.first, "no gaps")
        }
        XCTAssertEqual(year.stretches[1].last - year.stretches[1].first, Settings.Theme.festivalLead, "a week, and the day")
        XCTAssertEqual(ThemeYear.stretches(in: 2028).days, 366)
    }

    // MARK: The rotation

    func testEveryThemeIsInTheRotationUntilLeftOut() {
        XCTAssertEqual(Settings.rotation, Set(Settings.Theme.allCases))
        Settings.rotation = [.fall]
        XCTAssertEqual(Settings.rotation, [.fall])
        // Saved as the ones left out, so themes added in an update join the rotation by themselves.
        XCTAssertEqual(defaults.stringArray(forKey: "themesLeftOut"), ["halloween"])
        defaults.set(["halloween", "a-theme-from-a-later-version"], forKey: "themesLeftOut")
        XCTAssertEqual(Settings.rotation, [.fall])
    }

    @MainActor func testAThemeLeftOutOfTheRotationNeverComesOnByItself() {
        Settings.rotation = [.fall]
        let automatic = Settings.ThemeChoice.automatic
        XCTAssertEqual(automatic.theme(on: date(10, 28)), .fall, "Halloween's week stays with the season")
        XCTAssertNil(automatic.next(after: date(10, 15)), "nothing else to change to")
        XCTAssertEqual(ThemeYear.stretches(in: 2026, rotation: [.fall]).stretches.map(\.theme), [.fall])
        XCTAssertEqual(ThemeSchedule.summary(.automatic, now: date(10, 15)), "Fall stays on your Dock all year.")
        XCTAssertEqual(Settings.ThemeChoice.keep(.halloween).theme(on: date(3, 1)), .halloween, "it can still be kept on its own")

        Settings.rotation = Set(Settings.Theme.allCases)
        XCTAssertEqual(automatic.theme(on: date(10, 28)), .halloween)
    }

    func testTheLastSeasonStaysInTheRotation() {
        XCTAssertTrue(Settings.canLeave(.halloween, [.fall, .halloween]), "festivals can all be left out")
        XCTAssertFalse(Settings.canLeave(.fall, [.fall, .halloween]), "the only season stays, for the days between festivals")
        Settings.rotation = [.halloween]
        XCTAssertEqual(Settings.rotation, [.fall, .halloween], "a season always comes back in")
        XCTAssertEqual(ThemeSchedule.dates(.fall, rotation: [.fall, .halloween]), "All year, between festivals")
        XCTAssertTrue(ThemeSchedule.dates(.halloween, rotation: [.fall, .halloween]).contains(" to "))
    }

    func testScheduleWords() {
        XCTAssertEqual(ThemeSchedule.summary(.keep(.fall)), "Fall stays on your Dock all year.")
        XCTAssertTrue(ThemeSchedule.summary(.automatic, now: date(10, 15)).hasPrefix("Fall now, then Halloween on"))
        XCTAssertTrue(ThemeSchedule.window(.halloween).contains(" to "))
        XCTAssertEqual(ThemeSchedule.when(.fall), "Season")
        XCTAssertTrue(ThemeSchedule.when(.halloween).hasPrefix("Festival, "))
        XCTAssertEqual(ThemeSchedule.countdown(to: date(10, 16), now: date(10, 15)), "Tomorrow")
        XCTAssertEqual(ThemeSchedule.countdown(to: date(10, 24), now: date(10, 15)), "In 9 days")
        XCTAssertTrue(ThemeSchedule.upcoming(.halloween, start: date(10, 24), end: date(11, 1)).contains(" to "))
        XCTAssertTrue(ThemeSchedule.upcoming(.fall, start: date(11, 1), end: date(10, 24, year: 2027)).hasPrefix("From "))
    }

    func testResetEverythingGoesBackToFall() {
        Settings.themeChoice = .keep(.halloween)
        Settings.rotation = [.fall]
        Settings.bats = false
        Settings.ghost = false
        Settings.resetAll()
        Settings.registerDefaults()
        XCTAssertEqual(Settings.themeChoice, .keep(.fall))
        XCTAssertEqual(Settings.rotation, Set(Settings.Theme.allCases), "every theme back in the rotation")
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

    @MainActor func testCobwebsSitOverEachTopCornerOfTheDock() {
        Settings.themeChoice = .keep(.halloween)
        let dock = CGRect(x: 120, y: 0, width: 1200, height: 70)
        let scene = PumpkinScene(size: CGSize(width: 1440, height: 220))
        scene.configure(dockRect: dock, pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        let webs = scene.pumpkinLayer.children.compactMap { $0 as? WebNode }.sorted { $0.restX < $1.restX }
        XCTAssertEqual(webs.count, 2)
        let left = webs[0], right = webs[1]
        // Each fans up and outward from a little inside the Dock's top corner.
        XCTAssertGreaterThan(left.restX, dock.minX)
        XCTAssertLessThan(right.restX, dock.maxX)
        XCTAssertLessThan(left.restY, dock.maxY)
        XCTAssertEqual(left.restY, right.restY)
        XCTAssertLessThan(left.facing, 0, "the left web opens to the left, away from the Dock")
        XCTAssertGreaterThan(right.facing, 0, "the right web opens to the right")
        XCTAssertLessThanOrEqual(left.size.height, dock.height, "no taller than the Dock")
        XCTAssertFalse(left.risesWithIcons, "it stays put on the Dock when the icons magnify")

        // Placed, each reaches over the Dock's end and its top edge, and is mostly above the Dock.
        scene.update(1)
        scene.update(1.1)
        for (web, end) in [(left, dock.minX), (right, dock.maxX)] {
            let frame = web.calculateAccumulatedFrame()
            XCTAssertLessThan(frame.minX, end, "\(frame) crosses the end of the Dock")
            XCTAssertGreaterThan(frame.maxX, end, "\(frame) crosses the end of the Dock")
            XCTAssertLessThan(frame.minY, dock.maxY, "\(frame) overlaps the top of the Dock")
            XCTAssertGreaterThan(frame.midY, dock.maxY, "\(frame) sits on top of the Dock")
        }

        Settings.themeChoice = .keep(.fall)
        scene.configure(dockRect: dock, pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        XCTAssertTrue(scene.pumpkinLayer.children.compactMap { $0 as? WebNode }.isEmpty, "no cobwebs in fall")
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
