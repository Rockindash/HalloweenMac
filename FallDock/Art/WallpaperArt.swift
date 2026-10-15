import AppKit
import ImageIO
import UniformTypeIdentifiers

// The desktop pictures that go with each theme, drawn in code like the rest of the art: a soft sky,
// a sun or moon with a glow, and two rolling hills along the bottom. Every theme has a light and a
// dark picture, to go with a light or dark Dock. They're drawn at each display's exact size, so they
// stay sharp on any screen.

enum WallpaperArt {
    /// The colors of one picture.
    struct Look {
        var skyTop: CGColor
        var skyBottom: CGColor
        var orb: CGColor
        /// The haze around the sun or moon, fading out to nothing.
        var glow: CGColor
        var backHill: CGColor
        var frontHill: CGColor
        /// Halloween's touches: a bare tree, tombstones along the hill and bats by the moon.
        var spooky = false
    }

    /// Bump this when the pictures change, so Macs that already have the old files draw them again.
    static let version = 1

    static func look(for theme: Settings.Theme, _ appearance: Palette.Appearance) -> Look {
        switch (theme, appearance) {
        case (.fall, .light):
            // A hazy autumn afternoon: cream sky warming to peach, a pale sun, wheat and sage hills.
            return Look(skyTop: .hex(0xF5E9D9), skyBottom: .hex(0xEED4B5), orb: .hex(0xFDF6E7),
                        glow: .hex(0xFFFAF0, alpha: 0.55), backHill: .hex(0xE6D9BE), frontHill: .hex(0xD7D6B3))
        case (.fall, .dark):
            // Night: indigo sky warming to plum at the horizon, a harvest moon, dark plum hills.
            return Look(skyTop: .hex(0x17152B), skyBottom: .hex(0x342236), orb: .hex(0xD4CBB4),
                        glow: .hex(0xD4CBB4, alpha: 0.13), backHill: .hex(0x2F1E2F), frontHill: .hex(0x271A2A))
        case (.halloween, .light):
            // Dusk on Halloween: lavender sky glowing pumpkin orange at the horizon, a low sun, purple hills.
            return Look(skyTop: .hex(0x8F7BB0), skyBottom: .hex(0xF4B67E), orb: .hex(0xFFE0AE),
                        glow: .hex(0xFFE2B8, alpha: 0.5), backHill: .hex(0x7E6A99), frontHill: .hex(0x5E4C78), spooky: true)
        case (.halloween, .dark):
            // Halloween night: a deep purple sky, a big bright moon, nearly black hills.
            return Look(skyTop: .hex(0x16112A), skyBottom: .hex(0x3D2148), orb: .hex(0xF2E6C8),
                        glow: .hex(0xF2E6C8, alpha: 0.18), backHill: .hex(0x221730), frontHill: .hex(0x150E1E), spooky: true)
        }
    }

    // Where things sit, as fractions of the picture: x from the left, y from the top.
    private static let orbCenter = CGPoint(x: 0.78, y: 0.205)
    /// The sun or moon's diameter, as a fraction of the picture's width.
    private static let orbSize: CGFloat = 0.05
    private static let glowSize: CGFloat = 0.14
    /// The top edge of each hill, at every tenth of the way across.
    private static let backHill = ridge([0.777, 0.768, 0.774, 0.786, 0.794, 0.795, 0.796, 0.806, 0.826, 0.848, 0.86])
    private static let frontHill = ridge([0.855, 0.862, 0.865, 0.867, 0.875, 0.89, 0.906, 0.911, 0.9, 0.88, 0.861])

    private static func ridge(_ heights: [CGFloat]) -> [CGPoint] {
        heights.enumerated().map { CGPoint(x: CGFloat($0.offset) / CGFloat(heights.count - 1), y: $0.element) }
    }

    /// The picture at `pixels` pixels.
    static func image(_ look: Look, pixels: CGSize) -> CGImage? {
        let width = max(1, Int(pixels.width.rounded()))
        let height = max(1, Int(pixels.height.rounded()))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        draw(look, in: ctx, size: CGSize(width: width, height: height))
        return ctx.makeImage()
    }

