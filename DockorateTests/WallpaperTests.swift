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

    func testHalloweenPictureIsAHauntedHillUnderABigMoon() throws {
        for appearance in [Palette.Appearance.light, .dark] {
            let look = WallpaperArt.look(for: .halloween, appearance)
            let spooky = try XCTUnwrap(look.spooky, "Halloween has its own scene")
            let image = try XCTUnwrap(WallpaperArt.image(look, pixels: CGSize(width: 1600, height: 1000)))
            // Places worked out from where the scene puts things on a 1600 by 1000 picture.
            XCTAssertColor(color(in: image, x: 0.015, y: 0.004), look.skyTop.rgb255, tolerance: 4, "sky at the top")
            XCTAssertColor(color(in: image, x: 0.69, y: 0.565), look.orb.rgb255, tolerance: 2, "the middle of the big moon")
            XCTAssertColor(color(in: image, x: 0.705, y: 0.439), look.frontHill.rgb255, tolerance: 8, "a bat across the moon")
            XCTAssertColor(color(in: image, x: 0.176, y: 0.619), spooky.light.rgb255, tolerance: 3, "a lit window in the haunted house")
            XCTAssertColor(color(in: image, x: 0.05, y: 0.8566), CGColor.hex(0xE0701E).rgb255, tolerance: 3, "a jack-o'-lantern")
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

    func testHalloweenLooksNothingLikeFall() throws {
        let size = CGSize(width: 400, height: 250)
        for appearance in [Palette.Appearance.light, .dark] {
            let fallLook = WallpaperArt.look(for: .fall, appearance), halloweenLook = WallpaperArt.look(for: .halloween, appearance)
            let fall = pixels(of: try XCTUnwrap(WallpaperArt.image(fallLook, pixels: size)))
            let halloween = pixels(of: try XCTUnwrap(WallpaperArt.image(halloweenLook, pixels: size)))
            // How much of each picture is its sun or moon: Halloween's moon is many times bigger.
            func orbShare(_ bytes: [UInt8], _ orb: [Int]) -> Int {
                stride(from: 0, to: bytes.count, by: 4).filter { i in (0..<3).allSatisfy { abs(Int(bytes[i + $0]) - orb[$0]) <= 3 } }.count
            }
            let fallSun = orbShare(fall, fallLook.orb.rgb255), bigMoon = orbShare(halloween, halloweenLook.orb.rgb255)
            XCTAssertGreaterThan(bigMoon, max(fallSun, 1) * 10, "\(appearance): \(bigMoon) moon pixels against \(fallSun)")
            // And most of the picture is a different color.
            let different = stride(from: 0, to: fall.count, by: 4).filter { i in (0..<3).contains { abs(Int(fall[i + $0]) - Int(halloween[i + $0])) > 24 } }.count
            XCTAssertGreaterThan(Double(different) / Double(fall.count / 4), 0.35, "\(appearance)")
        }
    }

    func testEachThemeGetsItsOwnFiles() {
        let pixels = CGSize(width: 320, height: 200)
        XCTAssertNotEqual(WallpaperArt.file(for: .fall, .dark, pixels: pixels), WallpaperArt.file(for: .halloween, .dark, pixels: pixels))
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
