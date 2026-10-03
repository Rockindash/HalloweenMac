import AppKit
import SpriteKit

// All of the app's artwork is drawn in code, in the flat style of a hand-drawn harvest
// wagon: six warm colors, flat fills, no outlines, and tapered brush-stroke lines.
// Drawing in code keeps the app tiny and lets every pumpkin be a little different.

// MARK: - Colors

extension CGColor {
    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }

    func withAlpha(_ alpha: CGFloat) -> CGColor {
        copy(alpha: alpha) ?? self
    }

    /// A blend of this color and `other` (0 = this color, 1 = `other`).
    func mixed(with other: CGColor, _ amount: CGFloat) -> CGColor {
        guard let a = components, let b = other.components, a.count >= 3, b.count >= 3 else { return self }
        return CGColor(
            srgbRed: a[0] + (b[0] - a[0]) * amount,
            green: a[1] + (b[1] - a[1]) * amount,
            blue: a[2] + (b[2] - a[2]) * amount,
            alpha: 1
        )
    }
}

enum Palette {
    // The six wagon colors.
    static let green = CGColor.hex(0x627329)
    static let rust = CGColor.hex(0xA24B22)
    static let mustard = CGColor.hex(0xDB9D24)
    static let orange = CGColor.hex(0xEB6C15)
    static let plum = CGColor.hex(0x5D1C2B)
    static let peach = CGColor.hex(0xFCDCBE)

    static let stemCut = CGColor.hex(0xC9773D)
    static let shadowInk = CGColor.hex(0x3B1420)
    static let seed = CGColor.hex(0xF6E4C1)
}

// MARK: - Seeded randomness (so a pumpkin looks the same every time it's drawn)

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func float(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &self)
    }
}

// MARK: - Texture and brush helpers

enum TextureMaker {
    /// Draws into a transparent bitmap of `size` points at `scale` pixels per point.
    /// The context uses a bottom-left origin, like SpriteKit.
    static func make(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> SKTexture {
        let pixelWidth = max(1, Int(ceil(size.width * scale)))
        let pixelHeight = max(1, Int(ceil(size.height * scale)))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return SKTexture()
        }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setShouldAntialias(true)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        draw(ctx)
        guard let image = ctx.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }
}

/// Tapered brush strokes: thin at the ends, full width in the middle, like the wagon's ink lines.
enum Brush {
    /// A point on a quadratic (3 points) or cubic (4 points) Bézier curve.
    static func bezier(_ p: [CGPoint], _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        if p.count == 3 {
            return CGPoint(x: u * u * p[0].x + 2 * u * t * p[1].x + t * t * p[2].x,
                           y: u * u * p[0].y + 2 * u * t * p[1].y + t * t * p[2].y)
        }
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(x: a * p[0].x + b * p[1].x + c * p[2].x + d * p[3].x,
                       y: a * p[0].y + b * p[1].y + c * p[2].y + d * p[3].y)
    }

    /// The outline of a stroke through `points`, `width(t)` wide at each point (t runs 0...1).
    static func outline(_ points: [CGPoint], width: (CGFloat) -> CGFloat) -> CGPath {
        let n = points.count - 1
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...n {
            let a = points[max(0, i - 1)], b = points[min(n, i + 1)]
            let dx = b.x - a.x, dy = b.y - a.y, len = max(0.0001, sqrt(dx * dx + dy * dy))
            let w = width(CGFloat(i) / CGFloat(max(1, n))) / 2
            left.append(CGPoint(x: points[i].x - dy / len * w, y: points[i].y + dx / len * w))
            right.append(CGPoint(x: points[i].x + dy / len * w, y: points[i].y - dx / len * w))
        }
        let path = CGMutablePath()
        path.addLines(between: left + right.reversed())
        path.closeSubpath()
        return path
    }

