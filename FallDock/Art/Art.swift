import AppKit
import SpriteKit

// All of the app's artwork is drawn in code, in a flat, speckled, hand-drawn
// autumn style: warm oranges, dusty pinks, butter yellows and sage greens.
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
}

enum Palette {
    static let cream = CGColor.hex(0xFCEBD5)
    static let seed = CGColor.hex(0xF6E4C1)
    static let leafGreen = CGColor.hex(0x3F6420)
    static let sage = CGColor.hex(0xA3A04C)
    static let stemBrown = CGColor.hex(0x6B4429)
    static let stemBrownDark = CGColor.hex(0x4A2C1A)
    static let stemGreenDark = CGColor.hex(0x2B4615)
    static let vine = CGColor.hex(0x5B7A2C)
    static let vineDark = CGColor.hex(0x3B5418)
    static let pumpkinLeaf = CGColor.hex(0x557F2E)
    static let pumpkinLeafLight = CGColor.hex(0x86A94B)
    static let blossom = CGColor.hex(0xF4B63F)
    static let maple = CGColor.hex(0xEE8A2C)
    static let mapleRed = CGColor.hex(0xB3361F)
    static let golden = CGColor.hex(0xF3B23C)
    static let rust = CGColor.hex(0xC9562A)
    static let berry = CGColor.hex(0xE4532B)
    static let acorn = CGColor.hex(0xD9A35A)
    static let acornCap = CGColor.hex(0x8C5A35)
}

// MARK: - Seeded randomness (so a pumpkin's speckles don't change every frame)

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

// MARK: - Texture helper

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

    /// Sprinkles the soft speckles and flecks that give the art its printed, cozy texture.
    /// Speckles are denser toward the edges of the shape, like the reference style.
    static func speckle(
        _ ctx: CGContext,
        clip path: CGPath,
        in rect: CGRect,
        dark: CGColor,
        light: CGColor,
        density: CGFloat,
        rng: inout SeededRandom
    ) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let count = Int(rect.width * rect.height * density)
        for _ in 0..<count {
            let p = CGPoint(x: rng.float(rect.minX...rect.maxX), y: rng.float(rect.minY...rect.maxY))
            let dx = (p.x - rect.midX) / (rect.width / 2)
            let dy = (p.y - rect.midY) / (rect.height / 2)
            let edge = min(1, sqrt(dx * dx + dy * dy))
            guard rng.float(0...1) < 0.25 + 0.75 * edge * edge else { continue }
            let r = rng.float(0.25...0.95)
            ctx.setFillColor(dark.withAlpha(rng.float(0.35...0.75)))
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        // A few pale, chunky flecks.
        for _ in 0..<max(2, count / 14) {
            let p = CGPoint(x: rng.float(rect.minX...rect.maxX), y: rng.float(rect.minY...rect.maxY))
            let s = rng.float(0.8...1.8)
            let angle = rng.float(0...(.pi * 2))
            let fleck = CGMutablePath()
            for k in 0..<3 {
                let a = angle + CGFloat(k) * 2.1 + rng.float(-0.3...0.3)
                let pt = CGPoint(x: p.x + cos(a) * s, y: p.y + sin(a) * s * 0.8)
                if k == 0 { fleck.move(to: pt) } else { fleck.addLine(to: pt) }
            }
            fleck.closeSubpath()
            ctx.setFillColor(light.withAlpha(0.85))
            ctx.addPath(fleck)
            ctx.fillPath()
        }
        ctx.restoreGState()
    }
}

// MARK: - Pumpkins

enum PumpkinKind: CaseIterable {
    case classic      // round orange with ribs and a green stem
    case striped      // orange with deep green stripes
    case squat        // flat dusty-pink pumpkin with scalloped lobes
    case pear         // tall pink, pear-shaped squash
    case butternut    // butter-yellow, tall and curvy
    case blueHubbard  // tall soft blue-grey heirloom

    struct Look {
        var body: CGColor
        var rib: CGColor
        var speckDark: CGColor
        var speckLight: CGColor
        var stem: CGColor
        var stemDark: CGColor
        var stripe: CGColor?
        var aspect: CGFloat       // width / height of the whole sprite
        var stemFraction: CGFloat // how much of the height is stem
        var hasTendril: Bool
    }

