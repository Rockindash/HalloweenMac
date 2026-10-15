import AppKit
import ImageIO
import UniformTypeIdentifiers

// The desktop pictures that go with each theme, drawn in code like the rest of the art. They stay
// minimal and quiet, so the Dock is the star: every theme has the same small sun or moon in the same
// spot, and nothing big or bright pulls the eye. Fall's is a soft sky and two rolling hills along the bottom.
// Halloween's is its own scene: a haunted house on a hill, a few bats by the moon, a gnarled tree and
// a graveyard. Every theme has a light and a dark picture, to go with a light or dark Dock. They're
// drawn at each display's exact size, so they stay sharp on any screen.

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
        /// Halloween's own scene, instead of the plain hills.
        var spooky: Spooky?
    }

    /// The extra colors of Halloween's scene.
    struct Spooky {
        /// The sky between the top and the horizon.
        var skyMiddle: CGColor
        /// The moon's craters.
        var moonShade: CGColor
        /// The haunted house's lit windows.
        var light: CGColor
        /// Fog lying in the valley (none at dusk).
        var mist: CGColor?
        var stars: Bool
    }

    /// Bump this when the pictures change, so Macs that already have the old files draw them again.
    static let version = 3

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
            // Halloween dusk: violet sky turning rose, then pumpkin orange at the horizon, a pale moon,
            // and everything on the hills in deep purple silhouette.
            return Look(skyTop: .hex(0x5E4389), skyBottom: .hex(0xF6A04D), orb: .hex(0xFFE9B8),
                        glow: .hex(0xFFD79A, alpha: 0.32), backHill: .hex(0x3C2552), frontHill: .hex(0x1E1229),
                        spooky: Spooky(skyMiddle: .hex(0xB4567E), moonShade: .hex(0xF7DDA8), light: .hex(0xFFC54A),
                                       mist: nil, stars: false))
        case (.halloween, .dark):
            // Halloween night: a starry sky going eerie green near the ground, a pale moon, black hills
            // and fog in the valley.
            return Look(skyTop: .hex(0x070B16), skyBottom: .hex(0x24443F), orb: .hex(0xEEF3DA),
                        glow: .hex(0xD8F0C8, alpha: 0.18), backHill: .hex(0x0F1A20), frontHill: .hex(0x05090C),
                        spooky: Spooky(skyMiddle: .hex(0x10202B), moonShade: .hex(0xDCE4C8), light: .hex(0xFFC23D),
                                       mist: .hex(0xBFE3D0, alpha: 0.16), stars: true))
        }
    }

    // Where things sit, as fractions of the picture: x from the left, y from the top. Every theme's sun
    // or moon is this size, in this spot.
    static let orbCenter = CGPoint(x: 0.78, y: 0.205)
    /// The sun or moon's diameter, as a fraction of the picture's width.
    static let orbSize: CGFloat = 0.05
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
        if let spooky = look.spooky {
            drawHalloween(look, spooky, in: ctx, size: size)
            return
        }
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
    }

    // MARK: Halloween

    // Where Halloween's things sit, as fractions of the picture: x from the left, y from the top.
    /// A tall hill on the left for the haunted house, and the graveyard hill in front.
    private static let hauntedHill = ridge([0.700, 0.652, 0.640, 0.656, 0.700, 0.752, 0.782, 0.790, 0.788, 0.794, 0.806])
    private static let graveyardHill = ridge([0.872, 0.868, 0.878, 0.893, 0.900, 0.896, 0.884, 0.872, 0.862, 0.858, 0.866])
    /// Where the house stands on its hill.
    private static let houseX: CGFloat = 0.2

    /// The top of a hill at `x` (a fraction across), as a fraction from the top.
    private static func height(of line: [CGPoint], at x: CGFloat) -> CGFloat {
        guard let after = line.firstIndex(where: { $0.x >= x }) else { return line.last?.y ?? 1 }
        guard after > 0 else { return line[0].y }
        let a = line[after - 1], b = line[after]
        return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
    }

    private static func drawHalloween(_ look: Look, _ spooky: Spooky, in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: (1 - y) * h) }
        ctx.setShouldAntialias(true)

        // Sky, in three colors from the top down to the horizon.
        if let sky = CGGradient(colorsSpace: nil, colors: [look.skyTop, spooky.skyMiddle, look.skyBottom] as CFArray, locations: [0, 0.55, 1]) {
            ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: h * 0.14),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        // Stars, scattered over the upper sky but not over the moon.
        if spooky.stars {
            for i in 0..<70 {
                let n = CGFloat(i)
                let x = (n * 0.618034 + 0.13).truncatingRemainder(dividingBy: 1)
                let y = (n * 0.7548777 + 0.31).truncatingRemainder(dividingBy: 1) * 0.55
                if hypot(x - orbCenter.x, (y - orbCenter.y) * h / w) < orbSize { continue }
                let r = w * 0.0007 * (0.6 + (n * 0.381966).truncatingRemainder(dividingBy: 1) * 1.1)
                ctx.setFillColor(CGColor.hex(0xFFFFFF, alpha: 0.35 + (n * 0.2357).truncatingRemainder(dividingBy: 1) * 0.45))
                let c = point(x, y)
                ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
        }

        // The moon, where Fall's sun is and just as big, with a soft glow and a few faint craters.
        let center = point(orbCenter.x, orbCenter.y)
        let radius = w * orbSize / 2
        if let glow = CGGradient(colorsSpace: nil, colors: [look.glow, look.glow.withAlpha(0)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: w * glowSize, options: [])
        }
        ctx.setFillColor(look.orb)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.setFillColor(spooky.moonShade)
        for (dx, dy, r) in [(-0.34, 0.24, 0.17), (0.2, 0.4, 0.1), (0.32, -0.18, 0.14), (-0.1, -0.4, 0.08)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: center.x + (dx - r) * radius, y: center.y + (dy - r) * radius, width: r * 2 * radius, height: r * 2 * radius))
        }

        drawBats(in: ctx, size: size, color: look.frontHill)

        // The haunted hill, with the house on top.
        fillHill(hauntedHill, color: look.backHill, in: ctx, size: size)
        drawHouse(in: ctx, size: size, color: look.backHill, light: spooky.light)

        // Fog lying in the valley.
        if let mist = spooky.mist,
           let fog = CGGradient(colorsSpace: nil, colors: [mist, mist.withAlpha(0)] as CFArray, locations: [0, 1]) {
            for (x, y, width, height) in [(0.35, 0.83, 0.5, 0.03), (0.75, 0.815, 0.45, 0.025), (0.15, 0.85, 0.4, 0.02)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                ctx.saveGState()
                let c = point(x, y)
                ctx.translateBy(x: c.x, y: c.y)
                ctx.scaleBy(x: width * w / 2, y: height * h / 2)
                ctx.drawRadialGradient(fog, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
                ctx.restoreGState()
            }
        }

        // The graveyard hill in front, with its tree, stones and fence.
        fillHill(graveyardHill, color: look.frontHill, in: ctx, size: size)
        drawTree(in: ctx, size: size, color: look.frontHill)
        drawGraveyard(in: ctx, size: size, color: look.frontHill)
    }

    private static func fillHill(_ line: [CGPoint], color: CGColor, in ctx: CGContext, size: CGSize) {
        let path = CGMutablePath()
        path.move(to: .zero)
        addSmoothLine(through: line.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }, to: path)
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.closeSubpath()
        ctx.setFillColor(color)
        ctx.addPath(path)
        ctx.fillPath()
    }

    /// A few small bats flying by the moon, one across it.
    private static func drawBats(in ctx: CGContext, size: CGSize, color: CGColor) {
        let w = size.width, h = size.height
        ctx.setFillColor(color)
        for (x, y, span) in [(0.772, 0.212, 0.014), (0.738, 0.168, 0.010), (0.818, 0.172, 0.008), (0.712, 0.232, 0.007),
                             (0.842, 0.236, 0.006)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = CGPoint(x: x * w, y: (1 - y) * h), s = span * w
            // Each piece is filled on its own: the two wings wind opposite ways, so filled together
            // with the body, the overlaps would cancel out and leave holes.
            for side: CGFloat in [-1, 1] {
                // A wing: a sweep up to its tip, then scalloped back to the body.
                let wing = CGMutablePath()
                wing.move(to: c)
                wing.addQuadCurve(to: CGPoint(x: c.x + side * s / 2, y: c.y + s * 0.18), control: CGPoint(x: c.x + side * s * 0.22, y: c.y + s * 0.3))
                wing.addQuadCurve(to: CGPoint(x: c.x + side * s * 0.3, y: c.y + s * 0.02), control: CGPoint(x: c.x + side * s * 0.42, y: c.y))
                wing.addQuadCurve(to: CGPoint(x: c.x + side * s * 0.12, y: c.y), control: CGPoint(x: c.x + side * s * 0.2, y: c.y + s * 0.08))
                wing.closeSubpath()
                ctx.addPath(wing)
                ctx.fillPath()
                // An ear.
                ctx.move(to: CGPoint(x: c.x + side * s * 0.02, y: c.y + s * 0.08))
                ctx.addLine(to: CGPoint(x: c.x + side * s * 0.05, y: c.y + s * 0.14))
                ctx.addLine(to: CGPoint(x: c.x + side * s * 0.065, y: c.y + s * 0.06))
                ctx.closePath()
                ctx.fillPath()
            }
            ctx.fillEllipse(in: CGRect(x: c.x - s * 0.07, y: c.y + s * 0.02 - s * 0.09, width: s * 0.14, height: s * 0.18))
        }
    }

    /// A crooked house with a tall tower and lit windows, on top of the hill.
    private static func drawHouse(in ctx: CGContext, size: CGSize, color: CGColor, light: CGColor) {
        let u = size.width * 0.001
        // The middle of its front, sunk a little into the hill.
        let base = CGPoint(x: houseX * size.width, y: (1 - height(of: hauntedHill, at: houseX)) * size.height - 4 * u)
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: base.x + x * u, y: base.y + y * u, width: width * u, height: height * u)
        }
        func fill(_ points: [(CGFloat, CGFloat)]) {
            let path = CGMutablePath()
            path.addLines(between: points.map { CGPoint(x: base.x + $0.0 * u, y: base.y + $0.1 * u) })
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }
        ctx.setFillColor(color)
        // The house and its steep roof, a lower wing on the left, the tower and its spire, a chimney.
        ctx.fill(rect(-36, 0, 60, 46))
        fill([(-41, 46), (-6, 82), (29, 46)])
        ctx.fill(rect(-62, 0, 28, 30))
        fill([(-66, 30), (-48, 46), (-30, 30)])
        ctx.fill(rect(22, 0, 22, 74))
        fill([(19, 74), (33, 118), (47, 74)])
        ctx.fill(rect(-30, 56, 8, 22))
        ctx.setStrokeColor(color)
        ctx.setLineWidth(1.6 * u)
        ctx.move(to: CGPoint(x: base.x + 33 * u, y: base.y + 118 * u))
        ctx.addLine(to: CGPoint(x: base.x + 33 * u, y: base.y + 128 * u))
        ctx.strokePath()
        // Lit windows (one left dark), an arched window in the tower and a round one in the attic.
        ctx.setFillColor(light)
        for (x, y) in [(-28, 12), (-12, 12), (6, 12), (-28, 28), (6, 28)] as [(CGFloat, CGFloat)] {
            ctx.fill(rect(x, y, 8, 10))
        }
        ctx.fill(rect(-55, 10, 7, 9))
        ctx.fill(rect(29, 44, 8, 11))
        ctx.fillEllipse(in: rect(29, 51, 8, 8))
        ctx.fillEllipse(in: rect(-10.5, 55.5, 9, 9))
    }

    /// A gnarled, bare tree on the right of the graveyard hill.
    private static func drawTree(in ctx: CGContext, size: CGSize, color: CGColor) {
        let u = size.width * 0.001
        let foot = CGPoint(x: 0.895 * size.width, y: (1 - height(of: graveyardHill, at: 0.9)) * size.height - 6 * u)
        ctx.setStrokeColor(color)
        ctx.setLineCap(.round)
        func branch(from start: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, depth: Int, bend: CGFloat) {
            guard depth > 0 else { return }
            let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            ctx.setLineWidth(width)
            ctx.move(to: start)
            ctx.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + length * bend, y: (start.y + end.y) / 2))
            ctx.strokePath()
            branch(from: end, angle: angle + 0.55, length: length * 0.7, width: width * 0.6, depth: depth - 1, bend: -bend)
            branch(from: end, angle: angle - 0.45, length: length * 0.62, width: width * 0.58, depth: depth - 1, bend: bend)
        }
        branch(from: foot, angle: .pi / 2 + 0.12, length: 70 * u, width: 15 * u, depth: 6, bend: 0.16)
    }

    /// Tombstones and crosses standing on the front hill, and a stretch of iron fence.
    private static func drawGraveyard(in ctx: CGContext, size: CGSize, color: CGColor) {
        let w = size.width, h = size.height, u = w * 0.001
        func ground(_ x: CGFloat) -> CGPoint { CGPoint(x: x * w, y: (1 - height(of: graveyardHill, at: x)) * h) }
        ctx.setFillColor(color)
        // (x, size, tilt, shape): 0 a rounded tombstone, 1 a cross, 2 a square-topped stone.
        for (x, scale, tilt, shape) in [(0.125, 0.8, 0.05, 1), (0.33, 0.9, 0.06, 0), (0.37, 0.75, -0.1, 2), (0.405, 0.95, 0.03, 1),
                                        (0.62, 0.85, -0.05, 0), (0.67, 0.7, 0.09, 2), (0.72, 0.9, 0.04, 0)] as [(CGFloat, CGFloat, CGFloat, Int)] {
            let foot = ground(x)
            let stoneW = 14 * u * scale, stoneH = 22 * u * scale
            ctx.saveGState()
            ctx.translateBy(x: foot.x, y: foot.y - 4 * u)
            ctx.rotate(by: tilt)
            switch shape {
            case 1:
                ctx.fill(CGRect(x: -2.2 * u * scale, y: 0, width: 4.4 * u * scale, height: 30 * u * scale))
                ctx.fill(CGRect(x: -8 * u * scale, y: 19 * u * scale, width: 16 * u * scale, height: 4.4 * u * scale))
            case 2:
                ctx.fill(CGRect(x: -stoneW / 2, y: 0, width: stoneW, height: stoneH * 0.8))
            default:
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -stoneW / 2, y: 0))
                path.addLine(to: CGPoint(x: -stoneW / 2, y: stoneH - stoneW / 2))
                path.addArc(center: CGPoint(x: 0, y: stoneH - stoneW / 2), radius: stoneW / 2, startAngle: .pi, endAngle: 0, clockwise: true)
                path.addLine(to: CGPoint(x: stoneW / 2, y: 0))
                path.closeSubpath()
                ctx.addPath(path)
                ctx.fillPath()
            }
            ctx.restoreGState()
        }

        // The fence: spiked posts and two rails.
        let posts = (0..<14).map { ground(0.165 + CGFloat($0) * 0.0105) }
        ctx.setStrokeColor(color)
        ctx.setLineWidth(2.2 * u)
        for post in posts {
            ctx.move(to: CGPoint(x: post.x, y: post.y - 4 * u))
            ctx.addLine(to: CGPoint(x: post.x, y: post.y + 26 * u))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: post.x - 3 * u, y: post.y + 25 * u))
            ctx.addLine(to: CGPoint(x: post.x, y: post.y + 32 * u))
            ctx.addLine(to: CGPoint(x: post.x + 3 * u, y: post.y + 25 * u))
            ctx.closePath()
            ctx.fillPath()
        }
        if let first = posts.first, let last = posts.last {
            for rail: CGFloat in [8, 20] {
                ctx.move(to: CGPoint(x: first.x, y: first.y + rail * u))
                ctx.addLine(to: CGPoint(x: last.x, y: last.y + rail * u))
                ctx.strokePath()
            }
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