    /// A stroke along a Bézier curve that swells in the middle. `minF` and `endF` are how thin
    /// the start and end are, as a fraction of `maxWidth`.
    static func stroke(_ ctx: CGContext, _ controls: [CGPoint], maxWidth: CGFloat, color: CGColor,
                       minF: CGFloat = 0.18, endF: CGFloat? = nil) {
        let end = endF ?? minF
        let n = 22
        let points = (0...n).map { bezier(controls, CGFloat($0) / CGFloat(n)) }
        let path = outline(points) { t in
            let f = t < 0.5 ? minF + (1 - minF) * sin(.pi * t) : end + (1 - end) * sin(.pi * t)
            return maxWidth * f
        }
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// A stroke through `points` that starts at `maxWidth` and thins toward the end.
    static func trail(_ ctx: CGContext, _ points: [CGPoint], maxWidth: CGFloat, color: CGColor, minF: CGFloat = 0.15) {
        guard points.count > 1 else { return }
        ctx.addPath(outline(points) { t in maxWidth * (minF + (1 - minF) * (1 - t)) })
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// A curly tendril: a short rise from `start`, then a spiral that winds inward toward `dir`.
    /// The spiral begins exactly where the rise ends, so there is no straight jump between them.
    static func tendril(_ ctx: CGContext, from start: CGPoint, dir: CGFloat, size: CGFloat, color: CGColor) {
        var points: [CGPoint] = []
        let end = CGPoint(x: start.x + dir * size * 0.25, y: start.y + size * 0.75)
        for i in 0...12 {
            let t = CGFloat(i) / 12
            points.append(CGPoint(x: start.x + (end.x - start.x) * t + dir * sin(.pi * t) * size * 0.12,
                                  y: start.y + (end.y - start.y) * t))
        }
        let radius = size * 0.26
        let center = CGPoint(x: end.x + dir * radius, y: end.y)
        let steps = Int(1.6 * 22)
        for i in 1...steps {
            let phase = CGFloat(i) / 22 * .pi * 2
            let r = radius * (1 - 0.78 * CGFloat(i) / CGFloat(steps))
            points.append(CGPoint(x: center.x - dir * cos(phase) * r, y: end.y + sin(phase) * r))
        }
        trail(ctx, points, maxWidth: max(1.4, size * 0.07), color: color, minF: 0.3)
    }
}

// MARK: - Pumpkins

enum PumpkinShape {
    case round      // three overlapping lobes
    case squat      // wide and low
    case tall       // taller than wide
    case butternut  // pear-shaped squash
}

enum PumpkinKind: CaseIterable {
    case roundOrange, roundMustard, squatMustard, squatOrange, tallOrange, tallMustard
    case butternutOrange, butternutMustard, littleGreen
    /// A rare, sparkly golden pumpkin.
    case golden

    /// Every kind except the golden one, which only turns up now and then.
    static let everyday = allCases.filter { $0 != .golden }

    struct Look {
        var shape: PumpkinShape
        var body: CGColor    // the front lobe
        var side: CGColor    // the side lobes, a shade darker
        var rib: CGColor     // rib lines
        var aspect: CGFloat  // body width / body height
        var heightFactor: CGFloat // squat and little pumpkins are shorter than the slot
    }

    var look: Look {
        let orangeSide = Palette.orange.mixed(with: Palette.rust, 0.28)
        let mustardSide = Palette.mustard.mixed(with: Palette.rust, 0.25)
        let greenSide = Palette.green.mixed(with: Palette.plum, 0.25)
        switch self {
        case .roundOrange:
            return Look(shape: .round, body: Palette.orange, side: orangeSide, rib: Palette.rust, aspect: 1.34, heightFactor: 1)
        case .roundMustard:
            return Look(shape: .round, body: Palette.mustard, side: mustardSide, rib: Palette.rust, aspect: 1.26, heightFactor: 0.92)
        case .squatMustard:
            return Look(shape: .squat, body: Palette.mustard, side: mustardSide, rib: Palette.rust, aspect: 1.9, heightFactor: 0.66)
        case .squatOrange:
            return Look(shape: .squat, body: Palette.orange, side: orangeSide, rib: Palette.rust, aspect: 1.85, heightFactor: 0.68)
        case .tallOrange:
            return Look(shape: .tall, body: Palette.orange, side: orangeSide, rib: Palette.rust, aspect: 0.88, heightFactor: 0.95)
        case .tallMustard:
            return Look(shape: .tall, body: Palette.mustard, side: mustardSide, rib: Palette.rust, aspect: 0.87, heightFactor: 0.9)
        case .butternutOrange:
            return Look(shape: .butternut, body: Palette.orange, side: orangeSide, rib: Palette.rust, aspect: 0.6, heightFactor: 1.02)
        case .butternutMustard:
            return Look(shape: .butternut, body: Palette.mustard, side: mustardSide, rib: Palette.rust, aspect: 0.56, heightFactor: 1.05)
        case .littleGreen:
            return Look(shape: .squat, body: Palette.green, side: greenSide, rib: Palette.plum, aspect: 1.7, heightFactor: 0.5)
        case .golden:
            return Look(shape: .round, body: Palette.mustard.mixed(with: Palette.peach, 0.34), side: Palette.mustard,
                        rib: Palette.mustard.mixed(with: Palette.rust, 0.45), aspect: 1.3, heightFactor: 0.95)
        }
    }

    var isRound: Bool { look.shape != .butternut }

    /// Whether a face can be carved into it (not the skinny butternuts or the little green ones).
    var isCarvable: Bool { isRound && self != .littleGreen }
}

enum PumpkinArt {
    private static var cache: [String: SKTexture] = [:]
    static let pad: CGFloat = 2

    /// Body size (the `w` x `h` box the lobe shapes are measured against) for a slot height.
    static func bodySize(of kind: PumpkinKind, height: CGFloat) -> CGSize {
        let look = kind.look
        let total = height * look.heightFactor
        let h = (total - pad * 2) / (look.shape == .butternut ? 1.14 : 1.12)
        return CGSize(width: h * look.aspect, height: h)
    }

    /// Point size of a pumpkin sprite of the given kind and slot height.
    static func size(of kind: PumpkinKind, height: CGFloat) -> CGSize {
        let body = bodySize(of: kind, height: height)
        let h = body.height * (kind.look.shape == .butternut ? 1.14 : 1.12) + pad * 2
        return CGSize(width: (body.width * 1.08 + pad * 2).rounded(), height: h.rounded())
    }

    static func texture(kind: PumpkinKind, height: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let key = "\(kind)-\(Int(size.height))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let body = bodySize(of: kind, height: height)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            draw(kind: kind, cx: size.width / 2, base: pad, w: body.width, h: body.height, variant: variant, ctx: ctx)
        }
        cache[key] = texture
        return texture
    }

    // MARK: Shapes

    /// One lobe: an ellipse centered at (a·w, b·h) from the bottom-center, rx·w by ry·h, tilted `rot` degrees.
    struct Lobe {
        var a: CGFloat, b: CGFloat, rx: CGFloat, ry: CGFloat, rot: CGFloat
    }

    /// Left side lobe, right side lobe, front lobe.
    static func lobes(_ shape: PumpkinShape) -> (Lobe, Lobe, Lobe) {
        switch shape {
        case .squat:
            return (Lobe(a: -0.27, b: 0.45, rx: 0.24, ry: 0.45, rot: -6), Lobe(a: 0.27, b: 0.45, rx: 0.24, ry: 0.45, rot: 6),
                    Lobe(a: 0, b: 0.48, rx: 0.3, ry: 0.48, rot: 0))
        case .tall:
            return (Lobe(a: -0.17, b: 0.47, rx: 0.34, ry: 0.47, rot: -4), Lobe(a: 0.17, b: 0.48, rx: 0.34, ry: 0.48, rot: 4),
                    Lobe(a: 0, b: 0.47, rx: 0.22, ry: 0.47, rot: 0))
        default:
            return (Lobe(a: -0.2, b: 0.45, rx: 0.31, ry: 0.45, rot: -8), Lobe(a: 0.2, b: 0.46, rx: 0.31, ry: 0.46, rot: 8),
                    Lobe(a: 0, b: 0.42, rx: 0.26, ry: 0.42, rot: 0))
        }
    }

    /// The ellipse of a lobe, optionally shrunk around its center by `inset`.
    static func lobePath(_ l: Lobe, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat, inset: CGFloat = 1) -> CGPath {
        let center = CGPoint(x: cx + l.a * w, y: base + l.b * h)
        let rx = l.rx * w * inset, ry = l.ry * h * inset
        // The mockups measure tilt clockwise with y pointing down; here y points up.
        var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: -l.rot * .pi / 180)
        return CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t)
    }

    /// The pear-shaped squash body.
    static func butternutPath(cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
        let path = CGMutablePath()
        path.move(to: p(-0.5, 0.3))
        path.addCurve(to: p(0.5, 0.3), control1: p(-0.52, -0.07), control2: p(0.52, -0.07))
        path.addCurve(to: p(0.29, 0.88), control1: p(0.48, 0.55), control2: p(0.28, 0.6))
        path.addQuadCurve(to: p(-0.29, 0.88), control: p(0, 1.02))
        path.addCurve(to: p(-0.5, 0.3), control1: p(-0.28, 0.6), control2: p(-0.48, 0.55))
        path.closeSubpath()
        return path
    }

    /// The whole silhouette (used to keep the vine's shadow on the pumpkin).
    static func silhouette(kind: PumpkinKind, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) -> CGPath {
        let shape = kind.look.shape
        if shape == .butternut { return butternutPath(cx: cx, base: base, w: w, h: h) }
        let (l, r, m) = lobes(shape)
        let path = CGMutablePath()
        for lobe in [l, r, m] { path.addPath(lobePath(lobe, cx: cx, base: base, w: w, h: h)) }
        return path
    }

    /// A rib that bows like a bracket around a lobe. `a` keeps it away from its neighbours,
    /// `b` sets how far it bows, so ribs never meet at the top or bottom.
    static func bowRib(_ ctx: CGContext, center c: CGPoint, rx: CGFloat, ry: CGFloat, dir: CGFloat,
                       a: CGFloat, b: CGFloat, t0: CGFloat, t1: CGFloat, width: CGFloat, color: CGColor, sway: CGFloat = 0) {
        let n = 28
        let points: [CGPoint] = (0...n).map { i in
            let t = (t0 + (t1 - t0) * CGFloat(i) / CGFloat(n)) * .pi
            return CGPoint(x: c.x + (dir * (a + b * sin(t)) + sway * sin(2 * t)) * rx, y: c.y + ry * cos(t))
        }
        let path = Brush.outline(points) { u in width * (0.2 + 0.8 * sin(.pi * pow(u, 0.85))) }
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    // MARK: Drawing

    /// Draws a pumpkin whose body is `w` x `h`, standing on `base` and centered on `cx`.
    static func draw(kind: PumpkinKind, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat, variant: Int, ctx: CGContext) {
        var rng = SeededRandom(seed: UInt64(variant) &* 7919 &+ UInt64(PumpkinKind.allCases.firstIndex(of: kind) ?? 0))
        let look = kind.look
        let lineW = max(1.2, w * 0.028)
        let stemAngle = rng.float(-12...12)

        // The stem goes first so its base tucks behind the lobes.
        if look.shape == .butternut {
            drawStem(ctx, base: CGPoint(x: cx, y: base + h * 0.85), length: h * 0.24, angle: stemAngle, baseWidth: max(4, w * 0.17))
        } else {
            drawStem(ctx, base: CGPoint(x: cx, y: base + h * 0.74), length: h * 0.3, angle: stemAngle, baseWidth: max(4, w * 0.14))
        }

        if look.shape == .butternut {
            let body = butternutPath(cx: cx, base: base, w: w, h: h)
            ctx.addPath(body)
            ctx.setFillColor(look.body)
            ctx.fillPath()

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
            // A darker right side on the bulb, kept inside the body.
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            let side = CGMutablePath()
            side.move(to: p(0.12, -0.02))
            side.addCurve(to: p(0.44, 0.45), control1: p(0.42, 0.02), control2: p(0.55, 0.25))
            side.addCurve(to: p(0.12, -0.02), control1: p(0.38, 0.3), control2: p(0.3, 0.1))
            ctx.addPath(side)
            ctx.setFillColor(look.side)
            ctx.fillPath()
            ctx.restoreGState()

            // Two S-curved ribs around the bulb, clipped to a slightly smaller body.
            ctx.saveGState()
            var shrink = CGAffineTransform(translationX: cx, y: base + h * 0.45).scaledBy(x: 0.88, y: 0.88)
                .translatedBy(x: -cx, y: -(base + h * 0.45))
            if let inner = body.copy(using: &shrink) {
                ctx.addPath(inner)
                ctx.clip()
            }
            Brush.stroke(ctx, [p(-0.02, 0.86), p(0.04, 0.62), p(-0.56, 0.38), p(-0.2, 0.05)],
                         maxWidth: lineW * 1.2, color: look.rib, minF: 0.25, endF: 0.2)
            Brush.stroke(ctx, [p(0.06, 0.8), p(-0.04, 0.55), p(0.48, 0.36), p(0.16, 0.05)],
                         maxWidth: lineW * 1.2, color: look.rib, minF: 0.25, endF: 0.2)
            ctx.restoreGState()

            // Little spot where the flower was.
            ctx.setFillColor(Palette.rust.withAlpha(0.6))
            ctx.fillEllipse(in: CGRect(x: cx + w * 0.02 - w * 0.07, y: base + h * 0.06 - h * 0.025, width: w * 0.14, height: h * 0.05))
            return
        }

        let (left, right, front) = lobes(look.shape)

        // Side lobes, each with one rib centered in the part that stays visible.
        for (lobe, dir) in [(left, CGFloat(-1)), (right, CGFloat(1))] {
            ctx.addPath(lobePath(lobe, cx: cx, base: base, w: w, h: h))
            ctx.setFillColor(look.side)
            ctx.fillPath()
            ctx.saveGState()
            ctx.addPath(lobePath(lobe, cx: cx, base: base, w: w, h: h, inset: 0.86))
            ctx.clip()
            bowRib(ctx, center: CGPoint(x: cx + lobe.a * w, y: base + lobe.b * h), rx: lobe.rx * w, ry: lobe.ry * h * 0.95,
                   dir: dir, a: 0.22, b: 0.34, t0: 0.22, t1: 0.78, width: lineW * 1.2, color: look.rib)
            ctx.restoreGState()
        }

        // The front lobe covers the side ribs where they meet, then gets its own ribs inside it.
        ctx.addPath(lobePath(front, cx: cx, base: base, w: w, h: h))
        ctx.setFillColor(look.body)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(lobePath(front, cx: cx, base: base, w: w, h: h, inset: 0.88))
        ctx.clip()
        let fc = CGPoint(x: cx, y: base + front.b * h), frx = front.rx * w, fry = front.ry * h * 0.95
        bowRib(ctx, center: fc, rx: frx, ry: fry, dir: -1, a: 0.24, b: 0.34, t0: 0.2, t1: 0.8, width: lineW * 1.2, color: look.rib)
        bowRib(ctx, center: fc, rx: frx, ry: fry, dir: 1, a: 0.24, b: 0.34, t0: 0.2, t1: 0.8, width: lineW * 1.2, color: look.rib)
        // A gently swaying middle rib, only when the lobe is wide enough to keep the ribs apart.
        if frx > 12 {
            let sway: CGFloat = rng.float(0...1) < 0.5 ? -0.07 : 0.07
            bowRib(ctx, center: fc, rx: frx, ry: fry, dir: 1, a: 0, b: 0, t0: 0.24, t1: 0.76, width: lineW * 1.05,
                   color: look.rib, sway: sway)
        }
        ctx.restoreGState()
    }

    /// A chunky rust stem with a cut top and a plum shadow ridge, like the wagon pumpkins.
    /// `angle` is in degrees; positive leans right.
    static func drawStem(_ ctx: CGContext, base: CGPoint, length: CGFloat, angle: CGFloat, baseWidth bw: CGFloat) {
        let a = angle * .pi / 180
        let d = CGPoint(x: sin(a), y: cos(a))   // along the stem, upward
        let n = CGPoint(x: cos(a), y: -sin(a))  // across the stem, to the right
        let tip = CGPoint(x: base.x + d.x * length, y: base.y + d.y * length)
        let tw = bw * 0.62, bend = bw * 0.35
        func at(_ along: CGFloat, _ across: CGFloat, from o: CGPoint = base) -> CGPoint {
            CGPoint(x: o.x + d.x * along + n.x * across, y: o.y + d.y * along + n.y * across)
        }
        let path = CGMutablePath()
        path.move(to: at(0, -bw / 2))
        path.addQuadCurve(to: at(0, -tw / 2, from: tip), control: at(length * 0.55, -(bw * 0.42 - bend)))
        path.addLine(to: at(tw * 0.25, tw / 2, from: tip))
        path.addQuadCurve(to: at(0, bw / 2), control: at(length * 0.55, bw * 0.42 + bend))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(Palette.rust)
        ctx.fillPath()

        // Plum shadow ridge down one side.
        let tw2 = bw * 0.7
        Brush.stroke(ctx, [CGPoint(x: base.x + n.x * bw * 0.18, y: base.y + n.y * bw * 0.18 + 2),
                           at(length * 0.5, bw * 0.16),
                           CGPoint(x: tip.x + n.x * tw2 * 0.12, y: tip.y + n.y * tw2 * 0.12 - 2)],
                     maxWidth: bw * 0.26, color: Palette.plum, minF: 0.5, endF: 0.3)

        // The cut top, a little lighter.
        let cut = CGPoint(x: tip.x + d.x * tw2 * 0.1, y: tip.y + d.y * tw2 * 0.1)
        var t = CGAffineTransform(translationX: cut.x, y: cut.y).rotated(by: -a)
        let rx = tw2 * 0.5, ry = tw2 * 0.22
        ctx.addPath(CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: &t))
        ctx.setFillColor(Palette.stemCut)
        ctx.fillPath()
    }

    /// A flat, soft contact shadow that sits under each pumpkin.
    static func shadowTexture(width: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "shadow-\(Int(width))-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: width, height: 8)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            ctx.setFillColor(CGColor(srgbRed: 90 / 255, green: 40 / 255, blue: 25 / 255, alpha: 0.22))
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        cache[key] = texture
        return texture
    }

    // MARK: Smash bits

    static func shardTexture(kind: PumpkinKind, size: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let key = "shard-\(kind)-\(Int(size))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let look = kind.look
        let s = CGSize(width: size, height: size)
        let texture = TextureMaker.make(size: s, scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(variant) &* 104729 &+ 17)
            let c = CGPoint(x: size / 2, y: size / 2)
            let points = 5 + variant % 3
            let path = CGMutablePath()
            for k in 0..<points {
                let a = CGFloat(k) / CGFloat(points) * .pi * 2 + rng.float(-0.25...0.25)
                let r = size * 0.5 * rng.float(0.55...0.98)
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(variant % 3 == 0 ? look.side : look.body)
            ctx.fillPath()
            // A strip of flat, pale flesh on one edge.
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setFillColor(Palette.peach.withAlpha(0.7))
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size * 0.26))
            ctx.restoreGState()
        }
        cache[key] = texture
        return texture
    }

    static func seedTexture(scale: CGFloat) -> SKTexture {
        let key = "seed-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: 3.2, height: 5)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 1.6, y: 0.2))
            path.addQuadCurve(to: CGPoint(x: 1.6, y: 4.8), control: CGPoint(x: 3.4, y: 2.2))
            path.addQuadCurve(to: CGPoint(x: 1.6, y: 0.2), control: CGPoint(x: -0.2, y: 2.2))
            ctx.addPath(path)
            ctx.setFillColor(Palette.seed)
            ctx.fillPath()
        }
        cache[key] = texture
        return texture
    }

    static func splatTexture(kind: PumpkinKind, width: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "splat-\(kind)-\(Int(width))-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: width, height: width * 0.32)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(width) &+ 99)
            ctx.setFillColor(kind.look.body.withAlpha(0.85))
            ctx.fillEllipse(in: CGRect(x: width * 0.12, y: size.height * 0.1, width: width * 0.76, height: size.height * 0.75))
            for _ in 0..<9 {
                let r = rng.float(width * 0.04...width * 0.1)
                let x = rng.float(width * 0.05...width * 0.95)
                let y = rng.float(size.height * 0.1...size.height * 0.75)
                ctx.fillEllipse(in: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2))
            }
            ctx.setFillColor(Palette.seed)
            for _ in 0..<6 {
                let x = rng.float(width * 0.2...width * 0.8)
                let y = rng.float(size.height * 0.25...size.height * 0.65)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 1.4))
            }
        }
        cache[key] = texture
        return texture
    }
}