    var look: Look {
        switch self {
        case .classic:
            return Look(body: .hex(0xF26A2E), rib: .hex(0xB4431B), speckDark: .hex(0xC2451C), speckLight: .hex(0xF9A46C),
                        stem: Palette.leafGreen, stemDark: Palette.stemGreenDark, stripe: nil,
                        aspect: 1.12, stemFraction: 0.24, hasTendril: false)
        case .striped:
            return Look(body: .hex(0xF7893A), rib: .hex(0x7A3B12), speckDark: .hex(0xD45F1E), speckLight: .hex(0xFBC38D),
                        stem: Palette.stemBrown, stemDark: Palette.stemBrownDark, stripe: Palette.leafGreen,
                        aspect: 1.0, stemFraction: 0.26, hasTendril: false)
        case .squat:
            return Look(body: .hex(0xF5AC8E), rib: .hex(0xBF664A), speckDark: .hex(0xD7806A), speckLight: .hex(0xFCE3D6),
                        stem: Palette.leafGreen, stemDark: Palette.stemGreenDark, stripe: nil,
                        aspect: 1.55, stemFraction: 0.3, hasTendril: false)
        case .pear:
            return Look(body: .hex(0xF4A98B), rib: .hex(0xAE5639), speckDark: .hex(0xCF7660), speckLight: .hex(0xF9CDB9),
                        stem: Palette.leafGreen, stemDark: Palette.stemGreenDark, stripe: nil,
                        aspect: 0.68, stemFraction: 0.16, hasTendril: false)
        case .butternut:
            return Look(body: .hex(0xF1CB7E), rib: .hex(0xD3A13B), speckDark: .hex(0xE8977A), speckLight: .hex(0xFBE7BD),
                        stem: Palette.stemBrown, stemDark: Palette.stemBrownDark, stripe: nil,
                        aspect: 0.74, stemFraction: 0.17, hasTendril: true)
        case .blueHubbard:
            return Look(body: .hex(0xC3CCCC), rib: .hex(0x4F6464), speckDark: .hex(0x8A9999), speckLight: .hex(0xF1F4F4),
                        stem: Palette.stemBrown, stemDark: Palette.stemBrownDark, stripe: nil,
                        aspect: 0.66, stemFraction: 0.14, hasTendril: true)
        }
    }

    var isRound: Bool { self == .classic || self == .striped || self == .squat }
}

enum PumpkinArt {
    private static var cache: [String: SKTexture] = [:]

    /// Point size of a pumpkin sprite of the given kind and height.
    static func size(of kind: PumpkinKind, height: CGFloat) -> CGSize {
        let h = kind == .squat ? height * 0.8 : height
        return CGSize(width: (h * kind.look.aspect).rounded(), height: h.rounded())
    }