    /// Draws the picture filling `size`, in a context with a bottom-left origin.
    static func draw(_ look: Look, in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        // From fractions (y from the top) to the context's points (y from the bottom).
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * w, y: (1 - p.y) * h) }
        ctx.setShouldAntialias(true)

        // Sky.
        if let sky = CGGradient(colorsSpace: nil, colors: [look.skyTop, look.skyBottom] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: h * 0.12), options: [.drawsAfterEndLocation])
        }

        // Glow, then the sun or moon.
        let center = point(orbCenter)
        if let glow = CGGradient(colorsSpace: nil, colors: [look.glow, look.glow.withAlpha(0)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * glowSize, options: [])
        }
        let r = w * orbSize / 2
        ctx.setFillColor(look.orb)
        ctx.fillEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

        if look.spooky {
            drawBats(in: ctx, size: size, color: look.frontHill)
            drawTree(in: ctx, size: size, color: look.frontHill)
        }

        // Hills, back then front.
        for (line, color) in [(backHill, look.backHill), (frontHill, look.frontHill)] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            addSmoothLine(through: line.map(point), to: path)
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()
            ctx.setFillColor(color)
            ctx.addPath(path)
            ctx.fillPath()
        }

        if look.spooky {
            drawTombstones(in: ctx, size: size, color: look.frontHill)
        }
    }

    /// The top of a hill at `x` (a fraction across), as a fraction from the top.
    private static func height(of line: [CGPoint], at x: CGFloat) -> CGFloat {
        guard let after = line.firstIndex(where: { $0.x >= x }), after > 0 else { return line.first?.y ?? 1 }
        let a = line[after - 1], b = line[after]
        return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
    }

    /// A few tombstones standing on the front hill.
    private static func drawTombstones(in ctx: CGContext, size: CGSize, color: CGColor) {
        let w = size.width, h = size.height
        ctx.setFillColor(color)
        for (x, scale, tilt) in [(0.11, 1.0, -0.06), (0.155, 0.75, 0.04), (0.6, 0.9, 0.05), (0.66, 0.7, -0.08), (0.88, 0.85, 0.03)] as [(CGFloat, CGFloat, CGFloat)] {
            let stoneW = w * 0.012 * scale, stoneH = w * 0.019 * scale
            // Sunk a little into the hill, at the hill's height there.
            let base = (1 - height(of: frontHill, at: x)) * h - stoneH * 0.25
            ctx.saveGState()
            ctx.translateBy(x: x * w, y: base)
            ctx.rotate(by: tilt)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -stoneW / 2, y: 0))
            path.addLine(to: CGPoint(x: -stoneW / 2, y: stoneH - stoneW / 2))
            path.addArc(center: CGPoint(x: 0, y: stoneH - stoneW / 2), radius: stoneW / 2, startAngle: .pi, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: stoneW / 2, y: 0))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    /// A bare, crooked tree on the back hill.
    private static func drawTree(in ctx: CGContext, size: CGSize, color: CGColor) {
        let w = size.width, h = size.height
        let x: CGFloat = 0.27
        let foot = CGPoint(x: x * w, y: (1 - height(of: backHill, at: x)) * h - w * 0.004)
        let unit = w * 0.001
        ctx.setStrokeColor(color)
        ctx.setLineCap(.round)
        func branch(from start: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, depth: Int) {
            guard depth > 0 else { return }
            let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            ctx.setLineWidth(width)
            ctx.move(to: start)
            ctx.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + length * 0.12, y: (start.y + end.y) / 2))
            ctx.strokePath()
            branch(from: end, angle: angle + 0.5, length: length * 0.68, width: width * 0.62, depth: depth - 1)
            branch(from: end, angle: angle - 0.42, length: length * 0.6, width: width * 0.58, depth: depth - 1)
        }
        branch(from: foot, angle: .pi / 2 + 0.06, length: 46 * unit, width: 9 * unit, depth: 5)
    }

    /// Three bats flying past the moon, one right across it.
    private static func drawBats(in ctx: CGContext, size: CGSize, color: CGColor) {
        let w = size.width, h = size.height
        ctx.setFillColor(color)
        for (x, y, span) in [(0.772, 0.212, 0.022), (0.715, 0.14, 0.016), (0.84, 0.27, 0.013)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = CGPoint(x: x * w, y: (1 - y) * h), s = span * w
            let path = CGMutablePath()
            path.move(to: c)
            // Each wing: a sweep up to its tip, then scalloped back to the body.
            for side: CGFloat in [-1, 1] {
                path.move(to: c)
                path.addQuadCurve(to: CGPoint(x: c.x + side * s / 2, y: c.y + s * 0.18), control: CGPoint(x: c.x + side * s * 0.22, y: c.y + s * 0.3))
                path.addQuadCurve(to: CGPoint(x: c.x + side * s * 0.3, y: c.y + s * 0.02), control: CGPoint(x: c.x + side * s * 0.42, y: c.y))
                path.addQuadCurve(to: CGPoint(x: c.x + side * s * 0.12, y: c.y), control: CGPoint(x: c.x + side * s * 0.2, y: c.y + s * 0.08))
                path.closeSubpath()
            }
            ctx.addPath(path)
            ctx.fillPath()
            ctx.fillEllipse(in: CGRect(x: c.x - s * 0.06, y: c.y - s * 0.06, width: s * 0.12, height: s * 0.16))
        }
    }

    /// A smooth curve through every point (Catmull-Rom, as Bézier curves), starting with a line to the first.
    private static func addSmoothLine(through points: [CGPoint], to path: CGMutablePath) {
        guard let first = points.first else { return }
        path.addLine(to: first)
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)], p1 = points[i], p2 = points[i + 1], p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
    }

    // MARK: Files

    /// Where the pictures are saved. The desktop shows them from here. (Tests point it somewhere else.)
    static var directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Dockorate/Wallpapers", isDirectory: true)

    /// Whether `url` is one of Dockorate's pictures (rather than the person's own).
    static func isOurs(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/")
    }

    /// The file for this theme's picture at `pixels`, drawing and saving it first if it isn't there yet.
    /// Slow the first time for a big display, so it's best called off the main thread.
    static func file(for theme: Settings.Theme, _ appearance: Palette.Appearance, pixels: CGSize) -> URL? {
        let name = "\(theme.rawValue)-\(appearance == .dark ? "dark" : "light")-v\(version)-\(Int(pixels.width))x\(Int(pixels.height)).png"
        let url = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let picture = image(look(for: theme, appearance), pixels: pixels) else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Written next to the final name, then moved, so the desktop never sees half a file.
            let temporary = directory.appendingPathComponent(".\(UUID().uuidString).png")
            guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, UTType.png.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, picture, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: Previews

    private static var previews: [String: NSImage] = [:]

    /// A small picture for the Background page.
    static func preview(for theme: Settings.Theme, _ appearance: Palette.Appearance) -> NSImage {
        let key = "\(theme.rawValue)-\(appearance)"
        if let cached = previews[key] { return cached }
        let size = CGSize(width: 320, height: 200)
        let preview = image(look(for: theme, appearance), pixels: CGSize(width: size.width * 2, height: size.height * 2))
            .map { NSImage(cgImage: $0, size: size) } ?? NSImage(size: size)
        previews[key] = preview
        return preview
    }
}