// MARK: - Leaves

/// The four leaves from the wagon picture.
enum LeafKind: CaseIterable {
    case oak       // mustard oak leaf with rust veins
    case ovate     // rust leaf with plum veins
    case serrated  // green toothed leaf with plum veins
    case plum      // plum leaf with mustard veins

    static let fallers: [LeafKind] = LeafKind.allCases

    var fill: CGColor {
        switch self {
        case .oak: return Palette.mustard
        case .ovate: return Palette.rust
        case .serrated: return Palette.green
        case .plum: return Palette.plum
        }
    }

    var vein: CGColor {
        switch self {
        case .oak: return Palette.rust
        case .ovate, .serrated: return Palette.plum
        case .plum: return Palette.mustard
        }
    }
}

enum LeafArt {
    private static var cache: [String: SKTexture] = [:]

    /// A single leaf in a square sprite, for falling and flying leaves.
    static func texture(_ kind: LeafKind, size: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let key = "\(kind)-\(Int(size))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let s = CGSize(width: size, height: size)
        let texture = TextureMaker.make(size: s, scale: scale) { ctx in
            // Lay the leaf along the diagonal so it fills the square.
            let length = size * 0.78
            drawWagonLeaf(ctx, kind: kind, at: CGPoint(x: size * 0.54, y: size * 0.54), length: length,
                          angle: 45, flip: variant % 2 == 1)
        }
        cache[key] = texture
        return texture
    }