    static func texture(kind: PumpkinKind, height: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let key = "\(kind)-\(Int(size.height))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            draw(kind: kind, in: size, variant: variant, ctx: ctx)
        }
        cache[key] = texture
        return texture
    }

    /// The body outline for a pumpkin whose body fills `w` x `bh` points.
    static func bodyPath(kind: PumpkinKind, w: CGFloat, bh: CGFloat) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .classic, .striped, .squat:
            // Overlapping lobes give the soft scalloped silhouette.
            let lobes = kind == .squat ? 7 : 5
            let lobeW = w * (kind == .squat ? 0.30 : 0.44)
            for i in 0..<lobes {
                let t = CGFloat(i) / CGFloat(lobes - 1) // 0...1
                let cx = lobeW / 2 + t * (w - lobeW)
                let edge = abs(t - 0.5) * 2 // 0 center, 1 outside
                let lh = bh * (1 - 0.12 * edge)
                path.addEllipse(in: CGRect(x: cx - lobeW / 2, y: (bh - lh) * 0.35, width: lobeW, height: lh))
            }
        case .pear:
            path.move(to: CGPoint(x: w * 0.5, y: 0))
            path.addCurve(to: CGPoint(x: w * 0.99, y: bh * 0.30),
                          control1: CGPoint(x: w * 0.86, y: 0), control2: CGPoint(x: w * 0.99, y: bh * 0.12))
            path.addCurve(to: CGPoint(x: w * 0.68, y: bh * 0.94),
                          control1: CGPoint(x: w * 0.99, y: bh * 0.55), control2: CGPoint(x: w * 0.70, y: bh * 0.62))
            path.addCurve(to: CGPoint(x: w * 0.32, y: bh * 0.94),
                          control1: CGPoint(x: w * 0.63, y: bh * 1.02), control2: CGPoint(x: w * 0.37, y: bh * 1.02))
            path.addCurve(to: CGPoint(x: w * 0.01, y: bh * 0.30),
                          control1: CGPoint(x: w * 0.30, y: bh * 0.62), control2: CGPoint(x: w * 0.01, y: bh * 0.55))
            path.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                          control1: CGPoint(x: w * 0.01, y: bh * 0.12), control2: CGPoint(x: w * 0.14, y: 0))
            path.closeSubpath()
        case .butternut, .blueHubbard:
            let waist: CGFloat = kind == .butternut ? 0.86 : 0.90
            path.move(to: CGPoint(x: w * 0.5, y: 0))
            path.addCurve(to: CGPoint(x: w * 0.99, y: bh * 0.24),
                          control1: CGPoint(x: w * 0.88, y: 0), control2: CGPoint(x: w * 0.99, y: bh * 0.08))
            path.addCurve(to: CGPoint(x: w * waist, y: bh * 0.62),
                          control1: CGPoint(x: w * 0.99, y: bh * 0.44), control2: CGPoint(x: w * waist, y: bh * 0.50))
            path.addCurve(to: CGPoint(x: w * 0.60, y: bh * 0.99),
                          control1: CGPoint(x: w * waist, y: bh * 0.86), control2: CGPoint(x: w * 0.80, y: bh * 0.99))
            path.addLine(to: CGPoint(x: w * 0.40, y: bh * 0.99))
            path.addCurve(to: CGPoint(x: w * (1 - waist), y: bh * 0.62),
                          control1: CGPoint(x: w * 0.20, y: bh * 0.99), control2: CGPoint(x: w * (1 - waist), y: bh * 0.86))
            path.addCurve(to: CGPoint(x: w * 0.01, y: bh * 0.24),
                          control1: CGPoint(x: w * (1 - waist), y: bh * 0.50), control2: CGPoint(x: w * 0.01, y: bh * 0.44))
            path.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                          control1: CGPoint(x: w * 0.01, y: bh * 0.08), control2: CGPoint(x: w * 0.12, y: 0))
            path.closeSubpath()
        }
        return path
    }

    /// The rounded segments a pumpkin is made of, ordered back to front.
    /// Round pumpkins use their lobes; tall squashes use nested ribs clipped to the body.
    static func segments(kind: PumpkinKind, w: CGFloat, bh: CGFloat) -> [CGRect] {
        if kind.isRound {
            let lobes = kind == .squat ? 7 : 5
            let lobeW = w * (kind == .squat ? 0.30 : 0.44)
            let rects: [(CGFloat, CGRect)] = (0..<lobes).map { i in
                let t = CGFloat(i) / CGFloat(lobes - 1)
                let cx = lobeW / 2 + t * (w - lobeW)
                let edge = abs(t - 0.5) * 2
                let lh = bh * (1 - 0.12 * edge)
                return (edge, CGRect(x: cx - lobeW / 2, y: (bh - lh) * 0.35, width: lobeW, height: lh))
            }
            return rects.sorted { $0.0 > $1.0 }.map { $0.1 }
        }
        return [0.84, 0.6, 0.34].map { f in
            CGRect(x: w * (1 - f) / 2, y: bh * 0.005, width: w * f, height: bh * 0.99)
        }
    }

    /// Soft side shading across a rounded segment: darker toward both edges (more on the right,
    /// away from the light), with a gentle highlight a third of the way in.
    private static func shadeSegment(_ ctx: CGContext, rect: CGRect, strength: CGFloat) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let shade: [CGColor] = [
            CGColor.hex(0x3A1A08, alpha: 0.30 * strength),
            CGColor.hex(0x3A1A08, alpha: 0.06 * strength),
            CGColor.hex(0x3A1A08, alpha: 0),
            CGColor.hex(0x3A1A08, alpha: 0.12 * strength),
            CGColor.hex(0x3A1A08, alpha: 0.42 * strength),
        ]
        if let gradient = CGGradient(colorsSpace: space, colors: shade as CFArray, locations: [0, 0.2, 0.42, 0.72, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
        }
        let shine: [CGColor] = [
            CGColor.hex(0xFFF6E6, alpha: 0),
            CGColor.hex(0xFFF6E6, alpha: 0.22 * strength),
            CGColor.hex(0xFFF6E6, alpha: 0),
        ]
        if let gradient = CGGradient(colorsSpace: space, colors: shine as CFArray, locations: [0.14, 0.32, 0.5]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
        }
    }

    private static func fillStripes(_ ctx: CGContext, look: PumpkinKind.Look, w: CGFloat, bh: CGFloat) {
        guard let stripe = look.stripe else { return }
        let bands: [(CGFloat, CGColor)] = [(0.82, stripe), (0.64, look.body), (0.36, stripe), (0.20, look.body)]
        for (fraction, color) in bands {
            let bw = w * fraction
            ctx.setFillColor(color)
            ctx.fillEllipse(in: CGRect(x: (w - bw) / 2, y: -bh * 0.02, width: bw, height: bh * 1.04))
        }
    }

    private static func draw(kind: PumpkinKind, in size: CGSize, variant: Int, ctx: CGContext) {
        var rng = SeededRandom(seed: UInt64(variant) &* 7919 &+ UInt64(PumpkinKind.allCases.firstIndex(of: kind) ?? 0))
        let look = kind.look
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let pad: CGFloat = 1
        let w = size.width - pad * 2
        let bh = size.height * (1 - look.stemFraction) - pad

        ctx.saveGState()
        ctx.translateBy(x: pad, y: pad)

        let body = bodyPath(kind: kind, w: w, bh: bh)
        let bodyRect = CGRect(x: 0, y: 0, width: w, height: bh)
        let ribWidth = max(0.5, w / 110)

        // 1. The whole body, shaded as one rounded form.
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        ctx.setFillColor(look.body)
        ctx.fill(bodyRect)
        fillStripes(ctx, look: look, w: w, bh: bh)
        shadeSegment(ctx, rect: bodyRect, strength: 1)
        ctx.restoreGState()

        // 2. Each lobe or rib on top, back to front, so every segment looks rounded.
        for rect in segments(kind: kind, w: w, bh: bh) {
            let segment = CGPath(ellipseIn: rect, transform: nil)
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.addPath(segment)
            ctx.clip()
            ctx.setFillColor(look.body)
            ctx.fill(bodyRect)
            fillStripes(ctx, look: look, w: w, bh: bh)
            shadeSegment(ctx, rect: rect, strength: kind.isRound ? 0.85 : 0.7)
            // The crease where this segment meets the one behind it.
            ctx.addPath(segment)
            ctx.setStrokeColor(look.rib.withAlpha(0.55))
            ctx.setLineWidth(ribWidth * 2)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // 3. Light from above: darker underneath, a dimple around the stem.
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        let vertical: [CGColor] = [
            CGColor.hex(0x2A1205, alpha: 0.38),
            CGColor.hex(0x2A1205, alpha: 0.0),
            CGColor.hex(0x2A1205, alpha: 0.0),
            CGColor.hex(0x2A1205, alpha: 0.18),
        ]
        if let gradient = CGGradient(colorsSpace: space, colors: vertical as CFArray, locations: [0, 0.38, 0.8, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: bh), options: [])
        }
        // A soft glow on the upper left.
        let glow: [CGColor] = [CGColor.hex(0xFFF3DC, alpha: 0.28), CGColor.hex(0xFFF3DC, alpha: 0)]
        if let gradient = CGGradient(colorsSpace: space, colors: glow as CFArray, locations: [0, 1]) {
            let c = CGPoint(x: w * 0.32, y: bh * 0.66)
            ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: max(w, bh) * 0.36, options: [])
        }
        ctx.restoreGState()

        // 4. The speckled, printed texture from the reference style.
        TextureMaker.speckle(ctx, clip: body, in: bodyRect, dark: look.speckDark, light: look.speckLight,
                             density: 0.08, rng: &rng)

        // 5. Stem.
        let topY = bh - (kind.isRound ? bh * 0.07 : bh * 0.02)
        let stemH = size.height - topY - pad * 2
        let lean: CGFloat = (variant % 2 == 0 ? 1 : -1) * stemH * CGFloat(0.25 + 0.1 * Double(variant % 3))
        let baseWidth = max(3, min(w * (kind.isRound ? 0.16 : 0.22), 11))
        let base = CGPoint(x: w / 2, y: topY)
        drawStem(ctx, look: look, base: base, height: stemH, lean: lean, baseWidth: baseWidth)

        // 6. Curly tendril.
        if look.hasTendril {
            let curl = CGMutablePath()
            let dir: CGFloat = lean > 0 ? -1 : 1
            let start = CGPoint(x: base.x, y: base.y + stemH * 0.3)
            curl.move(to: start)
            curl.addCurve(to: CGPoint(x: start.x + dir * w * 0.32, y: start.y + stemH * 0.35),
                          control1: CGPoint(x: start.x + dir * w * 0.12, y: start.y + stemH * 0.5),
                          control2: CGPoint(x: start.x + dir * w * 0.22, y: start.y - stemH * 0.05))
            curl.addCurve(to: CGPoint(x: start.x + dir * w * 0.44, y: start.y + stemH * 0.55),
                          control1: CGPoint(x: start.x + dir * w * 0.42, y: start.y + stemH * 0.65),
                          control2: CGPoint(x: start.x + dir * w * 0.34, y: start.y + stemH * 0.7))
            ctx.setStrokeColor(Palette.vine)
            ctx.setLineWidth(max(0.6, w / 70))
            ctx.addPath(curl)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    /// A tapered, ridged stem with a flared base and a cut, dried top.
    static func drawStem(_ ctx: CGContext, look: PumpkinKind.Look, base: CGPoint, height: CGFloat, lean: CGFloat, baseWidth: CGFloat) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let tip = CGPoint(x: base.x + lean, y: base.y + height * 0.92)
        let control = CGPoint(x: base.x - lean * 0.2, y: base.y + height * 0.65)
        let topWidth = baseWidth * 0.58

        func point(_ t: CGFloat) -> CGPoint {
            let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
            return CGPoint(x: a * base.x + b * control.x + c * tip.x, y: a * base.y + b * control.y + c * tip.y)
        }
        func normal(_ t: CGFloat) -> CGPoint {
            let dx = 2 * (1 - t) * (control.x - base.x) + 2 * t * (tip.x - control.x)
            let dy = 2 * (1 - t) * (control.y - base.y) + 2 * t * (tip.y - control.y)
            let len = max(0.001, sqrt(dx * dx + dy * dy))
            return CGPoint(x: -dy / len, y: dx / len)
        }
        func halfWidth(_ t: CGFloat) -> CGFloat {
            // Flared at the bottom, then a steady taper.
            let flare = pow(max(0, 1 - t * 4), 2) * baseWidth * 0.35
            return (baseWidth + (topWidth - baseWidth) * t) / 2 + flare
        }

        let steps = 16
        let outline = CGMutablePath()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = point(t), n = normal(t), h = halfWidth(t)
            let q = CGPoint(x: p.x + n.x * h, y: p.y + n.y * h)
            if i == 0 { outline.move(to: q) } else { outline.addLine(to: q) }
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let t = CGFloat(i) / CGFloat(steps)
            let p = point(t), n = normal(t), h = halfWidth(t)
            outline.addLine(to: CGPoint(x: p.x - n.x * h, y: p.y - n.y * h))
        }
        outline.closeSubpath()

        // Body of the stem: lit from the left.
        ctx.saveGState()
        ctx.addPath(outline)
        ctx.clip()
        let colors: [CGColor] = [LeafArt.lighter(look.stem), look.stem, look.stemDark]
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.45, 1]) {
            let box = outline.boundingBoxOfPath
            ctx.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: 0), end: CGPoint(x: box.maxX, y: 0), options: [])
        }
        // Ridges running up the stem.
        ctx.setStrokeColor(look.stemDark.withAlpha(0.65))
        ctx.setLineWidth(max(0.4, baseWidth / 12))
        for offset in [-0.45, 0.0, 0.4] as [CGFloat] {
            let ridge = CGMutablePath()
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p = point(t), n = normal(t), h = halfWidth(t) * offset
                let q = CGPoint(x: p.x + n.x * h, y: p.y + n.y * h)
                if i == 0 { ridge.move(to: q) } else { ridge.addLine(to: q) }
            }
            ctx.addPath(ridge)
        }
        ctx.strokePath()
        ctx.restoreGState()

        // The dried, cut end.
        let capW = topWidth * 1.05
        let cap = CGRect(x: tip.x - capW / 2, y: tip.y - capW * 0.22, width: capW, height: capW * 0.44)
        ctx.setFillColor(CGColor.hex(0xC9A27A))
        ctx.fillEllipse(in: cap)
        ctx.setStrokeColor(look.stemDark)
        ctx.setLineWidth(max(0.4, baseWidth / 14))
        ctx.strokeEllipse(in: cap)
    }

    /// A soft contact shadow that sits under each pumpkin.
    static func shadowTexture(width: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "shadow-\(Int(width))-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: width, height: max(4, width * 0.22))
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor] = [CGColor.hex(0x1E0E04, alpha: 0.42), CGColor.hex(0x1E0E04, alpha: 0)]
            guard let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) else { return }
            ctx.scaleBy(x: 1, y: size.height / size.width)
            let c = CGPoint(x: size.width / 2, y: size.width / 2)
            ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
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
            ctx.setFillColor(look.stripe != nil && variant % 3 == 0 ? look.stripe! : look.body)
            ctx.fillPath()
            // A strip of soft inner flesh on one edge.
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.setFillColor(Palette.golden.withAlpha(0.55))
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size * 0.28))
            ctx.restoreGState()
            TextureMaker.speckle(ctx, clip: path, in: CGRect(origin: .zero, size: s),
                                 dark: look.speckDark, light: look.speckLight, density: 0.12, rng: &rng)
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
            ctx.setFillColor(kind.look.body.withAlpha(0.8))
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

