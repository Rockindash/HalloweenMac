import Metal
import SpriteKit
import XCTest
@testable import Dockorate

/// Not a check: draws the art into pictures to look at, for reviewing a theme without running the app.
/// It only draws when the DOCKORATE_PREVIEWS environment variable names a folder to put them in (the
/// Tests workflow's previews job sets it when the workflow is run by hand); otherwise it does nothing.
final class ArtPreviews: SettingsTestCase {
    private var folder: URL!

    @MainActor func testDrawPreviews() throws {
        guard let path = ProcessInfo.processInfo.environment["DOCKORATE_PREVIEWS"], !path.isEmpty else { return }
        folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let saved = Palette.appearance
        defer {
            Palette.appearance = saved
            ArtCache.clear()
        }
        for appearance in [Palette.Appearance.dark, .light] {
            Palette.appearance = appearance
            ArtCache.clear()
            let look = appearance == .dark ? "dark" : "light"
            for theme in Settings.Theme.allCases {
                Settings.themeChoice = .keep(theme)
                if let dock = dockPicture(theme, appearance) { save(dock, "dock-\(theme.rawValue)-\(look)") }
            }
            save(diwaliSheet(appearance), "diwali-art-\(look)")
            save(themeCards(appearance), "theme-cards-\(look)")
            save(menuBarIcons(appearance), "menu-bar-\(look)")
            for theme in Settings.Theme.allCases {
                if let picture = WallpaperArt.image(WallpaperArt.look(for: theme, appearance), pixels: CGSize(width: 1440, height: 900)) {
                    save(picture, "background-\(theme.rawValue)-\(look)")
                }
            }
        }
    }

    // MARK: Pictures

    private func save(_ image: CGImage, _ name: String) {
        let url = folder.appendingPathComponent(name + ".png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private func canvas(_ size: CGSize, scale: CGFloat = 2, draw: (CGContext) -> Void) -> CGImage {
        TextureMaker.make(size: size, scale: scale, draw: draw).cgImage()
    }

    /// The theme's sky, top to bottom, from its desktop picture.
    private func sky(_ ctx: CGContext, _ theme: Settings.Theme, _ appearance: Palette.Appearance, size: CGSize) {
        let look = WallpaperArt.look(for: theme, appearance)
        let middle = look.festive?.skyMiddle ?? look.spooky?.skyMiddle ?? look.skyTop.mixed(with: look.skyBottom, 0.5)
        if let gradient = CGGradient(colorsSpace: nil, colors: [look.skyTop, middle, look.skyBottom] as CFArray, locations: [0, 0.6, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: .zero, options: [])
        }
    }

    /// A pretend Dock with stand-in icons, and the real harvest on it, drawn by SpriteKit (needs Metal).
    @MainActor private func dockPicture(_ theme: Settings.Theme, _ appearance: Palette.Appearance) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        let size = CGSize(width: 1400, height: 300), scale: CGFloat = 2
        let dock = CGRect(x: 40, y: 10, width: 1320, height: 70)
        let scene = PumpkinScene(size: size)
        scene.configure(dockRect: dock, pixelScale: scale, magnifier: DockMagnifier(), regrow: true)
        if theme == .diwali { showOff(scene, dock: dock) }
        scene.update(1)
        scene.scaleMode = .fill

        let width = Int(size.width * scale), height = Int(size.height * scale)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        guard let texture = device.makeTexture(descriptor: descriptor), let buffer = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        renderer.render(withViewport: CGRect(x: 0, y: 0, width: width, height: height), commandBuffer: buffer, renderPassDescriptor: pass)
        if texture.storageMode == .managed, let blit = buffer.makeBlitCommandEncoder() {
            blit.synchronize(resource: texture)
            blit.endEncoding()
        }
        buffer.commit()
        buffer.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&bytes, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let harvest = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }

