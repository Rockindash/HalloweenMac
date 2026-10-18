import ImageIO
import XCTest
@testable import Dockorate

/// The Background page's desktop pictures: what they look like, where they're saved, and which one shows.
final class WallpaperTests: SettingsTestCase {
    private var realDirectory: URL!
    private var temporary: URL!
    private var savedAppearance = Palette.Appearance.dark

    override func setUp() {
        super.setUp()
        savedAppearance = Palette.appearance
        realDirectory = WallpaperArt.directory
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent("DockorateTests-\(UUID().uuidString)/Wallpapers")
        WallpaperArt.directory = temporary
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporary.deletingLastPathComponent())
        WallpaperArt.directory = realDirectory
        Palette.appearance = savedAppearance
        super.tearDown()
    }

    /// The color of the pixel `x` and `y` of the way across and down (from the top) the picture.
    private func color(in image: CGImage, x: CGFloat, y: CGFloat) -> [Int] {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let px = (x * CGFloat(image.width)).rounded(.down), py = (y * CGFloat(image.height)).rounded(.down)
        // Shift the picture so the wanted pixel lands on the 1×1 canvas (which has a bottom-left origin).
        context.draw(image, in: CGRect(x: -px, y: -(CGFloat(image.height) - 1 - py), width: CGFloat(image.width), height: CGFloat(image.height)))
        return pixel.prefix(3).map(Int.init)
    }

    func testEveryThemeHasALightAndADarkPicture() {
        for theme in Settings.Theme.allCases {
            let light = WallpaperArt.look(for: theme, .light), dark = WallpaperArt.look(for: theme, .dark)
            XCTAssertNotEqual(light.skyTop.rgb255, dark.skyTop.rgb255, "\(theme)")
            XCTAssertNotEqual(light.frontHill.rgb255, dark.frontHill.rgb255, "\(theme)")
        }
    }

    func testPictureIsDrawnAtTheDisplaysSize() {
        let image = try! XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: .fall, .light), pixels: CGSize(width: 3024, height: 1964)))
        XCTAssertEqual(image.width, 3024)
        XCTAssertEqual(image.height, 1964)
    }

    func testPictureHasSkySunAndHills() {
        for appearance in [Palette.Appearance.light, .dark] {
            let look = WallpaperArt.look(for: .fall, appearance)
            let image = try! XCTUnwrap(WallpaperArt.image(look, pixels: CGSize(width: 1600, height: 1000)))
            XCTAssertColor(color(in: image, x: 0.02, y: 0.01), look.skyTop.rgb255, tolerance: 4, "sky at the top")
            XCTAssertColor(color(in: image, x: 0.78, y: 0.205), look.orb.rgb255, tolerance: 2, "sun or moon")
            XCTAssertColor(color(in: image, x: 0.5, y: 0.84), look.backHill.rgb255, tolerance: 2, "back hill")
            XCTAssertColor(color(in: image, x: 0.5, y: 0.98), look.frontHill.rgb255, tolerance: 2, "front hill")
        }
    }

    func testHalloweenPictureIsAHauntedHillAndAGraveyard() throws {
        for appearance in [Palette.Appearance.light, .dark] {
            let look = WallpaperArt.look(for: .halloween, appearance)
            let spooky = try XCTUnwrap(look.spooky, "Halloween has its own scene")
            let image = try XCTUnwrap(WallpaperArt.image(look, pixels: CGSize(width: 1600, height: 1000)))
            // Places worked out from where the scene puts things on a 1600 by 1000 picture.
            XCTAssertColor(color(in: image, x: 0.015, y: 0.004), look.skyTop.rgb255, tolerance: 4, "sky at the top")
            XCTAssertColor(color(in: image, x: 0.78, y: 0.205), look.orb.rgb255, tolerance: 2, "the middle of the moon")
            XCTAssertColor(color(in: image, x: 0.772, y: 0.2115), look.frontHill.rgb255, tolerance: 8, "a bat across the moon")
            XCTAssertColor(color(in: image, x: 0.176, y: 0.619), spooky.light.rgb255, tolerance: 3, "a lit window in the haunted house")
            XCTAssertColor(color(in: image, x: 0.5, y: 0.79), look.backHill.rgb255, tolerance: 2, "the haunted hill")
            XCTAssertColor(color(in: image, x: 0.5, y: 0.98), look.frontHill.rgb255, tolerance: 2, "the graveyard hill")
        }
        XCTAssertNil(WallpaperArt.look(for: .fall, .light).spooky, "Fall's pictures stay as they were")
        XCTAssertNil(WallpaperArt.look(for: .fall, .dark).spooky)
    }

    /// Every pixel of a picture, as RGBA bytes, rows from the top.
    private func pixels(of image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    /// How many pixels are within `tolerance` of `color`.
    private func count(_ color: [Int], in bytes: [UInt8], tolerance: Int = 3) -> Int {
        stride(from: 0, to: bytes.count, by: 4).filter { i in (0..<3).allSatisfy { abs(Int(bytes[i + $0]) - color[$0]) <= tolerance } }.count
    }

    func testHalloweenLooksNothingLikeFall() throws {
        let size = CGSize(width: 400, height: 250)
        for appearance in [Palette.Appearance.light, .dark] {
            let fall = pixels(of: try XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: .fall, appearance), pixels: size)))
            let halloween = pixels(of: try XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: .halloween, appearance), pixels: size)))
            // A good part of the picture is a different color: its own sky, the house, the graveyard.
            let different = stride(from: 0, to: fall.count, by: 4).filter { i in (0..<3).contains { abs(Int(fall[i + $0]) - Int(halloween[i + $0])) > 24 } }.count
            XCTAssertGreaterThan(Double(different) / Double(fall.count / 4), 0.25, "\(appearance)")
        }
    }

    func testDiwalisPictureIsATownFullOfLights() throws {
        for appearance in [Palette.Appearance.light, .dark] {
            let look = WallpaperArt.look(for: .diwali, appearance)
            let festive = try XCTUnwrap(look.festive, "Diwali has its own scene")
            XCTAssertNil(look.spooky)
            let image = try XCTUnwrap(WallpaperArt.image(look, pixels: CGSize(width: 1600, height: 1000)))
            // Places worked out from where the scene puts things on a 1600 by 1000 picture.
            XCTAssertColor(color(in: image, x: 0.015, y: 0.004), look.skyTop.rgb255, tolerance: 4, "sky at the top")
            XCTAssertColor(color(in: image, x: 0.78, y: 0.205), look.orb.rgb255, tolerance: 2, "the sun or moon")
            XCTAssertColor(color(in: image, x: 0.34, y: 0.70), look.backHill.rgb255, tolerance: 2, "the temple's spire")
            XCTAssertColor(color(in: image, x: 0.5, y: 0.98), look.frontHill.rgb255, tolerance: 2, "the ground in front")
            XCTAssertGreaterThan(count(festive.light.rgb255, in: pixels(of: image)), 500, "\(appearance): lit windows")
        }
        XCTAssertNil(WallpaperArt.look(for: .fall, .dark).festive, "Fall's pictures stay as they were")
        XCTAssertNil(WallpaperArt.look(for: .halloween, .dark).festive)
    }

    /// Diwali's picture stays minimal: no row of diyas along the ground, no strings of lights between the
    /// roofs, and nothing bursting around the sun or moon.
    func testDiwalisPictureHasNoDiyasOrStringsOfLights() throws {
        let size = CGSize(width: 1600, height: 1000)
        let width = Int(size.width)
        for appearance in [Palette.Appearance.light, .dark] {
            let look = WallpaperArt.look(for: .diwali, appearance)
            let festive = try XCTUnwrap(look.festive)
            let bytes = pixels(of: try XCTUnwrap(WallpaperArt.image(look, pixels: size)))
            // Just above the ground and below every window there's only rooftops, sky between them, and the
            // temple's lit doorway. A diya's bowl, flame or glow would show here.
            let row = Int((WallpaperArt.groundTop - 0.004) * size.height)
            let door = Int((WallpaperArt.templeX - 0.012) * size.width)...Int((WallpaperArt.templeX + 0.012) * size.width)
            let expected = [look.backHill.rgb255, look.skyBottom.rgb255, festive.light.rgb255]
            let stray = (0..<width).filter { x in
                guard !door.contains(x) else { return false }
                let i = (row * width + x) * 4
                return !expected.contains { color in (0..<3).allSatisfy { abs(Int(bytes[i + $0]) - color[$0]) <= 6 } }
            }.count
            // A rooftop's edge can fall partway across a pixel.
            XCTAssertLessThan(stray, 80, "\(appearance): \(stray) pixels just above the ground aren't rooftop, sky or doorway")
            // The strings of lights and the burst around the moon were drawn in the fireworks' own colors; the
            // faint fireworks left are see-through, so they never match them.
            for spark in festive.sparks {
                XCTAssertLessThan(count(spark.rgb255, in: bytes, tolerance: 6), 20, "\(appearance): no lights in \(spark.rgb255)")
            }
        }
    }

    func testDiwaliLooksNothingLikeFallOrHalloween() throws {
        let size = CGSize(width: 400, height: 250)
        for appearance in [Palette.Appearance.light, .dark] {
            let diwali = pixels(of: try XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: .diwali, appearance), pixels: size)))
            for other in [Settings.Theme.fall, .halloween] {
                let picture = pixels(of: try XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: other, appearance), pixels: size)))
                let different = stride(from: 0, to: diwali.count, by: 4).filter { i in
                    (0..<3).contains { abs(Int(diwali[i + $0]) - Int(picture[i + $0])) > 24 }
                }.count
                XCTAssertGreaterThan(Double(different) / Double(diwali.count / 4), 0.25, "\(appearance) against \(other)")
            }
        }
    }

    /// The pictures stay in the background, so the Dock is the star: every theme's sun or moon is small and
    /// in the same spot as Fall's, and Halloween's has no glowing jack-o'-lanterns.
    func testEveryPictureKeepsItsSunOrMoonSmallAndInTheSameSpot() throws {
        let size = CGSize(width: 400, height: 250)
        for appearance in [Palette.Appearance.light, .dark] {
            let fallLook = WallpaperArt.look(for: .fall, appearance)
            let fallSun = count(fallLook.orb.rgb255, in: pixels(of: try XCTUnwrap(WallpaperArt.image(fallLook, pixels: size))))
            for theme in Settings.Theme.allCases {
                let look = WallpaperArt.look(for: theme, appearance)
                let image = try XCTUnwrap(WallpaperArt.image(look, pixels: size))
                XCTAssertColor(color(in: image, x: WallpaperArt.orbCenter.x, y: WallpaperArt.orbCenter.y), look.orb.rgb255, tolerance: 2,
                               "\(theme) \(appearance): the sun or moon is where Fall's is")
                // Its craters and a passing bat can cover a little of it, but it's no bigger.
                let orb = count(look.orb.rgb255, in: pixels(of: image))
                XCTAssertGreaterThan(orb, fallSun / 2, "\(theme) \(appearance)")
                XCTAssertLessThanOrEqual(orb, fallSun * 11 / 10, "\(theme) \(appearance): \(orb) pixels of sun or moon against Fall's \(fallSun)")
            }
            let halloween = pixels(of: try XCTUnwrap(WallpaperArt.image(WallpaperArt.look(for: .halloween, appearance), pixels: size)))
            XCTAssertEqual(count(rgb255(0xE0701E), in: halloween, tolerance: 12), 0, "no jack-o'-lanterns in the \(appearance) picture")
        }
    }

    func testEachThemeGetsItsOwnFiles() {
        let pixels = CGSize(width: 320, height: 200)
        XCTAssertNotEqual(WallpaperArt.file(for: .fall, .dark, pixels: pixels), WallpaperArt.file(for: .halloween, .dark, pixels: pixels))
        let files = Settings.Theme.allCases.compactMap { WallpaperArt.file(for: $0, .dark, pixels: pixels) }
        XCTAssertEqual(Set(files).count, Settings.Theme.allCases.count, "Diwali too")
    }

    func testPictureIsSavedOnceAndReused() throws {
        let pixels = CGSize(width: 800, height: 500)
        let url = try XCTUnwrap(WallpaperArt.file(for: .fall, .dark, pixels: pixels))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(WallpaperArt.isOurs(url))

        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let saved = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(saved.width, 800)
        XCTAssertEqual(saved.height, 500)

        let written = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(WallpaperArt.file(for: .fall, .dark, pixels: pixels), url)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date, written,
                       "not drawn again")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: temporary.path).filter { $0.hasPrefix(".") }
        XCTAssertTrue(leftovers.isEmpty, "no half-written files left behind")
    }

    func testEachLookAndSizeGetsItsOwnFile() {
        let light = WallpaperArt.file(for: .fall, .light, pixels: CGSize(width: 400, height: 250))
        let dark = WallpaperArt.file(for: .fall, .dark, pixels: CGSize(width: 400, height: 250))
        let bigger = WallpaperArt.file(for: .fall, .dark, pixels: CGSize(width: 800, height: 500))
        XCTAssertEqual(Set([light, dark, bigger].compactMap { $0 }).count, 3)
    }

    func testOnlyDockoratesOwnPicturesCountAsOurs() {
        XCTAssertTrue(WallpaperArt.isOurs(temporary.appendingPathComponent("fall-light-v1-10x10.png")))
        XCTAssertFalse(WallpaperArt.isOurs(URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sonoma.heic")))
        XCTAssertFalse(WallpaperArt.isOurs(temporary.deletingLastPathComponent().appendingPathComponent("Wallpapers-old/x.png")))
        XCTAssertFalse(WallpaperArt.isOurs(nil))
    }

    func testPreviewsForTheBackgroundPage() {
        for appearance in [Palette.Appearance.light, .dark] {
            XCTAssertEqual(WallpaperArt.preview(for: .fall, appearance).size, CGSize(width: 320, height: 200))
        }
    }

    @MainActor func testMatchTheDockFollowsLightAndDark() {
        Settings.wallpaperMode = .matchDock
        Palette.appearance = .light
        XCTAssertEqual(WallpaperController.appearance, .light)
        Palette.appearance = .dark
        XCTAssertEqual(WallpaperController.appearance, .dark)
    }

    @MainActor func testAPickedPictureStaysWhateverTheDock() {
        Settings.wallpaperMode = .light
        Palette.appearance = .dark
        XCTAssertEqual(WallpaperController.appearance, .light)
        Settings.wallpaperMode = .dark
        Palette.appearance = .light
        XCTAssertEqual(WallpaperController.appearance, .dark)
    }
}
