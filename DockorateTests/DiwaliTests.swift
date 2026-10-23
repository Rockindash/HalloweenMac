import SpriteKit
import XCTest
@testable import Dockorate

/// Diwali: its days (it follows the moon), what it grows on the Dock, what its lamps, crackers and sweets
/// do when clicked, the peacock and its art. (Its desktop pictures are in WallpaperTests.)
final class DiwaliTests: SettingsTestCase {
    private func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func monthDay(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.month, .day], from: date)
    }

    @MainActor private func harvest(width: CGFloat = 2000) -> PumpkinScene {
        let scene = PumpkinScene(size: CGSize(width: width + 40, height: 300))
        scene.configure(dockRect: CGRect(x: 20, y: 8, width: width, height: 60),
                        pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        return scene
    }

    @MainActor private func lamps(in scene: PumpkinScene) -> [PumpkinNode] {
        scene.pumpkinLayer.children.compactMap { $0 as? PumpkinNode }
    }

    // MARK: Its days

    func testDiwaliFollowsTheMoon() throws {
        // Lakshmi Puja, the main day, moves between mid October and mid November.
        let days: [(year: Int, month: Int, day: Int)] = [(2026, 11, 8), (2027, 10, 29), (2028, 10, 17), (2030, 10, 26),
                                                         (2031, 11, 14), (2035, 10, 30), (2040, 11, 4)]
        for (year, month, day) in days {
            let diwali = try XCTUnwrap(Settings.Theme.diwali.festivalDay(in: year), "\(year)")
            let parts = monthDay(diwali)
            XCTAssertEqual(parts.month, month, "\(year)")
            XCTAssertEqual(parts.day, day, "\(year)")
        }
        for year in 2026...2043 {
            let diwali = try XCTUnwrap(Settings.Theme.diwali.festivalDay(in: year), "\(year)")
            XCTAssertTrue((date(10, 15, year: year)...date(11, 16, year: year)).contains(diwali), "\(year): \(diwali)")
        }
        XCTAssertEqual(Settings.Theme.diwali.kind, .festival)
        XCTAssertNil(Settings.Theme.diwali.seasonStart)
    }

    func testDiwaliGoesOnAWeekBeforeItsDay() {
        let automatic = Settings.ThemeChoice.automatic
        // 2026: Halloween's week, then Diwali's the very next day.
        XCTAssertEqual(automatic.theme(on: date(10, 31)), .halloween)
        XCTAssertEqual(automatic.theme(on: date(11, 1)), .diwali, "a week before November 8th")
        XCTAssertEqual(automatic.theme(on: date(11, 8)), .diwali, "Diwali itself")
        XCTAssertEqual(automatic.theme(on: date(11, 9)), .fall, "the season again the day after")
        // 2028: well before Halloween.
        XCTAssertEqual(automatic.theme(on: date(10, 9, year: 2028)), .fall)
        XCTAssertEqual(automatic.theme(on: date(10, 10, year: 2028)), .diwali)
        XCTAssertEqual(automatic.theme(on: date(10, 17, year: 2028)), .diwali)
        XCTAssertEqual(automatic.theme(on: date(10, 18, year: 2028)), .fall)
        XCTAssertEqual(automatic.theme(on: date(10, 24, year: 2028)), .halloween)
    }

    @MainActor func testWhenDiwaliAndHalloweenOverlapTheOneThatEndsFirstGoesFirst() {
        // 2027: Diwali is October 29th, so its week runs into Halloween's.
        let automatic = Settings.ThemeChoice.automatic
        XCTAssertEqual(automatic.theme(on: date(10, 21, year: 2027)), .fall)
        XCTAssertEqual(automatic.theme(on: date(10, 22, year: 2027)), .diwali)
        XCTAssertEqual(automatic.theme(on: date(10, 25, year: 2027)), .diwali, "both are on; Diwali comes first")
        XCTAssertEqual(automatic.theme(on: date(10, 29, year: 2027)), .diwali)
        XCTAssertEqual(automatic.theme(on: date(10, 30, year: 2027)), .halloween, "then Halloween's last days")
        XCTAssertEqual(automatic.theme(on: date(11, 1, year: 2027)), .fall)
        XCTAssertEqual(ThemeYear.stretches(in: 2027).stretches.map(\.theme), [.fall, .diwali, .halloween, .fall])
    }

    func testDiwaliCanBeLeftOutOrKept() {
        Settings.rotation = [.fall, .halloween]
        XCTAssertEqual(Settings.ThemeChoice.automatic.theme(on: date(11, 3)), .fall, "Diwali's week stays with the season")
        XCTAssertTrue(Settings.canLeave(.diwali, Settings.rotation.union([.diwali])))
        XCTAssertEqual(Settings.ThemeChoice.keep(.diwali).theme(on: date(3, 1)), .diwali, "it can still be kept all year")
        Settings.themeChoice = .keep(.diwali)
        XCTAssertEqual(Settings.themeChoice, .keep(.diwali), "saved and read back")
        XCTAssertEqual(defaults.string(forKey: "theme"), "diwali")
    }

    func testDiwalisSwitchesStartOnAndAreKept() {
        XCTAssertTrue(Settings.fireworks)
        XCTAssertTrue(Settings.peacock)
        Settings.fireworks = false
        Settings.peacock = false
        XCTAssertFalse(Settings.fireworks)
        XCTAssertFalse(Settings.peacock)
        Settings.themeChoice = .keep(.diwali)
        XCTAssertFalse(Settings.visitor, "the peacock is Diwali's visitor")
        Settings.peacock = true
        XCTAssertTrue(Settings.visitor)
    }

    func testDiwalisWords() {
        let diwali = Settings.Theme.diwali
        XCTAssertEqual(diwali.title, "Diwali")
        XCTAssertEqual(diwali.vineTitle, "Marigold garland")
        XCTAssertEqual(diwali.visitorTitle, "Peacock")
        XCTAssertEqual(diwali.perch, .giftBoxes)
        XCTAssertTrue(diwali.extras.contains(.rangoli))
        XCTAssertTrue(diwali.extras.contains(.laddoos))
        XCTAssertTrue(Set([DecorKind.anar, .rocket, .chakri]).isSubset(of: diwali.extras), "the crackers")
        XCTAssertTrue(DecorKind.allCases.filter { $0.theme == .diwali }.allSatisfy { !$0.isSpooky })
    }

    // MARK: On the Dock

    @MainActor func testDiwaliGrowsLitDiyasAndFestiveExtras() {
        Settings.themeChoice = .keep(.diwali)
        let scene = harvest()
        let lit = lamps(in: scene)
        XCTAssertGreaterThan(lit.count, 2)
        XCTAssertTrue(lit.allSatisfy { PumpkinKind.diwali.contains($0.kind) }, "diyas and lamps, no pumpkins")
        XCTAssertTrue(lit.allSatisfy(\.kind.isLamp))
        for lamp in lit {
            XCTAssertTrue(lamp.isLit, "\(lamp.kind)")
            XCTAssertFalse(lamp.isLantern)
            let flames = lamp.children.filter { $0.name == "flame" }
            XCTAssertEqual(flames.count, DiwaliArt.flameSpots(lamp.kind.look.shape).count, "a flame on each wick of the \(lamp.kind)")
            XCTAssertNotNil(lamp.childNode(withName: "candle"), "and a warm glow")
        }
        XCTAssertFalse(scene.gapKinds.isEmpty)
        XCTAssertTrue(Set(scene.gapKinds).isSubset(of: Settings.Theme.diwali.extras))
        let perches = scene.pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.gap < 0 }
        XCTAssertFalse(perches.isEmpty)
        XCTAssertTrue(perches.allSatisfy { $0.kind == .giftBoxes }, "gift boxes instead of hay bales")
        XCTAssertTrue(scene.hasVine, "a marigold garland along the Dock")
        XCTAssertTrue(scene.pumpkinLayer.children.compactMap { $0 as? WebNode }.isEmpty, "no cobwebs")
    }

    @MainActor func testTheTallLampAndLotusDiyaStayOffTheGiftBoxes() {
        Settings.themeChoice = .keep(.diwali)
        for _ in 0..<5 {
            let scene = harvest()
            for lamp in lamps(in: scene) where lamp.perch > 0 {
                XCTAssertTrue([.diyaClay, .diyaBrass, .diyaPink].contains(lamp.kind), "\(lamp.kind) on the gift boxes")
            }
        }
    }

    @MainActor func testClickingADiyaLightsUpTheSkyRatherThanSmashingIt() throws {
        Settings.themeChoice = .keep(.diwali)
        Settings.sound = false
        let scene = harvest()
        var smashes = 0, lightUps = 0
        scene.onSmash = { smashes += 1 }
        scene.onLightUp = { lightUps += 1 }
        let lamp = try XCTUnwrap(lamps(in: scene).first)
        XCTAssertTrue(scene.effectsLayer.children.isEmpty)

        scene.lightUp(lamp)
        XCTAssertEqual(smashes, 0, "lamps aren't smashed")
        XCTAssertEqual(lightUps, 1, "it counts as a diya lit")
        XCTAssertFalse(lamp.isSmashing)
        XCTAssertTrue(lamp.parent === scene.pumpkinLayer, "still on the Dock")
        XCTAssertTrue(lamp.isInteractive)
        XCTAssertNil(scene.action(forKey: "respawn-\(lamp.slot)"), "nothing to grow back")
        XCTAssertEqual(scene.effectsLayer.children.count, 1, "a firework on its way up")
        XCTAssertNotNil(lamp.action(forKey: "light-up"))

        scene.lightUp(lamp)
        XCTAssertEqual(scene.effectsLayer.children.count, 1, "one at a time from each lamp")
        XCTAssertEqual(lightUps, 1, "and a click while it's going off isn't counted again")
    }

    @MainActor func testAFireworkBurstsIntoStreaksAndSparks() {
        Settings.themeChoice = .keep(.diwali)
        let scene = harvest()
        scene.fireworkBurst(at: CGPoint(x: 400, y: 200), radius: 40, colors: [Palette.magenta, Palette.marigold])
        let pieces = scene.effectsLayer.children.filter { $0.name == "firework" }
        XCTAssertGreaterThanOrEqual(pieces.count, 15, "a flash and a ring of streaks")
        XCTAssertGreaterThan(scene.effectsLayer.children.count, pieces.count, "and sparks left twinkling")
        XCTAssertFalse(PumpkinScene.fireworkColors.isEmpty)
    }

    /// A festive extra on its own, dressed the way the harvest dresses it.
    @MainActor private func extra(_ kind: DecorKind, in scene: PumpkinScene) -> DecorNode {
        let unit = scene.decorUnit
        let decor = DecorNode(kind: kind, gap: kind == .giftBoxes ? -1 : 0,
                              texture: CozyArt.texture(kind, unit: unit, variant: 0, scale: 1), size: CozyArt.size(of: kind, unit: unit))
        decor.anchorPoint = CGPoint(x: 0.5, y: 0)
        decor.position = CGPoint(x: 300, y: 68)
        scene.pumpkinLayer.addChild(decor)
        scene.dressDiwali(decor)
        return decor
    }

    @MainActor func testTheCrackersGoOff() throws {
        Settings.themeChoice = .keep(.diwali)
        Settings.sound = false
        let scene = harvest(width: 600)

        let anar = extra(.anar, in: scene)
        scene.pokeDiwali(anar)
        XCTAssertNotNil(anar.action(forKey: "fountain"), "the anar throws up a fountain of sparks")

        let bottle = extra(.rocket, in: scene)
        let rocket = try XCTUnwrap(bottle.childNode(withName: "rocket"), "a rocket stands in the bottle")
        scene.pokeDiwali(bottle)
        XCTAssertEqual(rocket.alpha, 0, "it's gone from the bottle")
        XCTAssertTrue(scene.effectsLayer.children.contains { $0.name == "rocket" }, "and flying up")
        XCTAssertNotNil(bottle.action(forKey: "reload"), "another one appears a moment later")
        let flying = scene.effectsLayer.children.count
        scene.pokeDiwali(bottle)
        XCTAssertEqual(scene.effectsLayer.children.count, flying, "not until it's back")

        let chakri = extra(.chakri, in: scene)
        let wheel = try XCTUnwrap(chakri.childNode(withName: "wheel"))
        scene.pokeDiwali(chakri)
        XCTAssertNotNil(wheel.action(forKey: "whirl"), "the chakri spins")
        XCTAssertNotNil(chakri.action(forKey: "spin"), "throwing off sparks")
    }

    @MainActor func testTheSweetsAndDecorationsDoThingsToo() throws {
        Settings.themeChoice = .keep(.diwali)
        Settings.sound = false
        let scene = harvest(width: 600)

        var before = scene.effectsLayer.children.count
        scene.pokeDiwali(extra(.laddoos, in: scene))
        XCTAssertEqual(scene.effectsLayer.children.count, before + 3, "laddoos fly off the plate")
        before = scene.effectsLayer.children.count
        scene.pokeDiwali(extra(.mithai, in: scene))
        XCTAssertEqual(scene.effectsLayer.children.count, before + 4, "and sweets out of the box")

        let kandil = extra(.kandil, in: scene)
        let lantern = try XCTUnwrap(kandil.childNode(withName: "kandil"), "the kandil hangs from its stand")
        XCTAssertNotNil(lantern.childNode(withName: "glow"))
        scene.pokeDiwali(kandil)
        XCTAssertNotNil(lantern.action(forKey: "sway"), "it swings")

        let rangoli = extra(.rangoli, in: scene)
        XCTAssertEqual(rangoli.children.filter { $0.name == "flame" }.count, 2, "a little diya lit at each end")
        scene.pokeDiwali(rangoli)
        XCTAssertGreaterThan(rangoli.children.filter { $0.name == "spark" }.count, 5, "sparkles all over it")

        let bowl = extra(.flowerBowl, in: scene)
        XCTAssertEqual(bowl.children.filter { $0.name == "flame" }.count, 1, "a diya floating in the bowl")
        before = scene.effectsLayer.children.count
        scene.pokeDiwali(bowl)
        XCTAssertGreaterThan(scene.effectsLayer.children.count, before, "petals bob up")

        before = scene.effectsLayer.children.count
        scene.pokeDiwali(extra(.giftBoxes, in: scene))
        XCTAssertGreaterThan(scene.effectsLayer.children.count, before, "petals burst out of the gift boxes")
    }

    @MainActor func testMarigoldsHangInEachTopCornerOfTheDock() {
        Settings.themeChoice = .keep(.diwali)
        let dock = CGRect(x: 120, y: 0, width: 1200, height: 70)
        let scene = PumpkinScene(size: CGSize(width: 1440, height: 260))
        scene.configure(dockRect: dock, pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        let strands = scene.pumpkinLayer.children.compactMap { $0 as? StrandNode }.sorted { $0.restX < $1.restX }
        XCTAssertEqual(strands.count, 2)
        XCTAssertEqual(strands.first?.restX, dock.minX)
        XCTAssertEqual(strands.last?.restX, dock.maxX)
        XCTAssertTrue(strands.allSatisfy { $0.restY == dock.maxY && !$0.isInteractive && !$0.risesWithIcons })
        XCTAssertEqual(strands.map(\.facing), [1, -1], "the right one is a mirror image")
        XCTAssertTrue(strands.allSatisfy { $0.size.height <= dock.height }, "no taller than the Dock")

        Settings.showVines = false
        scene.configure(dockRect: dock, pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        XCTAssertFalse(scene.hasVine, "the garland follows the Vine switch")
        XCTAssertTrue(scene.pumpkinLayer.children.compactMap { $0 as? StrandNode }.isEmpty, "and so do the strings")

        Settings.showVines = true
        Settings.themeChoice = .keep(.halloween)
        scene.configure(dockRect: dock, pixelScale: 1, magnifier: DockMagnifier(), regrow: true)
        XCTAssertTrue(scene.pumpkinLayer.children.compactMap { $0 as? StrandNode }.isEmpty, "only at Diwali")
    }

    @MainActor func testThePeacockStrutsByAndShowsOff() throws {
        Settings.themeChoice = .keep(.diwali)
        let scene = harvest()
        scene.peacockVisit()
        let peacock = try XCTUnwrap(scene.pumpkinLayer.children.compactMap { $0 as? PeacockNode }.first)
        XCTAssertNotNil(peacock.action(forKey: "visit"))
        XCTAssertNotNil(peacock.childNode(withName: "train"), "its long train")
        XCTAssertEqual(peacock.childNode(withName: "fan")?.alpha, 0, "the fan is folded away")
        scene.peacockVisit()
        XCTAssertEqual(scene.pumpkinLayer.children.filter { $0 is PeacockNode }.count, 1, "one at a time")

        scene.peacockFlee(peacock)
        XCTAssertTrue(peacock.isFleeing)
        XCTAssertTrue(peacock.isDisplaying, "clicked, it fans out its tail before it hurries off")
        XCTAssertNotNil(peacock.action(forKey: "visit"))
    }

    @MainActor func testThePeacockStaysAwayWhenSwitchedOff() {
        Settings.themeChoice = .keep(.diwali)
        Settings.peacock = false
        let scene = harvest()
        scene.peacockVisit()
        XCTAssertFalse(scene.pumpkinLayer.children.contains { $0 is PeacockNode })
    }

    @MainActor func testDiwaliGrowsInTheAppWindowToo() {
        Settings.themeChoice = .keep(.diwali)
        let live = LiveHarvest()
        live.layout(size: CGSize(width: 700, height: 300), regrow: true)
        XCTAssertGreaterThan(live.scene.pumpkinCount, 0)
        XCTAssertTrue(live.scene.pumpkinLayer.children.compactMap { $0 as? PumpkinNode }.allSatisfy(\.isLit))
    }

    // MARK: Art

    /// The alpha of the pixel at `point` (in points, from the bottom left) of a texture drawn at scale 1.
    private func alpha(of texture: SKTexture, at point: CGPoint) -> Int {
        let image = texture.cgImage()
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -point.x.rounded(.down), y: -point.y.rounded(.down), width: CGFloat(image.width), height: CGFloat(image.height)))
        return Int(pixel[3])
    }

    @MainActor func testEveryLampsFlamesSitOnItsWicks() {
        for kind in PumpkinKind.allCases where kind.isLamp {
            let height: CGFloat = 120
            let texture = PumpkinArt.texture(kind: kind, height: height, variant: 0, scale: 1)
            let size = PumpkinArt.size(of: kind, height: height), body = PumpkinArt.bodySize(of: kind, height: height)
            for spot in DiwaliArt.flameSpots(kind.look.shape) {
                // Just under where the flame burns is the lamp itself, not thin air.
                let x = size.width / 2 + spot.x * body.width
                let under = (1...6).map { CGPoint(x: x, y: PumpkinArt.pad + (spot.y - CGFloat($0) * 0.01) * body.height) }
                XCTAssertTrue(under.contains { alpha(of: texture, at: $0) > 200 }, "\(kind) at \(spot)")
            }
            XCTAssertEqual(alpha(of: texture, at: CGPoint(x: 1, y: size.height - 2)), 0, "\(kind): nothing in the corner")
        }
    }

    @MainActor func testTheMovingPartsFitTheirExtras() {
        let unit: CGFloat = 60
        // The rocket stands in its bottle without poking out of the picture.
        let bottle = CozyArt.size(of: .rocket, unit: unit)
        XCTAssertLessThanOrEqual((bottle.height * DiwaliArt.rocketFoot).rounded() + DiwaliArt.rocketSize(unit: unit).height, bottle.height + 1)
        // The chakri's wheel turns on its stake, inside the picture.
        let chakri = CozyArt.size(of: .chakri, unit: unit)
        let wheel = unit * DiwaliArt.chakriWheel
        XCTAssertLessThanOrEqual(wheel, chakri.width)
        XCTAssertLessThanOrEqual(chakri.height * DiwaliArt.chakriHub + wheel / 2, chakri.height + 1)
        XCTAssertGreaterThanOrEqual(chakri.height * DiwaliArt.chakriHub - wheel / 2, 0)
        // The kandil hangs from its hook above the floor, inside the stand's picture.
        let stand = CozyArt.size(of: .kandil, unit: unit), kandil = DiwaliArt.kandilSize(unit: unit)
        XCTAssertGreaterThan(stand.height * DiwaliArt.kandilHook.y - kandil.height, 0)
        XCTAssertGreaterThanOrEqual(stand.width * DiwaliArt.kandilHook.x - kandil.width / 2, 0)
        XCTAssertLessThanOrEqual(stand.width * DiwaliArt.kandilHook.x + kandil.width / 2, stand.width)
    }

    @MainActor func testDiwalisArtDraws() {
        for appearance in [Palette.Appearance.light, .dark] {
            let saved = Palette.appearance
            Palette.appearance = appearance
            ArtCache.clear()
            for kind in Settings.Theme.diwali.extras {
                XCTAssertGreaterThan(DiwaliArt.tile(kind, unit: 60, scale: 1).size().width, 0, "\(kind)")
                XCTAssertGreaterThan(ExtraArt.image(for: kind).size.width, 0, "\(kind)")
            }
            for kind in PumpkinKind.diwali {
                XCTAssertGreaterThan(DiwaliArt.litLamp(kind, height: 80, scale: 1).size().height,
                                     PumpkinArt.size(of: kind, height: 80).height, "\(kind) with room for its flames")
            }
            for variant in 0..<4 {
                XCTAssertGreaterThan(DiwaliArt.sweetTexture(variant: variant, size: 12, scale: 1).size().width, 0)
            }
            XCTAssertGreaterThan(DiwaliArt.garlandTexture(width: 600, height: 30, seed: 3, unit: 1.5, scale: 1).size().width, 0)
            XCTAssertGreaterThan(DiwaliArt.strandTexture(size: CGSize(width: 30, height: 60), scale: 1).size().width, 0)
            XCTAssertGreaterThan(DiwaliArt.peacockTexture(unit: 60, scale: 1).size().width, 0)
            XCTAssertGreaterThan(DiwaliArt.trainTexture(unit: 60, scale: 1).size().width, 0)
            XCTAssertGreaterThan(DiwaliArt.fanTexture(unit: 60, scale: 1).size().width, 0)
            XCTAssertGreaterThan(ExtraArt.diya().size.width, 0)
            XCTAssertGreaterThan(ExtraArt.peacock().size.width, ExtraArt.peacock().size.height, "the fanned tail is wider than tall")
            XCTAssertGreaterThan(ThemePreview.image(for: .diwali).size.width, 0)
            Palette.appearance = saved
        }
        ArtCache.clear()
    }
}