    /// The outline of a leaf lying along the x axis from 0 to `length`.
    private static func outline(_ kind: LeafKind, length: CGFloat, width: CGFloat) -> CGPath {
        let n = 60
        var top: [CGPoint] = [], bottom: [CGPoint] = []
        let ovate = kind == .ovate || kind == .plum
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            var hw = width * pow(sin(.pi * pow(t, ovate ? 0.75 : 0.9)), 0.85)
            if kind == .oak { hw *= 0.78 + 0.32 * abs(sin(t * .pi * 4.5)) }
            if kind == .serrated { hw *= 1 - 0.16 * (t * 9).truncatingRemainder(dividingBy: 1) }
            top.append(CGPoint(x: t * length, y: hw))
            bottom.append(CGPoint(x: t * length, y: -hw * (ovate ? 1.05 : 1)))
        }
        let path = CGMutablePath()
        path.addLines(between: top + bottom.reversed())
        path.closeSubpath()
        return path
    }

    /// A wagon-style leaf: flat fill, a curved stalk, a midrib and tapered side veins.
    /// `at` is the leaf's middle; `angle` is in degrees, counterclockwise from pointing right.
    static func drawWagonLeaf(_ ctx: CGContext, kind: LeafKind, at center: CGPoint, length: CGFloat, angle: CGFloat, flip: Bool) {
        let width = length * (kind == .ovate || kind == .plum ? 0.34 : 0.3)
        let vw = max(0.7, length * 0.028)
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle * .pi / 180)
        if flip { ctx.scaleBy(x: 1, y: -1) }
        ctx.translateBy(x: -length / 2, y: 0)

        // Stalk.
        Brush.stroke(ctx, [CGPoint(x: -length * 0.32, y: length * 0.06), CGPoint(x: -length * 0.15, y: length * 0.05),
                           CGPoint(x: length * 0.05, y: 0)], maxWidth: vw * 1.1, color: kind.vein, minF: 0.6)
        ctx.addPath(outline(kind, length: length, width: width))
        ctx.setFillColor(kind.fill)
        ctx.fillPath()
        // Midrib and side veins.
        Brush.stroke(ctx, [CGPoint(x: 0, y: 0), CGPoint(x: length * 0.45, y: -length * 0.02), CGPoint(x: length * 0.88, y: 0)],
                     maxWidth: vw * 1.3, color: kind.vein, minF: 0.5, endF: 0.1)
        for k in 0..<5 {
            let bx = (0.16 + CGFloat(k) * 0.14) * length
            let side = width * (0.6 - CGFloat(k) * 0.08)
            for s in [CGFloat(1), -1] {
                Brush.stroke(ctx, [CGPoint(x: bx, y: 0), CGPoint(x: bx + length * 0.03, y: s * side * 0.6),
                                   CGPoint(x: bx + length * 0.12, y: s * side * 0.95)],
                             maxWidth: vw, color: kind.vein, minF: 0.4, endF: 0.1)
            }
        }
        ctx.restoreGState()
    }
}

