import AppKit
import SpriteKit

// The cozy extras that fill the gaps between pumpkins: hay bales, leaf piles, acorns,
// a pumpkin spice latte, a lantern, a crate of apples and a visiting squirrel.
// Same flat harvest-wagon style as the pumpkins: wagon colors, flat fills, a darker side,
// tapered brush strokes and no outlines.

enum DecorKind: String, CaseIterable {
    // Fall.
    case hayBale, leafPile, acorns, mug, lantern, apples
    // Halloween (drawn in SpookyArt).
    case crypt, tombstone, blackCat, cauldron, candy, candles, skull

    var title: String {
        switch self {
        case .hayBale: return "Hay bales"
        case .leafPile: return "Leaf piles"
        case .acorns: return "Acorns"
        case .mug: return "Pumpkin spice latte"
        case .lantern: return "Lantern"
        case .apples: return "Crate of apples"
        case .crypt: return "Crypt pedestals"
        case .tombstone: return "Tombstones"
        case .blackCat: return "Black cat"
        case .cauldron: return "Cauldron"
        case .candy: return "Candy"
        case .candles: return "Candles"
        case .skull: return "Skull"
        }
    }

    var isSpooky: Bool { Settings.Theme.halloween.extras.contains(self) }
}

enum CozyArt {
    private static var cache: [String: SKTexture] = [:]
    static func clearCache() { cache.removeAll() }

    private static var straw: CGColor { Palette.mustard.mixed(with: Palette.peach, 0.18) }
    private static var strawLight: CGColor { Palette.mustard.mixed(with: Palette.peach, 0.5) }
    private static var strawDark: CGColor { Palette.mustard.mixed(with: Palette.rust, 0.38) }
    private static var bark: CGColor { Palette.rust.mixed(with: Palette.plum, 0.55) }
    private static var wood: CGColor { Palette.rust.mixed(with: Palette.peach, 0.22) }

    /// Point size of a decoration for pumpkins `h` points tall.
    static func size(of kind: DecorKind, unit h: CGFloat) -> CGSize {
        let s: CGSize
        switch kind {
        case .hayBale: s = CGSize(width: h * 1.4, height: h * 0.52)
        case .leafPile: s = CGSize(width: h * 0.95, height: h * 0.42)
        case .acorns: s = CGSize(width: h * 0.62, height: h * 0.4)
        case .mug: s = CGSize(width: h * 0.46, height: h * latteHeight)
        case .lantern: s = CGSize(width: h * 0.46, height: h * 0.82)
        case .apples: s = CGSize(width: h * 0.92, height: h * 0.58)
        case .crypt: s = CGSize(width: h * 1.2, height: h * 0.52)
        case .tombstone: s = CGSize(width: h * 0.6, height: h * 0.72)
        case .blackCat: s = CGSize(width: h * 0.7, height: h * 0.82)
        case .cauldron: s = CGSize(width: h * 0.82, height: h * 0.64)
        case .candy: s = CGSize(width: h * 0.95, height: h * 0.66)
        case .candles: s = CGSize(width: h * 0.58, height: h * 0.66)
        case .skull: s = CGSize(width: h * 0.66, height: h * 0.5)
        }
        return CGSize(width: s.width.rounded(), height: s.height.rounded())
    }