// MARK: - Leaves, acorns and berries

enum LeafKind: CaseIterable {
    case maple, mapleRed, oval, ginkgo, acorn, berries

    static let fallers: [LeafKind] = [.maple, .mapleRed, .oval, .ginkgo]
}

enum LeafArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ kind: LeafKind, size: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let key = "\(kind)-\(Int(size))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let s = CGSize(width: size, height: size)
        let texture = TextureMaker.make(size: s, scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(variant) &* 31337 &+ 5)
            switch kind {
            case .maple: drawMaple(ctx, size: size, color: variant % 2 == 0 ? Palette.maple : Palette.golden, rng: &rng)
            case .mapleRed: drawMaple(ctx, size: size, color: Palette.mapleRed, rng: &rng)
            case .oval: drawOval(ctx, size: size, color: variant % 2 == 0 ? Palette.sage : Palette.rust, rng: &rng)
            case .ginkgo: drawGinkgo(ctx, size: size, rng: &rng)
            case .acorn: drawAcorn(ctx, size: size, rng: &rng)
            case .berries: drawBerries(ctx, size: size, rng: &rng)
            }
        }
        cache[key] = texture
        return texture
    }

    static func darker(_ c: CGColor) -> CGColor {
        guard let comps = c.components, comps.count >= 3 else { return c }
        return CGColor(srgbRed: comps[0] * 0.68, green: comps[1] * 0.6, blue: comps[2] * 0.55, alpha: 1)
    }

    static func lighter(_ c: CGColor) -> CGColor {
        guard let comps = c.components, comps.count >= 3 else { return c }
        return CGColor(srgbRed: min(1, comps[0] * 1.1 + 0.08), green: min(1, comps[1] * 1.1 + 0.1), blue: min(1, comps[2] * 1.1 + 0.1), alpha: 1)
    }

    private static func drawMaple(_ ctx: CGContext, size: CGFloat, color: CGColor, rng: inout SeededRandom) {
        let c = CGPoint(x: size / 2, y: size * 0.45)
        let path = CGMutablePath()
        let steps = 90
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let a = t * .pi * 2 + .pi / 2
            // Five pointed lobes with little teeth, missing the bottom (where the stem goes).
            let lobe = pow(abs(cos(2.5 * (a - .pi / 2))), 0.6)
            let teeth = 0.06 * abs(sin(a * 15))
            let bottomNotch = max(0, -sin(a)) // ~1 at the bottom
            let r = size * 0.48 * (0.45 + 0.55 * lobe + teeth) * (1 - 0.45 * pow(bottomNotch, 6))
            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
        TextureMaker.speckle(ctx, clip: path, in: CGRect(x: 0, y: 0, width: size, height: size),
                             dark: darker(color), light: lighter(color), density: 0.1, rng: &rng)
        // Veins and stem.
        ctx.setStrokeColor(darker(color))
        ctx.setLineWidth(max(0.5, size / 40))
        for k in 0..<5 {
            let a = CGFloat.pi / 2 + CGFloat(k - 2) * (2 * .pi / 5)
            ctx.move(to: c)
            ctx.addLine(to: CGPoint(x: c.x + cos(a) * size * 0.36, y: c.y + sin(a) * size * 0.36))
        }
        ctx.move(to: c)
        ctx.addLine(to: CGPoint(x: c.x + size * 0.05, y: size * 0.02))
        ctx.strokePath()
    }

    private static func drawOval(_ ctx: CGContext, size: CGFloat, color: CGColor, rng: inout SeededRandom) {
        let path = CGMutablePath()
        let bottom = CGPoint(x: size * 0.5, y: size * 0.14)
        let top = CGPoint(x: size * 0.5, y: size * 0.98)
        path.move(to: bottom)
        path.addQuadCurve(to: top, control: CGPoint(x: size * 1.02, y: size * 0.5))
        path.addQuadCurve(to: bottom, control: CGPoint(x: -size * 0.02, y: size * 0.5))
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
        TextureMaker.speckle(ctx, clip: path, in: CGRect(x: 0, y: 0, width: size, height: size),
                             dark: darker(color), light: lighter(color), density: 0.1, rng: &rng)
        ctx.setStrokeColor(darker(color))
        ctx.setLineWidth(max(0.5, size / 40))
        ctx.move(to: CGPoint(x: size * 0.5, y: 0))
        ctx.addLine(to: CGPoint(x: size * 0.5, y: size * 0.9))
        for k in 1...4 {
            let y = size * (0.2 + CGFloat(k) * 0.15)
            ctx.move(to: CGPoint(x: size * 0.5, y: y))
            ctx.addLine(to: CGPoint(x: size * 0.28, y: y + size * 0.1))
            ctx.move(to: CGPoint(x: size * 0.5, y: y))
            ctx.addLine(to: CGPoint(x: size * 0.72, y: y + size * 0.1))
        }
        ctx.strokePath()
    }

    private static func drawGinkgo(_ ctx: CGContext, size: CGFloat, rng: inout SeededRandom) {
        let color = Palette.golden
        let base = CGPoint(x: size * 0.5, y: size * 0.3)
        let path = CGMutablePath()
        path.move(to: base)
        path.addLine(to: CGPoint(x: size * 0.06, y: size * 0.72))
        path.addQuadCurve(to: CGPoint(x: size * 0.46, y: size * 0.92), control: CGPoint(x: size * 0.18, y: size * 0.98))
        path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.82))
        path.addLine(to: CGPoint(x: size * 0.54, y: size * 0.92))
        path.addQuadCurve(to: CGPoint(x: size * 0.94, y: size * 0.72), control: CGPoint(x: size * 0.82, y: size * 0.98))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
        ctx.setStrokeColor(darker(color).withAlpha(0.6))
        ctx.setLineWidth(max(0.4, size / 60))
        for k in 0..<9 {
            let a = CGFloat.pi * (0.22 + 0.56 * CGFloat(k) / 8)
            ctx.move(to: base)
            ctx.addLine(to: CGPoint(x: base.x - cos(a) * size * 0.58, y: base.y + sin(a) * size * 0.58))
        }
        ctx.strokePath()
        ctx.setStrokeColor(Palette.stemBrown)
        ctx.setLineWidth(max(0.6, size / 35))
        ctx.move(to: base)
        ctx.addQuadCurve(to: CGPoint(x: size * 0.62, y: 0), control: CGPoint(x: size * 0.52, y: size * 0.12))
        ctx.strokePath()
        _ = rng.next()
    }

    private static func drawAcorn(_ ctx: CGContext, size: CGFloat, rng: inout SeededRandom) {
        let nut = CGRect(x: size * 0.22, y: size * 0.05, width: size * 0.56, height: size * 0.62)
        let nutPath = CGPath(ellipseIn: nut, transform: nil)
        ctx.addPath(nutPath)
        ctx.setFillColor(Palette.acorn)
        ctx.fillPath()
        TextureMaker.speckle(ctx, clip: nutPath, in: nut, dark: darker(Palette.acorn), light: lighter(Palette.acorn),
                             density: 0.08, rng: &rng)
        let cap = CGRect(x: size * 0.16, y: size * 0.5, width: size * 0.68, height: size * 0.34)
        let capPath = CGPath(ellipseIn: cap, transform: nil)
        ctx.addPath(capPath)
        ctx.setFillColor(Palette.acornCap)
        ctx.fillPath()
        // Cross-hatch on the cap.
        ctx.saveGState()
        ctx.addPath(capPath)
        ctx.clip()
        ctx.setStrokeColor(darker(Palette.acornCap))
        ctx.setLineWidth(max(0.4, size / 60))
        var x = -size
        while x < size * 2 {
            ctx.move(to: CGPoint(x: x, y: cap.minY))
            ctx.addLine(to: CGPoint(x: x + cap.height, y: cap.maxY))
            ctx.move(to: CGPoint(x: x + cap.height, y: cap.minY))
            ctx.addLine(to: CGPoint(x: x, y: cap.maxY))
            x += size * 0.1
        }
        ctx.strokePath()
        ctx.restoreGState()
        ctx.setStrokeColor(Palette.stemBrownDark)
        ctx.setLineWidth(max(1, size / 14))
        ctx.move(to: CGPoint(x: size * 0.5, y: cap.maxY - 1))
        ctx.addLine(to: CGPoint(x: size * 0.56, y: size * 0.97))
        ctx.strokePath()
    }

    private static func drawBerries(_ ctx: CGContext, size: CGFloat, rng: inout SeededRandom) {
        ctx.setStrokeColor(Palette.stemBrown)
        ctx.setLineWidth(max(0.6, size / 30))
        let joint = CGPoint(x: size * 0.5, y: size * 0.88)
        let berries = [CGPoint(x: size * 0.28, y: size * 0.3), CGPoint(x: size * 0.55, y: size * 0.22), CGPoint(x: size * 0.74, y: size * 0.42)]
        for b in berries {
            ctx.move(to: joint)
            ctx.addQuadCurve(to: b, control: CGPoint(x: (joint.x + b.x) / 2 + size * 0.05, y: (joint.y + b.y) / 2 + size * 0.1))
        }
        ctx.strokePath()
        for b in berries {
            let r = size * rng.float(0.15...0.19)
            let rect = CGRect(x: b.x - r, y: b.y - r * 1.15, width: r * 2, height: r * 2.3)
            let p = CGPath(ellipseIn: rect, transform: nil)
            ctx.addPath(p)
            ctx.setFillColor(Palette.berry)
            ctx.fillPath()
            TextureMaker.speckle(ctx, clip: p, in: rect, dark: darker(Palette.berry), light: lighter(Palette.berry),
                                 density: 0.1, rng: &rng)
            ctx.setFillColor(Palette.stemBrownDark)
            ctx.fillEllipse(in: CGRect(x: b.x - 0.8, y: rect.minY - 0.4, width: 1.6, height: 1.6))
        }
    }
}