// MARK: - Vines

/// The pumpkin vine that runs along the top of the Dock behind the pumpkins: a wavy main
/// vine that swells and pinches, with fine ridges, two-tone curls and buds, and no leaves.
enum VineArt {
    private static var cache: [String: SKTexture] = [:]

    /// Where the middle of the main vine sits, measured up from the bottom of the vine texture.
    /// `x` is measured from the texture's left edge; `k` is the size unit (1 ≈ a 62 pt pumpkin).
    static func centerY(x: CGFloat, unit k: CGFloat) -> CGFloat {
        baseLevel(unit: k) - (sin(x / (47 * k)) * 3.2 + sin(x / (17 * k)) * 1.2) * k
    }

    static func baseLevel(unit k: CGFloat) -> CGFloat { 8 * k }

    static func texture(width: CGFloat, height: CGFloat, seed: Int, unit k: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "vine-\(Int(width))-\(Int(height))-\(seed)-\(Int(k * 100))-\(scale)"
        if let cached = cache[key] { return cached }
        if cache.count > 40 { cache.removeAll() }
        let size = CGSize(width: width, height: height)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            draw(ctx, size: size, seed: seed, k: k)
        }
        cache[key] = texture
        return texture
    }

    /// A vine through `xs` at heights `y(x)`, `maxWidth` wide, swelling and pinching along its length.
    static func taperedVine(_ ctx: CGContext, from x0: CGFloat, to x1: CGFloat, maxWidth: CGFloat, color: CGColor,
                            y: (CGFloat) -> CGFloat) {
        guard x1 > x0 else { return }
        let xs = stride(from: x0, through: x1, by: 3).map { $0 }
        let points = xs.map { CGPoint(x: $0, y: y($0)) }
        let path = Brush.outline(points) { t in
            let x = x0 + (x1 - x0) * t
            return maxWidth * (0.55 + 0.3 * sin(x / 31) * sin(x / 13) + 0.25 * sin(.pi * t))
        }
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    private static func draw(_ ctx: CGContext, size: CGSize, seed: Int, k: CGFloat) {
        var rng = SeededRandom(seed: UInt64(seed) &* 6151 &+ 3)
        let x0: CGFloat = 4, x1 = size.width - 4
        func vy(_ x: CGFloat) -> CGFloat { centerY(x: x, unit: k) }
        let dark = Palette.green.mixed(with: Palette.plum, 0.38)
        let width = 6 * k

        // The main vine.
        taperedVine(ctx, from: x0, to: x1, maxWidth: width, color: Palette.green) { vy($0) }

        // Fine ridges across the stem.
        var ridges = SeededRandom(seed: UInt64(seed) &* 911 &+ 7)
        var x = x0 + 3 * k
        while x < x1 - 3 * k {
            if ridges.float(0...1) < 0.65 {
                let y = vy(x)
                Brush.stroke(ctx, [CGPoint(x: x - 1.2 * k, y: y - width * 0.32), CGPoint(x: x, y: y - width * 0.05),
                                   CGPoint(x: x + 1.4 * k, y: y + width * 0.18)],
                             maxWidth: max(0.6, 0.75 * k), color: dark.withAlpha(0.7), minF: 0.3)
            }
            x += ridges.float(5...9) * k
        }

        // Curly tendrils of mixed sizes, each with a darker shadow.
        x = x0 + rng.float(50...90) * k
        var i = 0
        while x < x1 - 30 * k {
            let start = CGPoint(x: x, y: vy(x))
            let dir: CGFloat = i % 2 == 0 ? 1 : -1
            let size = rng.float(24...42) * k
            Brush.tendril(ctx, from: CGPoint(x: start.x + 1.2 * k, y: start.y - 1.2 * k), dir: dir, size: size, color: dark)
            Brush.tendril(ctx, from: start, dir: dir, size: size, color: Palette.green)
            x += rng.float(75...140) * k
            i += 1
        }

        // A few small buds on short stalks.
        x = x0 + rng.float(200...280) * k
        while x < x1 - 40 * k {
            drawBud(ctx, at: CGPoint(x: x, y: vy(x)), length: rng.float(14...16) * k, angle: rng.float(70...110))
            x += rng.float(260...340) * k
        }
    }

    private static func drawBud(_ ctx: CGContext, at start: CGPoint, length: CGFloat, angle: CGFloat) {
        let r = angle * .pi / 180
        let tip = CGPoint(x: start.x + cos(r) * length, y: start.y + sin(r) * length)
        Brush.stroke(ctx, [start, CGPoint(x: (start.x + tip.x) / 2 + 2, y: (start.y + tip.y) / 2), tip],
                     maxWidth: 2.4, color: Palette.green, minF: 0.6)
        ctx.saveGState()
        ctx.translateBy(x: tip.x, y: tip.y)
        ctx.rotate(by: r - .pi / 2)
        ctx.setFillColor(Palette.mustard)
        ctx.fillEllipse(in: CGRect(x: -length * 0.2, y: -length * 0.32, width: length * 0.4, height: length * 0.64))
        ctx.setFillColor(Palette.orange)
        ctx.fillEllipse(in: CGRect(x: -length * 0.1, y: -length * 0.3 + length * 0.05, width: length * 0.2, height: length * 0.6))
        ctx.restoreGState()
    }
}