        return canvas(size, scale: scale) { ctx in
            sky(ctx, theme, appearance, size: size)
            // The Dock's frosted glass, and its icons.
            let glass = CGPath(roundedRect: dock, cornerWidth: 18, cornerHeight: 18, transform: nil)
            ctx.addPath(glass)
            ctx.setFillColor(appearance == .dark ? CGColor.hex(0x1E1E24, alpha: 0.55) : CGColor.hex(0xFFFFFF, alpha: 0.45))
            ctx.fillPath()
            let icons: [CGColor] = [.hex(0x3A86FF), .hex(0x8E8E93), .hex(0x34C759), .hex(0xFF9500), .hex(0xAF52DE), .hex(0xFF3B30),
                                    .hex(0x5AC8FA), .hex(0xFFCC00)]
            var x = dock.minX + 12
            var i = 0
            while x + 52 < dock.maxX - 8 {
                let icon = CGPath(roundedRect: CGRect(x: x, y: dock.minY + 9, width: 52, height: 52), cornerWidth: 12, cornerHeight: 12, transform: nil)
                ctx.addPath(icon)
                ctx.setFillColor(icons[i % icons.count].withAlpha(0.85))
                ctx.fillPath()
                x += 62
                i += 1
            }
            ctx.draw(harvest, in: CGRect(origin: .zero, size: size))
        }
    }

    /// At Diwali: the peacock with its tail fanned out, and a firework frozen mid-burst.
    @MainActor private func showOff(_ scene: PumpkinScene, dock: CGRect) {
        scene.peacockVisit()
        if let peacock = scene.pumpkinLayer.children.compactMap({ $0 as? PeacockNode }).first {
            peacock.removeAllActions()
            peacock.alpha = 1
            peacock.facing = 1
            peacock.restX = dock.minX + dock.width * 0.58
            peacock.isDisplaying = true
            peacock.childNode(withName: "train")?.alpha = 0
            if let fan = peacock.childNode(withName: "fan") {
                fan.alpha = 1
                fan.setScale(1)
            }
        }
        let radius = scene.pumpkinHeight * 0.5
        scene.fireworkBurst(at: CGPoint(x: dock.minX + dock.width * 0.3, y: dock.maxY + scene.pumpkinHeight * 1.7), radius: radius,
                            colors: [Palette.magenta, Palette.marigold])
        scene.fireworkBurst(at: CGPoint(x: dock.minX + dock.width * 0.82, y: dock.maxY + scene.pumpkinHeight * 1.9), radius: radius * 0.8,
                            colors: [Palette.teal, Palette.candlelight])
        for case let node as SKSpriteNode in scene.effectsLayer.children {
            node.removeAllActions()
            if node.anchorPoint.x == 1 {
                // A streak, flown out to the edge of the burst.
                node.setScale(1)
                node.position = CGPoint(x: node.position.x + cos(node.zRotation) * radius * 0.95,
                                        y: node.position.y + sin(node.zRotation) * radius * 0.95)
            } else if node.name == "firework" {
                node.setScale(1)
                node.alpha = 0.5
            } else {
                node.alpha = 1
            }
        }
    }

    /// Every piece of Diwali's art on its own: the lamps lit, the extras, the peacock walking and showing off,
    /// the sweets that fly, fireworks, the garland and a string of marigolds.
    private func diwaliSheet(_ appearance: Palette.Appearance) -> CGImage {
        let size = CGSize(width: 1240, height: 620)
        return canvas(size) { ctx in
            ctx.setFillColor(appearance == .dark ? CGColor.hex(0x1F1A2E) : CGColor.hex(0xF6EEE4))
            ctx.fill(CGRect(origin: .zero, size: size))
            func draw(_ texture: SKTexture, _ rect: CGRect) { ctx.draw(texture.cgImage(), in: rect) }

            // The lamps, lit.
            var x: CGFloat = 40
            for kind in [PumpkinKind.diyaClay, .diyaPink, .diyaTeal, .diyaBrass, .diyaLotus, .lampStand] {
                let height: CGFloat = 130
                let s = DiwaliArt.litLampSize(kind, height: height)
                draw(DiwaliArt.litLamp(kind, height: height, scale: 2), CGRect(x: x, y: 450, width: s.width, height: s.height))
                x += s.width + 40
            }
            // The peacock walking, and showing off.
            let unit: CGFloat = 110
            let body = DiwaliArt.peacockSize(unit: unit), fan = DiwaliArt.fanSize(unit: unit)
            draw(DiwaliArt.trainTexture(unit: unit, scale: 2), CGRect(x: x, y: 450, width: body.width, height: body.height))
            draw(DiwaliArt.peacockTexture(unit: unit, scale: 2), CGRect(x: x, y: 450, width: body.width, height: body.height))
            let shown = CGPoint(x: x + body.width + 60, y: 430)
            let rump = CGPoint(x: shown.x + DiwaliArt.peacockRump.x * body.width, y: shown.y + DiwaliArt.peacockRump.y * body.height)
            draw(DiwaliArt.fanTexture(unit: unit, scale: 2),
                 CGRect(x: rump.x - fan.width / 2, y: rump.y - fan.height * DiwaliArt.fanPivot, width: fan.width, height: fan.height))
            draw(DiwaliArt.peacockTexture(unit: unit, scale: 2), CGRect(origin: shown, size: body))

            // The extras, with their moving parts.
            x = 40
            let decorUnit: CGFloat = 100
            for kind in Settings.Theme.diwali.extras {
                let s = CozyArt.size(of: kind, unit: decorUnit)
                draw(DiwaliArt.tile(kind, unit: decorUnit, scale: 2), CGRect(x: x, y: 250, width: s.width, height: s.height))
                x += s.width + 22
            }

            // The sweets that fly, a few fireworks, the garland and a string of marigolds.
            x = 40
            for variant in 0..<4 {
                draw(DiwaliArt.sweetTexture(variant: variant, size: 44, scale: 2), CGRect(x: x, y: 160, width: 44, height: 44))
                x += 64
            }
            for (i, colors) in [[Palette.magenta, Palette.marigold], [Palette.teal, Palette.candlelight], [Palette.marigold, Palette.candyPink, Palette.slime]].enumerated() {
                DiwaliArt.drawFirework(ctx, center: CGPoint(x: 400 + CGFloat(i) * 120, y: 180), radius: 50, colors: colors, seed: i + 1)
            }
            draw(DiwaliArt.garlandTexture(width: 900, height: 40, seed: 3, unit: 1.6, scale: 2), CGRect(x: 40, y: 40, width: 900, height: 40))
            let strand = CGSize(width: 60, height: 110)
            draw(DiwaliArt.strandTexture(size: strand, scale: 2), CGRect(origin: CGPoint(x: 1000, y: 30), size: strand))
            for (i, color) in [Palette.marigold, Palette.magenta, Palette.teal].enumerated() {
                draw(DiwaliArt.petalTexture(color: color, size: 30, scale: 2), CGRect(x: 1100, y: 40 + CGFloat(i) * 40, width: 30, height: 30))
                draw(DiwaliArt.sparkTexture(color: color, size: 16, scale: 2), CGRect(x: 1150, y: 47 + CGFloat(i) * 40, width: 16, height: 16))
            }
        }
    }

    /// Every theme's card on the Themes page.
    /// Each theme's menu bar icon on a menu bar of this look, four times as big and at its real size,
    /// colored the way macOS colors a template image.
    @MainActor private func menuBarIcons(_ appearance: Palette.Appearance) -> CGImage {
        let themes = Settings.Theme.allCases
        let size = CGSize(width: 140 * CGFloat(themes.count) + 20, height: 150)
        let ink = appearance == .dark ? CGColor.white : CGColor.black
        return canvas(size) { ctx in
            ctx.setFillColor(appearance == .dark ? CGColor.hex(0x2B2A33) : CGColor.hex(0xE8E6EA))
            ctx.fill(CGRect(origin: .zero, size: size))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            for (i, theme) in themes.enumerated() {
                let x = 20 + CGFloat(i) * 140
                for rect in [CGRect(x: x + 10, y: 50, width: 80, height: 72), CGRect(x: x + 40, y: 14, width: 20, height: 18)] {
                    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                    ExtraArt.menuBarIcon(theme).draw(in: rect)
                    ctx.setBlendMode(.sourceIn)
                    ctx.setFillColor(ink)
                    ctx.fill(rect)
                    ctx.endTransparencyLayer()
                    ctx.setBlendMode(.normal)
                }
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func themeCards(_ appearance: Palette.Appearance) -> CGImage {
        let card = CGSize(width: 520, height: 170)
        let size = CGSize(width: card.width + 40, height: (card.height + 20) * CGFloat(Settings.Theme.allCases.count) + 20)
        return canvas(size) { ctx in
            ctx.setFillColor(appearance == .dark ? CGColor.hex(0x26232E) : CGColor.hex(0xEFEAE4))
            ctx.fill(CGRect(origin: .zero, size: size))
            for (i, theme) in Settings.Theme.allCases.enumerated() {
                let rect = CGRect(x: 20, y: size.height - CGFloat(i + 1) * (card.height + 20), width: card.width, height: card.height)
                ctx.saveGState()
                ctx.clip(to: rect)
                ctx.translateBy(x: rect.minX, y: rect.minY)
                sky(ctx, theme, appearance, size: card)
                ctx.restoreGState()
                if let image = ThemePreview.image(for: theme).cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    ctx.draw(image, in: rect)
                }
            }
        }
    }
}