// MARK: - Vines

/// A leafy pumpkin vine that runs along the top of the Dock, with big lobed leaves,
/// curly tendrils and a few golden blossoms.
enum VineArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(width: CGFloat, height: CGFloat, seed: Int, scale: CGFloat) -> SKTexture {
        let key = "vine-\(Int(width))-\(Int(height))-\(seed)-\(scale)"
        if let cached = cache[key] { return cached }
        if cache.count > 40 { cache.removeAll() }
        let size = CGSize(width: width, height: height)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            draw(ctx, size: size, seed: seed)
        }
        cache[key] = texture
        return texture
    }

    private static func vineY(_ x: CGFloat, size: CGSize, phase: CGFloat) -> CGFloat {
        size.height * 0.1 + sin(x / size.height * 1.7 + phase) * size.height * 0.05
    }

    private static func draw(_ ctx: CGContext, size: CGSize, seed: Int) {
        var rng = SeededRandom(seed: UInt64(seed) &* 6151 &+ 3)
        let phase = rng.float(0...6)
        let h = size.height

        // Leaves first (they grow behind the vine), spaced along its length.
        var x = rng.float(h * 0.1...h * 0.4)
        var leaves: [(CGPoint, CGFloat, CGFloat)] = []
        while x < size.width - h * 0.2 {
            let leafSize = h * rng.float(0.5...0.85)
            let tilt = rng.float(-0.55...0.55)
            leaves.append((CGPoint(x: x, y: vineY(x, size: size, phase: phase)), leafSize, tilt))
            x += h * rng.float(0.55...0.95)
        }
        for (i, leaf) in leaves.enumerated() {
            drawLeaf(ctx, at: leaf.0, size: leaf.1, tilt: leaf.2, variant: i, rng: &rng)
        }

        // The main vine.
        let vine = CGMutablePath()
        let steps = max(8, Int(size.width / 6))
        for i in 0...steps {
            let px = size.width * CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: px, y: vineY(px, size: size, phase: phase))
            if i == 0 { vine.move(to: p) } else { vine.addLine(to: p) }
        }
        ctx.setLineCap(.round)
        ctx.setStrokeColor(Palette.vineDark)
        ctx.setLineWidth(max(2, h * 0.07))
        ctx.addPath(vine)
        ctx.strokePath()
        ctx.setStrokeColor(Palette.vine)
        ctx.setLineWidth(max(1.2, h * 0.045))
        ctx.addPath(vine)
        ctx.strokePath()

        // Curly tendrils between the leaves.
        for i in 0..<max(0, leaves.count - 1) {
            guard i % 2 == 0 || rng.float(0...1) < 0.4 else { continue }
            let px = (leaves[i].0.x + leaves[i + 1].0.x) / 2
            let start = CGPoint(x: px, y: vineY(px, size: size, phase: phase))
            drawTendril(ctx, from: start, size: h * rng.float(0.22...0.34), dir: i % 2 == 0 ? 1 : -1)
        }

        // A few golden pumpkin blossoms.
        for i in stride(from: 1, to: leaves.count, by: 4) {
            let px = leaves[i].0.x + h * 0.15
            guard px < size.width - h * 0.2 else { continue }
            drawBlossom(ctx, at: CGPoint(x: px, y: vineY(px, size: size, phase: phase) + h * 0.12), size: h * 0.26, rng: &rng)
        }
    }

    /// A big, lobed pumpkin leaf on a short stalk, with light veins.
    private static func drawLeaf(_ ctx: CGContext, at base: CGPoint, size: CGFloat, tilt: CGFloat, variant: Int, rng: inout SeededRandom) {
        ctx.saveGState()
        ctx.translateBy(x: base.x, y: base.y)
        ctx.rotate(by: tilt)

        // Stalk.
        let stalkTop = CGPoint(x: size * 0.04, y: size * 0.32)
        ctx.setStrokeColor(Palette.vine)
        ctx.setLineWidth(max(0.8, size / 22))
        ctx.move(to: .zero)
        ctx.addQuadCurve(to: stalkTop, control: CGPoint(x: -size * 0.06, y: size * 0.16))
        ctx.strokePath()

        // Leaf blade: five rounded, gently serrated lobes.
        let c = CGPoint(x: stalkTop.x, y: stalkTop.y + size * 0.3)
        let r = size * 0.36
        let blade = CGMutablePath()
        let steps = 120
        for i in 0...steps {
            let a = CGFloat(i) / CGFloat(steps) * .pi * 2 + .pi / 2
            let lobe = pow(abs(cos(2.5 * (a - .pi / 2))), 0.7)
            let teeth = 0.035 * sin(a * 34)
            let notch = pow(max(0, -sin(a)), 8)
            let rr = r * (0.7 + 0.3 * lobe + teeth) * (1 - 0.55 * notch)
            let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr * 0.92)
            if i == 0 { blade.move(to: p) } else { blade.addLine(to: p) }
        }
        blade.closeSubpath()

        let colors: [CGColor] = [Palette.pumpkinLeafLight, Palette.pumpkinLeaf, Palette.leafGreen]
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ctx.saveGState()
        ctx.addPath(blade)
        ctx.clip()
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 0.55, 1]) {
            let hl = CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.3)
            ctx.drawRadialGradient(gradient, startCenter: hl, startRadius: 0, endCenter: c, endRadius: r * 1.15,
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
        let bladeRect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        TextureMaker.speckle(ctx, clip: blade, in: bladeRect, dark: Palette.stemGreenDark,
                             light: Palette.pumpkinLeafLight, density: 0.05, rng: &rng)

        // Veins.
        ctx.setStrokeColor(CGColor.hex(0xC9D98F, alpha: 0.75))
        ctx.setLineWidth(max(0.4, size / 55))
        let veinStart = CGPoint(x: c.x, y: c.y - r * 0.5)
        for k in 0..<5 {
            let a = CGFloat.pi / 2 + CGFloat(k - 2) * (2 * .pi / 5) * 0.8
            let end = CGPoint(x: c.x + cos(a) * r * 0.85, y: c.y + sin(a) * r * 0.8)
            ctx.move(to: veinStart)
            ctx.addQuadCurve(to: end, control: CGPoint(x: (veinStart.x + end.x) / 2, y: (veinStart.y + end.y) / 2 + r * 0.08))
        }
        ctx.strokePath()
        ctx.restoreGState()
        _ = variant
    }

    private static func drawTendril(_ ctx: CGContext, from start: CGPoint, size: CGFloat, dir: CGFloat) {
        let path = CGMutablePath()
        path.move(to: start)
        let lift = CGPoint(x: start.x + dir * size * 0.5, y: start.y + size * 0.9)
        path.addQuadCurve(to: lift, control: CGPoint(x: start.x + dir * size * 0.05, y: start.y + size * 0.7))
        // A spiral that winds inward.
        let center = CGPoint(x: lift.x + dir * size * 0.28, y: lift.y)
        let turns: CGFloat = 1.6
        let steps = 40
        let startAngle: CGFloat = dir > 0 ? .pi : 0
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = startAngle - dir * t * turns * 2 * .pi
            let radius = size * 0.28 * (1 - t * 0.85)
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        }
        ctx.setStrokeColor(Palette.vine)
        ctx.setLineWidth(max(0.6, size / 14))
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawBlossom(_ ctx: CGContext, at c: CGPoint, size: CGFloat, rng: inout SeededRandom) {
        let petals = 5
        let start = rng.float(0...1)
        for k in 0..<petals {
            let a = start + CGFloat(k) / CGFloat(petals) * .pi * 2
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: a)
            ctx.setFillColor(Palette.blossom)
            ctx.fillEllipse(in: CGRect(x: 0, y: -size * 0.17, width: size * 0.55, height: size * 0.34))
            ctx.setStrokeColor(CGColor.hex(0xD98A1E, alpha: 0.8))
            ctx.setLineWidth(max(0.4, size / 30))
            ctx.move(to: CGPoint(x: size * 0.08, y: 0))
            ctx.addLine(to: CGPoint(x: size * 0.45, y: 0))
            ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.setFillColor(CGColor.hex(0xD98A1E))
        ctx.fillEllipse(in: CGRect(x: c.x - size * 0.1, y: c.y - size * 0.1, width: size * 0.2, height: size * 0.2))
    }
}