    static func texture(_ kind: DecorKind, unit h: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let size = size(of: kind, unit: h)
        let key = "\(kind)-\(Int(h))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        if cache.count > 120 { cache.removeAll() }
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(variant + 1) &* 4241 &+ UInt64(DecorKind.allCases.firstIndex(of: kind) ?? 0))
            switch kind {
            case .hayBale: drawHayBale(ctx, size: size, h: h, rng: &rng)
            case .leafPile: drawLeafPile(ctx, size: size, h: h, rng: &rng)
            case .acorns: drawAcorns(ctx, size: size, h: h)
            case .mug: drawMug(ctx, size: size, h: h)
            case .lantern: drawLantern(ctx, size: size, h: h)
            case .apples: drawApples(ctx, size: size, h: h, rng: &rng)
            case .crypt, .tombstone, .blackCat, .cauldron, .candy, .candles, .skull:
                SpookyArt.draw(kind, ctx, size: size, h: h, rng: &rng)
            }
        }
        cache[key] = texture
        return texture
    }

    // MARK: Hay bale

    private static func drawHayBale(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        let front = CGRect(x: 1, y: 1, width: w - 2, height: ht * 0.78)
        let top = CGRect(x: 4, y: ht * 0.6, width: w - 8, height: ht * 0.38)
        let frontPath = CGPath(roundedRect: front, cornerWidth: ht * 0.14, cornerHeight: ht * 0.14, transform: nil)

        // Top face, lighter, then the front.
        ctx.addPath(CGPath(roundedRect: top, cornerWidth: ht * 0.12, cornerHeight: ht * 0.12, transform: nil))
        ctx.setFillColor(strawLight)
        ctx.fillPath()
        ctx.addPath(frontPath)
        ctx.setFillColor(straw)
        ctx.fillPath()

        // A darker end on the right, like the pumpkins' side lobes.
        ctx.saveGState()
        ctx.addPath(frontPath)
        ctx.clip()
        ctx.setFillColor(straw.mixed(with: Palette.rust, 0.2))
        ctx.fill(CGRect(x: w * 0.86, y: 0, width: w * 0.14, height: ht))

        // Loose straw.
        let lw = max(0.8, h * 0.016)
        for _ in 0..<Int(w * ht / 55) {
            let x = rng.float(front.minX...front.maxX), y = rng.float(front.minY...front.maxY)
            let len = rng.float(0.06...0.14) * w
            let tilt = rng.float(-0.1...0.1) * len
            let color = rng.float(0...1) < 0.7 ? strawDark : strawLight
            Brush.stroke(ctx, [CGPoint(x: x, y: y), CGPoint(x: x + len / 2, y: y + tilt), CGPoint(x: x + len, y: y + tilt * 0.4)],
                         maxWidth: lw, color: color, minF: 0.2)
        }
        ctx.restoreGState()

        // Straw on top, running front to back.
        for _ in 0..<Int(w / 6) {
            let x = rng.float(top.minX + 4...top.maxX - 4), y = rng.float(top.minY + top.height * 0.45...top.maxY - 2)
            let len = rng.float(4...9) * h / 60
            Brush.stroke(ctx, [CGPoint(x: x, y: y), CGPoint(x: x + len * 0.3, y: y + len * 0.5), CGPoint(x: x + len * 0.2, y: y + len)],
                         maxWidth: lw, color: strawDark, minF: 0.3)
        }

        // Twine.
        for fx in [CGFloat(0.27), 0.73] {
            let x = w * fx
            Brush.stroke(ctx, [CGPoint(x: x, y: 2), CGPoint(x: x + 1, y: ht * 0.4), CGPoint(x: x, y: front.maxY - 1)],
                         maxWidth: h * 0.035, color: Palette.rust, minF: 0.8)
            Brush.stroke(ctx, [CGPoint(x: x, y: front.maxY - 1), CGPoint(x: x + 1.5, y: ht * 0.86), CGPoint(x: x + 1, y: top.maxY - 2)],
                         maxWidth: h * 0.03, color: Palette.rust.mixed(with: Palette.plum, 0.3), minF: 0.6, endF: 0.4)
        }

        // Tufts poking out of the ends.
        for (x, dir) in [(front.minX + 2, CGFloat(-1)), (front.maxX - 2, CGFloat(1))] {
            for i in 0..<4 {
                let y = ht * (0.18 + CGFloat(i) * 0.16)
                let len = rng.float(4...7) * h / 60
                Brush.stroke(ctx, [CGPoint(x: x - dir * 2, y: y), CGPoint(x: x + dir * len * 0.6, y: y + len * 0.2),
                                   CGPoint(x: x + dir * len, y: y + rng.float(-2...3))],
                             maxWidth: lw * 1.2, color: strawDark, minF: 0.5, endF: 0.1)
            }
        }
    }

    // MARK: Leaf pile

    private static func drawLeafPile(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        let kinds: [LeafKind] = [.oak, .oak, .ovate, .ovate, .plum, .oak, .serrated, .ovate]
        // Bottom leaves first, so the pile builds up into a mound.
        for row in 0..<4 {
            let count = 5 - row
            let rowY = ht * (0.18 + CGFloat(row) * 0.17)
            let halfWidth = w * 0.42 * sqrt(max(0.05, 1 - pow(CGFloat(row) / 3.6, 2)))
            for i in 0..<count {
                let t = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
                let length = h * rng.float(0.2...0.27)
                let x = w / 2 - halfWidth + t * halfWidth * 2 + rng.float(-3...3)
                let y = rowY + rng.float(-2...2)
                let kind = kinds[Int(rng.float(0...7.99))]
                LeafArt.drawWagonLeaf(ctx, kind: kind,
                                      at: CGPoint(x: min(w - length * 0.45, max(length * 0.45, x)), y: y),
                                      length: length, angle: rng.float(0...360), flip: rng.float(0...1) < 0.5)
            }
        }
    }

    // MARK: Acorns

    private static func drawAcorns(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width
        let s = h * 0.32
        acorn(ctx, bottom: CGPoint(x: w * 0.3, y: 1), size: s, angle: 6)
        acorn(ctx, bottom: CGPoint(x: w * 0.56, y: 1), size: s * 0.86, angle: -8)
        // One lying on its side in front.
        acorn(ctx, bottom: CGPoint(x: w * 0.7, y: s * 0.27), size: s * 0.78, angle: -78)
    }

    /// An acorn standing on `bottom`, tilted `angle` degrees.
    private static func acorn(_ ctx: CGContext, bottom: CGPoint, size s: CGFloat, angle: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: bottom.x, y: bottom.y)
        ctx.rotate(by: angle * .pi / 180)
        let nutW = s * 0.62, nutH = s * 0.72
        let nut = CGMutablePath()
        nut.move(to: CGPoint(x: 0, y: 0))
        nut.addCurve(to: CGPoint(x: nutW / 2, y: nutH * 0.62), control1: CGPoint(x: nutW * 0.26, y: 0), control2: CGPoint(x: nutW / 2, y: nutH * 0.3))
        nut.addLine(to: CGPoint(x: -nutW / 2, y: nutH * 0.62))
        nut.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: -nutW / 2, y: nutH * 0.3), control2: CGPoint(x: -nutW * 0.26, y: 0))
        nut.closeSubpath()
        ctx.addPath(nut)
        ctx.setFillColor(Palette.rust.mixed(with: Palette.mustard, 0.4))
        ctx.fillPath()
        // Darker right side.
        ctx.saveGState()
        ctx.addPath(nut)
        ctx.clip()
        ctx.setFillColor(Palette.rust.mixed(with: Palette.mustard, 0.1))
        ctx.fillEllipse(in: CGRect(x: nutW * 0.12, y: -nutH * 0.1, width: nutW * 0.6, height: nutH * 0.9))
        ctx.restoreGState()

        // Cap with a little crosshatch, and a stem.
        let cap = CGRect(x: -nutW * 0.6, y: nutH * 0.5, width: nutW * 1.2, height: s * 0.36)
        ctx.addPath(CGPath(ellipseIn: cap, transform: nil))
        ctx.setFillColor(bark)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addEllipse(in: cap)
        ctx.clip()
        for i in 0..<4 {
            let x = cap.minX + cap.width * (0.2 + CGFloat(i) * 0.2)
            Brush.stroke(ctx, [CGPoint(x: x - s * 0.06, y: cap.midY - s * 0.06), CGPoint(x: x, y: cap.midY + s * 0.02),
                               CGPoint(x: x + s * 0.06, y: cap.midY - s * 0.06)],
                         maxWidth: max(0.8, s * 0.05), color: Palette.plum, minF: 0.4)
        }
        ctx.restoreGState()
        Brush.stroke(ctx, [CGPoint(x: 0, y: cap.maxY - s * 0.04), CGPoint(x: s * 0.03, y: cap.maxY + s * 0.06),
                           CGPoint(x: s * 0.09, y: cap.maxY + s * 0.1)],
                     maxWidth: s * 0.08, color: Palette.plum, minF: 0.7)
        ctx.restoreGState()
    }

    // MARK: Pumpkin spice latte

    /// The latte's height for pumpkins `h` points tall, as a fraction of `h`.
    static let latteHeight: CGFloat = 0.66
    /// Where the lid's sip hole is (steam comes out there), as a fraction of the latte's size.
    static let latteSteam = CGPoint(x: 0.62, y: 0.86)

    /// A takeaway cup: cream paper, an orange sleeve with a little pumpkin on it, and a plum lid.
    private static func drawMug(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        // The cup widens toward the top.
        let cup = CGMutablePath()
        cup.addLines(between: [p(0.24, 0.02), p(0.76, 0.02), p(0.88, 0.76), p(0.12, 0.76)])
        cup.closeSubpath()
        ctx.addPath(cup)
        ctx.setFillColor(Palette.peach)
        ctx.fillPath()

        ctx.saveGState()
        ctx.addPath(cup)
        ctx.clip()
        // The sleeve.
        let sleeve = Palette.orange.mixed(with: Palette.rust, 0.35)
        ctx.setFillColor(sleeve)
        ctx.fill(CGRect(x: 0, y: ht * 0.2, width: w, height: ht * 0.32))
        // Darker right side, like everything else.
        ctx.setFillColor(Palette.shadowInk.withAlpha(0.16))
        ctx.fill(CGRect(x: w * 0.66, y: 0, width: w * 0.4, height: ht))
        ctx.restoreGState()

        // A little pumpkin on the sleeve.
        let c = p(0.46, 0.36)
        let r = w * 0.1
        ctx.setFillColor(Palette.orange.mixed(with: Palette.mustard, 0.25))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 1.3, y: c.y - r * 0.85, width: r * 1.6, height: r * 1.7))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.85, width: r * 1.6, height: r * 1.7))
        ctx.setFillColor(Palette.mustard.mixed(with: Palette.peach, 0.2))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.75, y: c.y - r * 0.9, width: r * 1.5, height: r * 1.8))
        Brush.stroke(ctx, [CGPoint(x: c.x, y: c.y + r * 0.8), CGPoint(x: c.x + r * 0.1, y: c.y + r * 1.1),
                           CGPoint(x: c.x + r * 0.35, y: c.y + r * 1.3)],
                     maxWidth: r * 0.4, color: Palette.green, minF: 0.7)

        // The lid: a rim, a raised top and a sip hole.
        let lid = Palette.plum.mixed(with: Palette.rust, 0.2)
        ctx.setFillColor(lid)
        ctx.addPath(CGPath(roundedRect: CGRect(x: w * 0.06, y: ht * 0.74, width: w * 0.88, height: ht * 0.08),
                           cornerWidth: ht * 0.03, cornerHeight: ht * 0.03, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(lid.mixed(with: Palette.peach, 0.15))
        ctx.addPath(CGPath(roundedRect: CGRect(x: w * 0.16, y: ht * 0.8, width: w * 0.68, height: ht * 0.1),
                           cornerWidth: ht * 0.04, cornerHeight: ht * 0.04, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(Palette.shadowInk)
        ctx.fillEllipse(in: CGRect(x: w * latteSteam.x - w * 0.07, y: ht * latteSteam.y - ht * 0.012, width: w * 0.14, height: ht * 0.03))
        // A sprinkle of cinnamon on the sleeve's edge, for fun.
        ctx.setFillColor(Palette.rust.mixed(with: Palette.plum, 0.4))
        for (x, y) in [(0.3, 0.5), (0.36, 0.47), (0.6, 0.49), (0.67, 0.46), (0.52, 0.23)] {
            ctx.fillEllipse(in: CGRect(x: w * CGFloat(x), y: ht * CGFloat(y), width: w * 0.035, height: w * 0.035))
        }
    }

    private static func heart(_ ctx: CGContext, center c: CGPoint, size s: CGFloat, color: CGColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: c.x, y: c.y - s * 0.5))
        path.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.25), control1: CGPoint(x: c.x - s * 0.9, y: c.y), control2: CGPoint(x: c.x - s * 0.35, y: c.y + s * 0.75))
        path.addCurve(to: CGPoint(x: c.x, y: c.y - s * 0.5), control1: CGPoint(x: c.x + s * 0.35, y: c.y + s * 0.75), control2: CGPoint(x: c.x + s * 0.9, y: c.y))
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    // MARK: Lantern

    /// Where the flame sits in the lantern texture, as a fraction of its height.
    static let lanternFlameLevel: CGFloat = 0.36

    private static func drawLantern(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let metal = Palette.plum
        let glass = CGRect(x: w * 0.2, y: ht * 0.1, width: w * 0.6, height: ht * 0.5)

        // Warm glass, lighter in the middle.
        ctx.setFillColor(Palette.mustard.mixed(with: Palette.peach, 0.35))
        ctx.fill(glass)
        ctx.setFillColor(Palette.peach.mixed(with: Palette.mustard, 0.15))
        ctx.fill(glass.insetBy(dx: glass.width * 0.22, dy: glass.height * 0.12))

        // Candle and flame.
        let candle = CGRect(x: w * 0.4, y: glass.minY, width: w * 0.2, height: ht * 0.18)
        ctx.setFillColor(Palette.peach)
        ctx.fill(candle)
        let fy = ht * lanternFlameLevel
        let flame = CGMutablePath()
        flame.move(to: CGPoint(x: w / 2, y: fy + ht * 0.14))
        flame.addCurve(to: CGPoint(x: w / 2, y: fy - ht * 0.04), control1: CGPoint(x: w / 2 + w * 0.1, y: fy + ht * 0.04), control2: CGPoint(x: w / 2 + w * 0.09, y: fy - ht * 0.04))
        flame.addCurve(to: CGPoint(x: w / 2, y: fy + ht * 0.14), control1: CGPoint(x: w / 2 - w * 0.09, y: fy - ht * 0.04), control2: CGPoint(x: w / 2 - w * 0.1, y: fy + ht * 0.04))
        ctx.addPath(flame)
        ctx.setFillColor(Palette.orange)
        ctx.fillPath()
        ctx.setFillColor(Palette.mustard)
        ctx.fillEllipse(in: CGRect(x: w / 2 - w * 0.04, y: fy - ht * 0.02, width: w * 0.08, height: ht * 0.08))

        // Frame: base, corner posts, roof, knob and handle.
        ctx.setFillColor(metal)
        ctx.fill(CGRect(x: w * 0.12, y: 1, width: w * 0.76, height: ht * 0.1))
        for x in [glass.minX, glass.maxX] {
            Brush.stroke(ctx, [CGPoint(x: x, y: glass.minY), CGPoint(x: x, y: glass.midY), CGPoint(x: x, y: glass.maxY)],
                         maxWidth: h * 0.045, color: metal, minF: 1)
        }
        Brush.stroke(ctx, [CGPoint(x: w / 2, y: glass.minY), CGPoint(x: w / 2, y: glass.midY), CGPoint(x: w / 2, y: glass.maxY)],
                     maxWidth: h * 0.018, color: metal.withAlpha(0.6), minF: 1)
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: w * 0.08, y: glass.maxY))
        roof.addLine(to: CGPoint(x: w * 0.92, y: glass.maxY))
        roof.addLine(to: CGPoint(x: w * 0.66, y: ht * 0.74))
        roof.addLine(to: CGPoint(x: w * 0.34, y: ht * 0.74))
        roof.closeSubpath()
        ctx.addPath(roof)
        ctx.fillPath()
        ctx.setFillColor(metal.mixed(with: Palette.shadowInk, 0.4))
        ctx.fill(CGRect(x: w * 0.6, y: glass.maxY, width: w * 0.3, height: ht * 0.03))
        ctx.setFillColor(metal)
        ctx.fillEllipse(in: CGRect(x: w * 0.42, y: ht * 0.72, width: w * 0.16, height: ht * 0.07))
        ctx.setStrokeColor(metal)
        ctx.setLineWidth(h * 0.03)
        ctx.addArc(center: CGPoint(x: w / 2, y: ht * 0.78), radius: w * 0.2, startAngle: 0.15, endAngle: .pi - 0.15, clockwise: false)
        ctx.strokePath()
    }

    // MARK: Crate of apples

    private static func drawApples(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        let crate = CGRect(x: 1, y: 1, width: w - 2, height: ht * 0.52)
        let r = ht * 0.21
        let colors = [Palette.rust.mixed(with: Palette.orange, 0.2), Palette.rust, Palette.mustard, Palette.rust.mixed(with: Palette.orange, 0.2)]

        // Apples peeking over the top of the crate.
        for i in 0..<4 {
            let cx = crate.minX + crate.width * (0.16 + CGFloat(i) * 0.225) + rng.float(-2...2)
            let cy = crate.maxY + r * (i % 2 == 0 ? 0.25 : 0.5)
            apple(ctx, center: CGPoint(x: cx, y: cy), radius: r, color: colors[i], leaf: i == 1)
        }

        // The crate: slats with darker gaps and end posts.
        ctx.setFillColor(wood)
        ctx.fill(crate)
        ctx.setFillColor(wood.mixed(with: Palette.plum, 0.4))
        for f in [CGFloat(0.34), 0.67] {
            ctx.fill(CGRect(x: crate.minX, y: crate.minY + crate.height * f - 1, width: crate.width, height: max(1.5, ht * 0.035)))
        }
        ctx.setFillColor(wood.mixed(with: Palette.plum, 0.25))
        ctx.fill(CGRect(x: crate.minX, y: crate.minY, width: crate.width * 0.1, height: crate.height))
        ctx.fill(CGRect(x: crate.maxX - crate.width * 0.1, y: crate.minY, width: crate.width * 0.1, height: crate.height))
        // Wood grain.
        for _ in 0..<6 {
            let x = rng.float(crate.minX + crate.width * 0.14...crate.maxX - crate.width * 0.3)
            let y = rng.float(crate.minY + 3...crate.maxY - 3)
            let len = crate.width * rng.float(0.12...0.22)
            Brush.stroke(ctx, [CGPoint(x: x, y: y), CGPoint(x: x + len / 2, y: y + 0.6), CGPoint(x: x + len, y: y)],
                         maxWidth: max(0.8, h * 0.014), color: wood.mixed(with: Palette.plum, 0.3), minF: 0.2)
        }
    }

    private static func apple(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, color: CGColor, leaf: Bool) {
        let body = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 1.9)
        ctx.setFillColor(color)
        ctx.fillEllipse(in: body)
        ctx.saveGState()
        ctx.addEllipse(in: body)
        ctx.clip()
        ctx.setFillColor(color.mixed(with: Palette.plum, 0.3))
        ctx.fillEllipse(in: CGRect(x: c.x + r * 0.2, y: c.y - r * 1.1, width: r * 1.4, height: r * 2.2))
        ctx.restoreGState()
        ctx.setFillColor(Palette.peach.withAlpha(0.8))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y + r * 0.2, width: r * 0.32, height: r * 0.42))
        Brush.stroke(ctx, [CGPoint(x: c.x, y: c.y + r * 0.7), CGPoint(x: c.x + r * 0.05, y: c.y + r * 1.05),
                           CGPoint(x: c.x + r * 0.2, y: c.y + r * 1.25)],
                     maxWidth: r * 0.18, color: Palette.plum, minF: 0.7)
        if leaf {
            LeafArt.drawWagonLeaf(ctx, kind: .serrated, at: CGPoint(x: c.x + r * 0.6, y: c.y + r * 1.12), length: r * 1.2,
                                  angle: 20, flip: false)
        }
    }

    // MARK: Glow and steam

    /// A soft round glow, meant to be drawn with additive blending.
    static func glowTexture(color: CGColor, diameter: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "glow-\(color.components ?? [])-\(Int(diameter))-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: diameter, height: diameter)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: [color.withAlpha(0.75), color.withAlpha(0.25), color.withAlpha(0)] as CFArray,
                                            locations: [0, 0.4, 1]) else { return }
            let c = CGPoint(x: diameter / 2, y: diameter / 2)
            ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: diameter / 2, options: [])
        }
        cache[key] = texture
        return texture
    }

    /// A wisp of steam rising from the latte.
    static func steamTexture(unit h: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let size = CGSize(width: (h * 0.16).rounded(), height: (h * 0.36).rounded())
        let key = "steam-\(Int(h))-\(variant)-\(scale)"
        if let cached = cache[key] { return cached }
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let dir: CGFloat = variant % 2 == 0 ? 1 : -1
            Brush.stroke(ctx, [CGPoint(x: w / 2, y: 2), CGPoint(x: w / 2 + dir * w * 0.45, y: ht * 0.35),
                               CGPoint(x: w / 2 - dir * w * 0.45, y: ht * 0.65), CGPoint(x: w / 2, y: ht - 2)],
                         maxWidth: max(1.5, h * 0.045), color: Palette.peach, minF: 0.3, endF: 0.05)
        }
        cache[key] = texture
        return texture
    }

    // MARK: Squirrel

    /// The box the squirrel is drawn in, and the room left of and above it so the big curly tail
    /// (and its swish) isn't cut off.
    private static func squirrelBody(unit h: CGFloat) -> CGSize { CGSize(width: h * 0.62, height: h * 0.56) }
    private static func squirrelRoom(unit h: CGFloat) -> CGSize { CGSize(width: h * 0.14, height: h * 0.1) }

    /// The squirrel's size for pumpkins `h` points tall. The body and tail textures share it,
    /// so they line up when stacked.
    static func squirrelSize(unit h: CGFloat) -> CGSize {
        let body = squirrelBody(unit: h), room = squirrelRoom(unit: h)
        return CGSize(width: (body.width + room.width).rounded(), height: (body.height + room.height).rounded())
    }

    /// Where the tail joins the body, as a fraction of the squirrel's size.
    static func tailBase(unit h: CGFloat) -> CGPoint {
        let size = squirrelSize(unit: h), body = squirrelBody(unit: h), room = squirrelRoom(unit: h)
        return CGPoint(x: (room.width + body.width * 0.36) / size.width, y: body.height * 0.22 / size.height)
    }

    /// Where the squirrel's front paws are, measured from the middle of its bottom edge (facing right).
    static func squirrelPaws(unit h: CGFloat) -> CGPoint {
        let size = squirrelSize(unit: h), body = squirrelBody(unit: h), room = squirrelRoom(unit: h)
        return CGPoint(x: room.width + body.width * 0.8 - size.width / 2, y: body.height * 0.42)
    }

    /// One acorn, standing up, for the squirrel to carry.
    static func acornTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        let key = "acorn-\(Int(s * 10))-\(scale)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: s * 0.8, height: s)
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            acorn(ctx, bottom: CGPoint(x: size.width / 2, y: 0.5), size: s * 0.95, angle: 0)
        }
        cache[key] = texture
        return texture
    }

    private static var fur: CGColor { Palette.rust.mixed(with: Palette.orange, 0.3) }

    /// The squirrel's body, facing right.
    static func squirrelTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = squirrelSize(unit: h)
        let key = "squirrel-\(Int(h))-\(scale)"
        if let cached = cache[key] { return cached }
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let body = squirrelBody(unit: h)
            ctx.translateBy(x: squirrelRoom(unit: h).width, y: 0)
            let w = body.width, ht = body.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let furDark = fur.mixed(with: Palette.plum, 0.3)

            // Back leg and haunch.
            ctx.setFillColor(furDark)
            ctx.fillEllipse(in: CGRect(x: 0.36 * w, y: 0.02 * ht, width: 0.3 * w, height: 0.1 * ht))
            ctx.setFillColor(fur)
            ctx.fillEllipse(in: CGRect(x: 0.32 * w, y: 0.04 * ht, width: 0.36 * w, height: 0.44 * ht))
            // Body leaning forward, up to the head.
            Brush.stroke(ctx, [p(0.46, 0.2), p(0.58, 0.42), p(0.7, 0.6)], maxWidth: 0.3 * w, color: fur, minF: 0.85, endF: 0.6)
            // Belly.
            Brush.stroke(ctx, [p(0.56, 0.16), p(0.66, 0.36), p(0.72, 0.5)], maxWidth: 0.13 * w, color: Palette.peach, minF: 0.4, endF: 0.3)
            // Front paws holding something.
            Brush.stroke(ctx, [p(0.68, 0.42), p(0.78, 0.4), p(0.83, 0.44)], maxWidth: 0.07 * w, color: furDark, minF: 0.8, endF: 0.5)
            // Head, ear, snout, eye and nose.
            ctx.setFillColor(fur)
            ctx.fillEllipse(in: CGRect(x: 0.62 * w, y: 0.54 * ht, width: 0.27 * w, height: 0.3 * ht))
            Brush.stroke(ctx, [p(0.7, 0.78), p(0.69, 0.88), p(0.66, 0.97)], maxWidth: 0.09 * w, color: furDark, minF: 0.9, endF: 0.2)
            ctx.setFillColor(fur)
            ctx.fillEllipse(in: CGRect(x: 0.8 * w, y: 0.58 * ht, width: 0.17 * w, height: 0.16 * ht))
            ctx.setFillColor(Palette.peach)
            ctx.fillEllipse(in: CGRect(x: 0.82 * w, y: 0.57 * ht, width: 0.11 * w, height: 0.08 * ht))
            ctx.setFillColor(Palette.shadowInk)
            ctx.fillEllipse(in: CGRect(x: 0.79 * w, y: 0.7 * ht, width: 0.055 * w, height: 0.065 * ht))
            ctx.fillEllipse(in: CGRect(x: 0.94 * w, y: 0.66 * ht, width: 0.05 * w, height: 0.05 * ht))
            ctx.setFillColor(Palette.peach)
            ctx.fillEllipse(in: CGRect(x: 0.795 * w, y: 0.74 * ht, width: 0.018 * w, height: 0.02 * ht))
        }
        cache[key] = texture
        return texture
    }

    /// The squirrel's big curly tail, in a texture the same size as the body.
    static func squirrelTailTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = squirrelSize(unit: h)
        let key = "squirrel-tail-\(Int(h))-\(scale)"
        if let cached = cache[key] { return cached }
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            let body = squirrelBody(unit: h)
            ctx.translateBy(x: squirrelRoom(unit: h).width, y: 0)
            let w = body.width, ht = body.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            Brush.stroke(ctx, [p(0.38, 0.2), p(0.02, 0.2), p(0.02, 0.92), p(0.34, 0.86)],
                         maxWidth: 0.3 * w, color: fur.mixed(with: Palette.orange, 0.2), minF: 0.5, endF: 0.25)
            Brush.stroke(ctx, [p(0.3, 0.26), p(0.1, 0.3), p(0.1, 0.82), p(0.3, 0.82)],
                         maxWidth: 0.1 * w, color: Palette.mustard.mixed(with: Palette.orange, 0.3), minF: 0.3, endF: 0.1)
        }
        cache[key] = texture
        return texture
    }
}
