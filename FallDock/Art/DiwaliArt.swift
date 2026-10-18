import AppKit
import SpriteKit

// Diwali's art: diyas of clay, painted and brass, a lotus diya, a tall brass lamp, a stack of gift boxes,
// rangoli, a plate of laddoos, a box of mithai, crackers (an anar, a rocket in a bottle and a chakri), a
// kandil hanging from its stand, a bowl of floating flowers, a peacock, fireworks and marigold garlands.
// Same flat harvest-wagon style as everything else: flat fills, a darker right side,
// tapered brush strokes and no outlines.

enum DiwaliArt {
    private static var cache: [String: SKTexture] = [:]
    static func clearCache() { cache.removeAll() }

    private static func cached(_ key: String, size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> SKTexture {
        let key = "\(key)-\(Int(size.width * 10))x\(Int(size.height * 10))-\(scale)"
        if let texture = cache[key] { return texture }
        if cache.count > 200 { cache.removeAll() }
        let texture = TextureMaker.make(size: size, scale: scale, draw: draw)
        cache[key] = texture
        return texture
    }

    /// A darker version of a color for the shaded right side.
    private static func shade(_ color: CGColor, _ amount: CGFloat = 0.28) -> CGColor {
        color.mixed(with: Palette.shadowInk, amount)
    }

    private static func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// Fills `path`, then darkens its right side (from `fraction` of the way across) with `side`, or a shade of `color`.
    private static func fillShaded(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, side: CGColor? = nil,
                                   from fraction: CGFloat = 0.66, amount: CGFloat = 0.28) {
        fill(ctx, path, color)
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(side ?? shade(color, amount))
        ctx.fill(CGRect(x: box.minX + box.width * fraction, y: box.minY, width: box.width, height: box.height))
        ctx.restoreGState()
    }

    private static func dot(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// A pointed petal (or leaf) from `base` to `tip`, about `width` across at its widest.
    static func petalPath(from base: CGPoint, to tip: CGPoint, width: CGFloat) -> CGPath {
        let dx = tip.x - base.x, dy = tip.y - base.y
        let length = max(0.001, hypot(dx, dy))
        let nx = -dy / length * width, ny = dx / length * width
        let mid = CGPoint(x: base.x + dx * 0.45, y: base.y + dy * 0.45)
        let path = CGMutablePath()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx, y: mid.y + ny))
        path.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx, y: mid.y - ny))
        path.closeSubpath()
        return path
    }

    // MARK: Flowers and leaves

    /// A marigold head: a ruffled ball of petals with a lighter frill in the middle, darker on the right.
    static func marigold(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, color: CGColor) {
        // The ruffled edge: a ring of overlapping little rounds around a middle.
        func ruffle(count: Int, ring: CGFloat, size: CGFloat, core: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: c.x - r * core, y: c.y - r * core, width: r * core * 2, height: r * core * 2))
            for i in 0..<count {
                let a = CGFloat(i) / CGFloat(count) * .pi * 2
                let p = CGPoint(x: c.x + cos(a) * r * ring, y: c.y + sin(a) * r * ring)
                path.addEllipse(in: CGRect(x: p.x - r * size, y: p.y - r * size, width: r * size * 2, height: r * size * 2))
            }
            return path
        }
        fillShaded(ctx, ruffle(count: 11, ring: 0.68, size: 0.34, core: 0.75), color, from: 0.6, amount: 0.3)
        let frill = color.mixed(with: Palette.peach, 0.28)
        fillShaded(ctx, ruffle(count: 7, ring: 0.36, size: 0.24, core: 0.42), frill, side: color, from: 0.6)
        // A few creases between the petals.
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * .pi * 2 + 0.3
            Brush.stroke(ctx, [CGPoint(x: c.x + cos(a) * r * 0.3, y: c.y + sin(a) * r * 0.3),
                               CGPoint(x: c.x + cos(a + 0.15) * r * 0.55, y: c.y + sin(a + 0.15) * r * 0.55),
                               CGPoint(x: c.x + cos(a + 0.1) * r * 0.82, y: c.y + sin(a + 0.1) * r * 0.82)],
                         maxWidth: max(0.5, r * 0.12), color: shade(color, 0.32).withAlpha(0.7), minF: 0.3, endF: 0.1)
        }
    }

    /// A mango leaf, pointed at both ends, with a midrib.
    static func mangoLeaf(_ ctx: CGContext, from base: CGPoint, angle: CGFloat, length: CGFloat, dark: Bool = false) {
        let a = angle * .pi / 180
        let tip = CGPoint(x: base.x + cos(a) * length, y: base.y + sin(a) * length)
        let green = Palette.green.mixed(with: Palette.teal, 0.12)
        fill(ctx, petalPath(from: base, to: tip, width: length * 0.34), dark ? shade(green, 0.25) : green)
        Brush.stroke(ctx, [base, CGPoint(x: base.x + cos(a) * length * 0.5, y: base.y + sin(a) * length * 0.5), tip],
                     maxWidth: max(0.6, length * 0.05), color: shade(green, 0.4), minF: 0.6, endF: 0.1)
    }

    // MARK: Diyas and lamps

    /// The tip of a diya's spout, as a fraction of its body (x from its middle, y up from its base).
    private static let diyaSpout = CGPoint(x: 0.53, y: 0.74)

    /// Where a lamp's flames burn, as fractions of its body: x from its middle, y up from its base.
    static func flameSpots(_ shape: PumpkinShape) -> [CGPoint] {
        switch shape {
        case .lotus: return [CGPoint(x: 0, y: 0.7)]
        case .lampStand: return [CGPoint(x: -0.44, y: 0.8), CGPoint(x: 0, y: 0.79), CGPoint(x: 0.44, y: 0.8)]
        default: return [CGPoint(x: diyaSpout.x - 0.04, y: diyaSpout.y + 0.03)]
        }
    }

    /// Draws one of Diwali's lamps whose body is `w` x `h`, standing on `base` and centered on `cx`.
    static func drawLamp(kind: PumpkinKind, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat, variant: Int, ctx: CGContext) {
        switch kind.look.shape {
        case .lotus: drawLotusDiya(ctx, look: kind.look, cx: cx, base: base, w: w, h: h)
        case .lampStand: drawLampStand(ctx, look: kind.look, cx: cx, base: base, w: w, h: h)
        default: drawDiya(ctx, kind: kind, cx: cx, base: base, w: w, h: h, variant: variant)
        }
    }

    /// A diya: a little bowl on a foot, its rim pinched into a spout on the right where the wick sits, with
    /// golden oil inside and a painted band, dots and petals on the front (a different mix on each one).
    static func drawDiya(_ ctx: CGContext, kind: PumpkinKind, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat, variant: Int) {
        let look = kind.look
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
        let left = p(-0.47, 0.6), spout = p(diyaSpout.x, diyaSpout.y)
        // The front lip, from the spout round to the left end.
        let lip = [spout, p(0.3, 0.58), p(-0.36, 0.5), left]

        // The foot, then the bowl.
        fill(ctx, CGPath(ellipseIn: CGRect(x: cx - w * 0.18, y: base, width: w * 0.36, height: h * 0.16), transform: nil), look.side)
        let body = CGMutablePath()
        body.move(to: left)
        body.addCurve(to: p(0.02, 0.1), control1: p(-0.48, 0.3), control2: p(-0.28, 0.1))
        body.addCurve(to: spout, control1: p(0.32, 0.1), control2: p(0.44, 0.42))
        body.addCurve(to: left, control1: p(0.28, 0.92), control2: p(-0.38, 0.88))
        body.closeSubpath()
        fillShaded(ctx, body, look.body, side: look.side, from: 0.64)

        // Inside the bowl, with golden oil pooled at the bottom.
        let inside = CGMutablePath()
        inside.move(to: p(-0.41, 0.62))
        inside.addCurve(to: p(0.45, 0.73), control1: p(-0.33, 0.82), control2: p(0.26, 0.86))
        inside.addCurve(to: p(-0.41, 0.62), control1: p(0.27, 0.6), control2: p(-0.31, 0.53))
        inside.closeSubpath()
        fill(ctx, inside, look.side.mixed(with: Palette.shadowInk, 0.35))
        ctx.saveGState()
        ctx.addPath(inside)
        ctx.clip()
        ctx.setFillColor(Palette.marigold.mixed(with: Palette.rust, 0.35))
        ctx.fillEllipse(in: CGRect(x: cx - w * 0.36, y: base + h * 0.48, width: w * 0.72, height: h * 0.22))
        ctx.restoreGState()
        // The rim along the front catches the light.
        Brush.stroke(ctx, lip, maxWidth: h * 0.09, color: look.body.mixed(with: Palette.peach, 0.3), minF: 0.25, endF: 0.4)

        // The painting, following the lip: the left part plain, the right part shaded like the bowl.
        let accent: CGColor
        switch kind {
        case .diyaClay, .diyaTeal: accent = Palette.magenta.mixed(with: Palette.peach, 0.15)
        case .diyaPink: accent = Palette.ghost
        default: accent = Palette.rust
        }
        func below(_ drop: CGFloat) -> [CGPoint] { lip.map { CGPoint(x: $0.x, y: $0.y - drop * h) } }
        let style = variant % 3
        let box = body.boundingBoxOfPath
        let split = box.minX + box.width * 0.64
        for (rect, shaded) in [(CGRect(x: box.minX - 2, y: box.minY - 2, width: split - box.minX + 2, height: box.height + 4), false),
                               (CGRect(x: split, y: box.minY - 2, width: box.maxX - split + 2, height: box.height + 4), true)] {
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.clip(to: rect)
            func tint(_ color: CGColor) -> CGColor { shaded ? shade(color, 0.3) : color }
            if style != 2 {
                Brush.stroke(ctx, below(0.17), maxWidth: h * 0.07, color: tint(look.rib), minF: 1)
            }
            if style != 1 {
                for i in 0..<9 {
                    let q = Brush.bezier(below(style == 2 ? 0.2 : 0.3), 0.1 + CGFloat(i) / 8 * 0.8)
                    dot(ctx, q, h * 0.04, tint(i % 2 == 0 ? accent : look.rib))
                }
            }
            if style != 0 {
                for i in 0..<5 {
                    let q = Brush.bezier(below(0.36), 0.2 + CGFloat(i) / 4 * 0.6)
                    fill(ctx, petalPath(from: q, to: CGPoint(x: q.x, y: q.y - h * 0.16), width: h * 0.1), tint(accent))
                }
            }
            ctx.restoreGState()
        }

        // The wick, lying in the spout.
        Brush.stroke(ctx, [p(0.4, 0.71), p(0.46, 0.74), p(0.5, 0.78)], maxWidth: h * 0.07,
                     color: Palette.peach.mixed(with: Palette.soot, 0.15), minF: 0.6, endF: 0.35)
    }

    /// A diya shaped like a lotus: pink petals cupped around the flame, on a little brass ring.
    private static func drawLotusDiya(_ ctx: CGContext, look: PumpkinKind.Look, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
        let light = look.body, middle = look.side, vein = look.rib
        fillShaded(ctx, CGPath(ellipseIn: CGRect(x: cx - w * 0.2, y: base, width: w * 0.4, height: h * 0.14), transform: nil),
                   Palette.brass, from: 0.62)
        // The back petals, the oil showing between them, then the side and front petals.
        for (tip, color) in [(p(-0.34, 0.9), light), (p(0, 1.0), light), (p(0.34, 0.9), shade(light, 0.15))] {
            fill(ctx, petalPath(from: p(0, 0.18), to: tip, width: w * 0.3), color)
        }
        dot(ctx, p(0, 0.68), w * 0.12, Palette.marigold.mixed(with: Palette.rust, 0.3))
        for (tip, color) in [(p(-0.5, 0.56), middle), (p(0.5, 0.56), shade(middle, 0.25))] {
            fill(ctx, petalPath(from: p(0, 0.12), to: tip, width: w * 0.26), color)
        }
        for (tip, color) in [(p(-0.27, 0.74), middle), (p(0.27, 0.74), shade(middle, 0.22)), (p(0, 0.7), light.mixed(with: middle, 0.4))] {
            let from = p(0, 0.06)
            fill(ctx, petalPath(from: from, to: tip, width: w * 0.3), color)
            Brush.stroke(ctx, [CGPoint(x: from.x + (tip.x - from.x) * 0.25, y: from.y + (tip.y - from.y) * 0.25),
                               CGPoint(x: from.x + (tip.x - from.x) * 0.55, y: from.y + (tip.y - from.y) * 0.55),
                               CGPoint(x: from.x + (tip.x - from.x) * 0.85, y: from.y + (tip.y - from.y) * 0.85)],
                         maxWidth: max(0.8, w * 0.025), color: vein.withAlpha(0.8), minF: 0.4, endF: 0.1)
        }
    }

    /// A tall brass lamp (a kuthu vilakku): a domed foot, a stem with knobs, a dish with a spout at each end
    /// and one at the front, and a pointed finial on top.
    private static func drawLampStand(_ ctx: CGContext, look: PumpkinKind.Look, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
        func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: cx + x0 * w, y: base + y0 * h, width: (x1 - x0) * w, height: (y1 - y0) * h)
        }
        func brass(_ path: CGPath) { fillShaded(ctx, path, look.body, side: look.side, from: 0.6) }
        // The finial, behind the dish: a stem, a ring and a pointed bud.
        brass(CGPath(rect: rect(-0.035, 0.72, 0.035, 0.9), transform: nil))
        brass(CGPath(ellipseIn: rect(-0.09, 0.87, 0.09, 0.93), transform: nil))
        let bud = CGMutablePath()
        bud.move(to: p(0, 1.1))
        bud.addCurve(to: p(0, 0.91), control1: p(0.11, 1.0), control2: p(0.1, 0.91))
        bud.addCurve(to: p(0, 1.1), control1: p(-0.1, 0.91), control2: p(-0.11, 1.0))
        bud.closeSubpath()
        brass(bud)

        // The foot: a flat plate and a dome.
        brass(CGPath(roundedRect: rect(-0.46, 0, 0.46, 0.05), cornerWidth: h * 0.02, cornerHeight: h * 0.02, transform: nil))
        let dome = CGMutablePath()
        dome.move(to: p(-0.36, 0.045))
        dome.addCurve(to: p(0, 0.17), control1: p(-0.34, 0.14), control2: p(-0.14, 0.17))
        dome.addCurve(to: p(0.36, 0.045), control1: p(0.14, 0.17), control2: p(0.34, 0.14))
        dome.closeSubpath()
        brass(dome)
        // The stem, with three knobs.
        brass(CGPath(rect: rect(-0.05, 0.15, 0.05, 0.69), transform: nil))
        for y in [0.24, 0.4, 0.56] as [CGFloat] {
            brass(CGPath(ellipseIn: rect(-0.13, y - 0.03, 0.13, y + 0.03), transform: nil))
        }
        // The dish, its spouts pointing out to each side.
        let dish = CGMutablePath()
        dish.move(to: p(-0.53, 0.81))
        dish.addQuadCurve(to: p(-0.36, 0.76), control: p(-0.45, 0.76))
        dish.addCurve(to: p(0, 0.66), control1: p(-0.3, 0.68), control2: p(-0.16, 0.66))
        dish.addCurve(to: p(0.36, 0.76), control1: p(0.16, 0.66), control2: p(0.3, 0.68))
        dish.addQuadCurve(to: p(0.53, 0.81), control: p(0.45, 0.76))
        dish.addQuadCurve(to: p(0.34, 0.8), control: p(0.42, 0.83))
        dish.addLine(to: p(-0.34, 0.8))
        dish.addQuadCurve(to: p(-0.53, 0.81), control: p(-0.42, 0.83))
        dish.closeSubpath()
        brass(dish)
        // Engraved lines: the dish's rim, and a ring on the dome.
        Brush.stroke(ctx, [p(-0.32, 0.775), p(0, 0.765), p(0.32, 0.775)], maxWidth: max(0.8, h * 0.014), color: look.rib, minF: 0.5)
        Brush.stroke(ctx, [p(-0.26, 0.09), p(0, 0.115), p(0.26, 0.09)], maxWidth: max(0.8, h * 0.012), color: look.rib, minF: 0.4)
        // The wicks.
        for spot in flameSpots(.lampStand) {
            Brush.stroke(ctx, [p(spot.x * 0.92, spot.y - 0.04), p(spot.x * 0.97, spot.y - 0.02), p(spot.x, spot.y)],
                         maxWidth: max(1, h * 0.03), color: Palette.peach.mixed(with: Palette.soot, 0.15), minF: 0.7, endF: 0.4)
        }
    }

    // MARK: The extras

    static func draw(_ kind: DecorKind, _ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        switch kind {
        case .giftBoxes: drawGiftBoxes(ctx, size: size, h: h)
        case .rangoli: drawRangoli(ctx, size: size, h: h)
        case .laddoos: drawLaddoos(ctx, size: size, h: h)
        case .mithai: drawMithai(ctx, size: size, h: h)
        case .anar: drawAnar(ctx, size: size, h: h)
        case .rocket: drawBottle(ctx, size: size, h: h)
        case .chakri: drawChakriStand(ctx, size: size, h: h)
        case .kandil: drawKandilStand(ctx, size: size, h: h)
        case .flowerBowl: drawFlowerBowl(ctx, size: size, h: h)
        default: break
        }
    }

    // MARK: Gift boxes

    /// A big pink gift box with a brass ribbon (a lamp sits on its lid), and two little ones in front.
    private static func drawGiftBoxes(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(x: x0 * w, y: y0 * ht, width: (x1 - x0) * w, height: (y1 - y0) * ht)
        }
        giftBox(ctx, body: rect(0.14, 0, 0.86, 0.7), lid: rect(0.11, 0.67, 0.89, 0.88), color: Palette.magenta, ribbon: Palette.brass, h: h)
        giftBox(ctx, body: rect(0.01, 0, 0.27, 0.36), lid: rect(0, 0.33, 0.28, 0.45), color: Palette.teal, ribbon: Palette.marigold, h: h)
        bow(ctx, at: CGPoint(x: 0.14 * w, y: 0.45 * ht), size: h * 0.1, color: Palette.marigold)
        giftBox(ctx, body: rect(0.75, 0, 0.98, 0.28), lid: rect(0.74, 0.25, 0.99, 0.35), color: Palette.brass, ribbon: Palette.magenta, h: h)
    }

    private static func giftBox(_ ctx: CGContext, body: CGRect, lid: CGRect, color: CGColor, ribbon: CGColor, h: CGFloat) {
        fillShaded(ctx, CGPath(rect: body, transform: nil), color, from: 0.72, amount: 0.25)
        fillShaded(ctx, CGPath(roundedRect: lid, cornerWidth: h * 0.012, cornerHeight: h * 0.012, transform: nil),
                   color.mixed(with: Palette.peach, 0.14), from: 0.74, amount: 0.22)
        // The ribbon, up the middle and around, darker on the right.
        let band = max(2, body.width * 0.11)
        ctx.setFillColor(ribbon)
        ctx.fill(CGRect(x: body.midX - band / 2, y: body.minY, width: band, height: lid.maxY - body.minY))
        let around = CGRect(x: body.minX, y: body.minY + (lid.minY - body.minY) * 0.45 - band * 0.4, width: body.width, height: band * 0.8)
        ctx.fill(around)
        ctx.setFillColor(shade(ribbon, 0.25))
        ctx.fill(CGRect(x: body.minX + body.width * 0.72, y: around.minY, width: body.width * 0.28, height: around.height))
        // Little dots along the lid.
        let r = max(0.6, lid.height * 0.12)
        var x = lid.minX + lid.width * 0.07
        while x < lid.maxX - lid.width * 0.05 {
            if abs(x - body.midX) > band * 0.8 { dot(ctx, CGPoint(x: x, y: lid.minY + lid.height * 0.4), r, ribbon.withAlpha(0.9)) }
            x += lid.width * 0.09
        }
    }

    private static func bow(_ ctx: CGContext, at c: CGPoint, size s: CGFloat, color: CGColor) {
        fill(ctx, petalPath(from: c, to: CGPoint(x: c.x - s, y: c.y + s * 0.5), width: s * 0.75), color)
        fill(ctx, petalPath(from: c, to: CGPoint(x: c.x + s, y: c.y + s * 0.5), width: s * 0.75), shade(color, 0.2))
        dot(ctx, CGPoint(x: c.x, y: c.y + s * 0.08), s * 0.2, shade(color, 0.1))
    }

    // MARK: Rangoli

    /// Where the rangoli's two little diyas sit, as (middle, base, width, height), and whether each is turned
    /// to face left.
    private static func rangoliDiyas(size: CGSize) -> [(cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat, flipped: Bool)] {
        let dw = size.width * 0.17, dh = dw / 1.72
        return [(size.width * 0.12, size.height * 0.2, dw, dh, true), (size.width * 0.88, size.height * 0.2, dw, dh, false)]
    }

    /// Where the flames of the rangoli's diyas burn, from the middle of the rangoli's bottom edge.
    static func rangoliFlames(size: CGSize) -> [CGPoint] {
        let spot = flameSpots(.diya)[0]
        return rangoliDiyas(size: size).map { diya in
            CGPoint(x: diya.cx + (diya.flipped ? -1 : 1) * spot.x * diya.w - size.width / 2, y: diya.base + spot.y * diya.h)
        }
    }

    /// A flower of colored powder lying flat on the Dock: rings of pink, marigold and teal petals around a white
    /// middle, dotted with white, and a little diya at each end.
    private static func drawRangoli(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let r = w * 0.47
        ctx.saveGState()
        // Lying flat, so it's seen squashed.
        ctx.translateBy(x: w / 2, y: ht * 0.42)
        ctx.scaleBy(x: 1, y: min(1, ht * 0.38 / r))
        func ring(_ count: Int, inner: CGFloat, outer: CGFloat, width: CGFloat, offset: CGFloat, colors: [CGColor]) {
            for i in 0..<count {
                let a = offset + CGFloat(i) / CGFloat(count) * .pi * 2
                fill(ctx, petalPath(from: CGPoint(x: cos(a) * inner * r, y: sin(a) * inner * r),
                                    to: CGPoint(x: cos(a) * outer * r, y: sin(a) * outer * r), width: width * r),
                     colors[i % colors.count])
            }
        }
        ring(12, inner: 0.48, outer: 1.0, width: 0.3, offset: 0, colors: [Palette.magenta])
        ring(12, inner: 0.48, outer: 0.86, width: 0.26, offset: .pi / 12, colors: [Palette.marigold, Palette.orange])
        dot(ctx, .zero, r * 0.6, Palette.marigold.mixed(with: Palette.peach, 0.4))
        ring(8, inner: 0.12, outer: 0.57, width: 0.24, offset: .pi / 8, colors: [Palette.teal])
        dot(ctx, .zero, r * 0.3, Palette.ghost)
        ring(6, inner: 0.05, outer: 0.27, width: 0.16, offset: 0, colors: [Palette.magenta])
        dot(ctx, .zero, r * 0.08, Palette.marigold)
        for i in 0..<12 {
            let a = (CGFloat(i) + 0.5) / 12 * .pi * 2
            dot(ctx, CGPoint(x: cos(a) * r * 0.93, y: sin(a) * r * 0.93), r * 0.04, Palette.ghost)
            dot(ctx, CGPoint(x: cos(a) * r * 0.42, y: sin(a) * r * 0.42), r * 0.028, Palette.ghost)
        }
        ctx.restoreGState()

        for diya in rangoliDiyas(size: size) {
            ctx.saveGState()
            ctx.translateBy(x: diya.cx, y: 0)
            if diya.flipped { ctx.scaleBy(x: -1, y: 1) }
            drawDiya(ctx, kind: .diyaClay, cx: 0, base: diya.base, w: diya.w, h: diya.h, variant: 0)
            ctx.restoreGState()
        }
    }

    // MARK: Sweets

    /// A pyramid of laddoos on a pink plate.
    private static func drawLaddoos(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let pink = Palette.magenta.mixed(with: Palette.peach, 0.45)
        let plate = CGRect(x: w * 0.02, y: ht * 0.05, width: w * 0.96, height: ht * 0.24)
        ctx.setFillColor(shade(pink, 0.3))
        ctx.fillEllipse(in: plate.offsetBy(dx: 0, dy: -ht * 0.04))
        ctx.setFillColor(pink)
        ctx.fillEllipse(in: plate)
        ctx.setFillColor(pink.mixed(with: Palette.peach, 0.35))
        ctx.fillEllipse(in: plate.insetBy(dx: w * 0.1, dy: ht * 0.045))
        let r = w * 0.14
        let y0 = plate.midY + r * 0.55
        let rows: [[CGFloat]] = [[-1.9, 0, 1.9], [-0.95, 0.95], [0]]
        for (row, xs) in rows.enumerated() {
            for x in xs {
                laddoo(ctx, center: CGPoint(x: w / 2 + x * r, y: y0 + CGFloat(row) * r * 1.65), radius: r, seed: row * 3 + Int(x * 2 + 4))
            }
        }
        // Slivers of pistachio on top.
        let top = CGPoint(x: w / 2, y: y0 + r * 3.3)
        for (dx, dy, a) in [(-0.3, 0.55, 0.5), (0.2, 0.7, -0.4), (0.35, 0.35, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = CGPoint(x: top.x + dx * r, y: top.y + dy * r)
            Brush.stroke(ctx, [CGPoint(x: c.x - cos(a) * r * 0.16, y: c.y - sin(a) * r * 0.16), c,
                               CGPoint(x: c.x + cos(a) * r * 0.16, y: c.y + sin(a) * r * 0.16)],
                         maxWidth: r * 0.12, color: Palette.slime.mixed(with: Palette.green, 0.35), minF: 0.5)
        }
    }

    /// One laddoo: a ball of tiny golden drops.
    static func laddoo(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, seed: Int) {
        let color = Palette.marigold.mixed(with: Palette.orange, 0.35)
        fillShaded(ctx, CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil), color, from: 0.62, amount: 0.24)
        var rng = SeededRandom(seed: UInt64(seed + 1) &* 977)
        for _ in 0..<10 {
            let a = rng.float(0...(.pi * 2)), d = rng.float(0.15...0.8) * r
            dot(ctx, CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), r * 0.09, shade(color, 0.32).withAlpha(0.75))
        }
        dot(ctx, CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.35), r * 0.17, color.mixed(with: Palette.peach, 0.5))
    }

    /// An open box of mithai: kaju katli, a jalebi and gulab jamuns, with its lid propped up behind.
    private static func drawMithai(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        // The lid, propped open behind, with a brass border and a brass flower.
        let lid = CGMutablePath()
        lid.addLines(between: [p(0.08, 0.4), p(0.92, 0.4), p(0.96, 0.98), p(0.04, 0.98)])
        lid.closeSubpath()
        fillShaded(ctx, lid, Palette.teal, from: 0.76, amount: 0.22)
        ctx.setStrokeColor(Palette.brass)
        ctx.setLineWidth(max(0.8, h * 0.018))
        ctx.addLines(between: [p(0.13, 0.46), p(0.87, 0.46), p(0.9, 0.92), p(0.1, 0.92), p(0.13, 0.46)])
        ctx.strokePath()
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * .pi * 2 + .pi / 2
            let c = p(0.5, 0.74)
            fill(ctx, petalPath(from: c, to: CGPoint(x: c.x + cos(a) * w * 0.09, y: c.y + sin(a) * w * 0.09), width: w * 0.06), Palette.brass)
        }
        dot(ctx, p(0.5, 0.74), w * 0.025, Palette.magenta)

        // Inside the box, behind the sweets.
        ctx.setFillColor(shade(Palette.magenta, 0.5))
        ctx.fill(CGRect(x: w * 0.05, y: ht * 0.3, width: w * 0.9, height: ht * 0.16))
        // Kaju katli: silvery diamonds.
        let katli = Palette.ghost.mixed(with: Palette.peach, 0.45)
        for (x, y) in [(0.17, 0.47), (0.33, 0.5), (0.24, 0.58)] as [(CGFloat, CGFloat)] {
            let c = p(x, y), a = w * 0.09, b = ht * 0.1
            let diamond = CGMutablePath()
            diamond.addLines(between: [CGPoint(x: c.x - a, y: c.y), CGPoint(x: c.x, y: c.y + b), CGPoint(x: c.x + a, y: c.y), CGPoint(x: c.x, y: c.y - b)])
            diamond.closeSubpath()
            fillShaded(ctx, diamond, katli, from: 0.55, amount: 0.18)
            dot(ctx, CGPoint(x: c.x - a * 0.25, y: c.y + b * 0.2), b * 0.18, Palette.ghost)
        }
        // A jalebi: a sticky orange spiral.
        jalebi(ctx, center: p(0.53, 0.55), radius: w * 0.11)
        // Gulab jamuns.
        for (x, y) in [(0.74, 0.5), (0.86, 0.47)] as [(CGFloat, CGFloat)] {
            gulabJamun(ctx, center: p(x, y), radius: w * 0.07)
        }

        // The front of the box, with a brass trim and dots.
        fillShaded(ctx, CGPath(rect: CGRect(x: w * 0.03, y: 0, width: w * 0.94, height: ht * 0.44), transform: nil), Palette.magenta, from: 0.76, amount: 0.25)
        ctx.setFillColor(Palette.brass)
        ctx.fill(CGRect(x: w * 0.03, y: ht * 0.37, width: w * 0.94, height: ht * 0.07))
        ctx.setFillColor(shade(Palette.brass, 0.25))
        ctx.fill(CGRect(x: w * 0.75, y: ht * 0.37, width: w * 0.22, height: ht * 0.07))
        for i in 0..<7 {
            dot(ctx, p(0.12 + CGFloat(i) * 0.126, 0.18), h * 0.022, Palette.brass.withAlpha(0.9))
        }
    }

    static func jalebi(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat) {
        let points = (0...48).map { i -> CGPoint in
            let t = CGFloat(i) / 48
            let a = t * 2.2 * .pi * 2
            let d = r * (1 - 0.85 * t)
            return CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.9)
        }
        let color = Palette.orange.mixed(with: Palette.marigold, 0.3)
        Brush.trail(ctx, points.map { CGPoint(x: $0.x + r * 0.06, y: $0.y - r * 0.08) }, maxWidth: r * 0.3, color: shade(color, 0.3), minF: 0.55)
        Brush.trail(ctx, points, maxWidth: r * 0.28, color: color, minF: 0.55)
    }

    static func gulabJamun(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat) {
        let color = Palette.rust.mixed(with: Palette.plum, 0.45)
        fillShaded(ctx, CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil), color, from: 0.6, amount: 0.3)
        dot(ctx, CGPoint(x: c.x - r * 0.35, y: c.y + r * 0.35), r * 0.2, color.mixed(with: Palette.peach, 0.55))
    }

    /// One sweet, flying out of a plate or box: a laddoo (0), a jalebi (1), kaju katli (2) or a gulab jamun (3).
    static func sweetTexture(variant: Int, size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("sweet-\(variant % 4)", size: CGSize(width: s, height: s), scale: scale) { ctx in
            let c = CGPoint(x: s / 2, y: s / 2)
            switch variant % 4 {
            case 0: laddoo(ctx, center: c, radius: s * 0.46, seed: 7)
            case 1: jalebi(ctx, center: c, radius: s * 0.4)
            case 2:
                let diamond = CGMutablePath()
                diamond.addLines(between: [CGPoint(x: s * 0.04, y: c.y), CGPoint(x: c.x, y: s * 0.8), CGPoint(x: s * 0.96, y: c.y), CGPoint(x: c.x, y: s * 0.2)])
                diamond.closeSubpath()
                fillShaded(ctx, diamond, Palette.ghost.mixed(with: Palette.peach, 0.45), from: 0.55, amount: 0.18)
            default: gulabJamun(ctx, center: c, radius: s * 0.42)
            }
        }
    }

    // MARK: Crackers

    /// Where the big anar's fountain comes out, as a fraction of its picture's size.
    static let anarTop = CGPoint(x: 0.36, y: 0.9)

    /// Two anars (flower pots): striped paper cones with clay caps and fuses.
    private static func drawAnar(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        cone(ctx, cx: w * 0.78, baseWidth: w * 0.36, height: ht * 0.55, colors: [Palette.marigold, Palette.royal], h: h)
        cone(ctx, cx: w * anarTop.x, baseWidth: w * 0.6, height: ht * anarTop.y, colors: [Palette.magenta, Palette.ghost], h: h)
    }

    private static func cone(_ ctx: CGContext, cx: CGFloat, baseWidth bw: CGFloat, height: CGFloat, colors: [CGColor], h: CGFloat) {
        let tw = bw * 0.34, capHeight = height * 0.12, top = height - capHeight
        let body = CGMutablePath()
        body.move(to: CGPoint(x: cx - bw / 2, y: 0))
        body.addLine(to: CGPoint(x: cx + bw / 2, y: 0))
        body.addQuadCurve(to: CGPoint(x: cx + tw / 2, y: top), control: CGPoint(x: cx + bw * 0.34, y: height * 0.4))
        body.addLine(to: CGPoint(x: cx - tw / 2, y: top))
        body.addQuadCurve(to: CGPoint(x: cx - bw / 2, y: 0), control: CGPoint(x: cx - bw * 0.34, y: height * 0.4))
        body.closeSubpath()
        fill(ctx, body, colors[0])
        // Paper wrapped round in curved bands, darker on the right.
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        let bands = 5
        for i in stride(from: 1, to: bands * 2, by: 2) {
            let y0 = height * CGFloat(i) / CGFloat(bands * 2) * 0.92, y1 = y0 + height * 0.092
            let band = CGMutablePath()
            band.move(to: CGPoint(x: cx - bw, y: y0))
            band.addQuadCurve(to: CGPoint(x: cx + bw, y: y0), control: CGPoint(x: cx, y: y0 - bw * 0.14))
            band.addLine(to: CGPoint(x: cx + bw, y: y1))
            band.addQuadCurve(to: CGPoint(x: cx - bw, y: y1), control: CGPoint(x: cx, y: y1 - bw * 0.14))
            band.closeSubpath()
            fill(ctx, band, colors[1])
        }
        ctx.setFillColor(Palette.shadowInk.withAlpha(0.22))
        ctx.fill(CGRect(x: cx + bw * 0.12, y: 0, width: bw, height: height))
        // A clay ring at the bottom.
        ctx.setFillColor(Palette.clay)
        ctx.fill(CGRect(x: cx - bw, y: 0, width: bw * 2, height: height * 0.07))
        ctx.restoreGState()
        // The clay cap and its fuse.
        fillShaded(ctx, CGPath(ellipseIn: CGRect(x: cx - tw * 0.62, y: top - capHeight * 0.7, width: tw * 1.24, height: capHeight * 1.6), transform: nil),
                   Palette.clay, from: 0.6)
        Brush.stroke(ctx, [CGPoint(x: cx, y: top + capHeight * 0.6), CGPoint(x: cx + tw * 0.15, y: height * 0.98),
                           CGPoint(x: cx + tw * 0.4, y: height)], maxWidth: max(1, h * 0.025), color: Palette.soot, minF: 0.8, endF: 0.4)
    }

    /// The rocket's bottle stands in a picture this tall, with the rocket standing in it from this high up.
    static let rocketFoot: CGFloat = 0.1

    /// A glass bottle, with room above it for the rocket that stands in it (drawn by `rocketTexture`).
    private static func drawBottle(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let glass = Palette.teal.mixed(with: Palette.ghost, 0.3)
        let bottle = CGMutablePath()
        bottle.move(to: p(0.26, 0))
        bottle.addLine(to: p(0.74, 0))
        bottle.addQuadCurve(to: p(0.86, 0.05), control: p(0.86, 0))
        bottle.addLine(to: p(0.86, 0.3))
        bottle.addCurve(to: p(0.62, 0.48), control1: p(0.86, 0.4), control2: p(0.62, 0.4))
        bottle.addLine(to: p(0.62, 0.56))
        bottle.addLine(to: p(0.38, 0.56))
        bottle.addLine(to: p(0.38, 0.48))
        bottle.addCurve(to: p(0.14, 0.3), control1: p(0.38, 0.4), control2: p(0.14, 0.4))
        bottle.addLine(to: p(0.14, 0.05))
        bottle.addQuadCurve(to: p(0.26, 0), control: p(0.14, 0))
        bottle.closeSubpath()
        // See-through glass, so the rocket's stick shows inside.
        fillShaded(ctx, bottle, glass.withAlpha(0.72), side: shade(glass, 0.25).withAlpha(0.8), from: 0.62)
        // The lip, a label, and a shine down the left.
        fillShaded(ctx, CGPath(roundedRect: CGRect(x: w * 0.34, y: ht * 0.53, width: w * 0.32, height: ht * 0.05),
                               cornerWidth: w * 0.04, cornerHeight: w * 0.04, transform: nil), shade(glass, 0.1), from: 0.62)
        fillShaded(ctx, CGPath(rect: CGRect(x: w * 0.14, y: ht * 0.1, width: w * 0.72, height: ht * 0.11), transform: nil),
                   Palette.marigold, from: 0.62, amount: 0.25)
        dot(ctx, p(0.42, 0.155), w * 0.06, Palette.magenta)
        Brush.stroke(ctx, [p(0.24, 0.25), p(0.23, 0.32), p(0.25, 0.4)], maxWidth: w * 0.06, color: Palette.ghost.withAlpha(0.65), minF: 0.3)
    }

    static func rocketSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.2).rounded(), height: (h * 0.76).rounded()) }

    /// A sky rocket: a striped tube with a brass nose cone, tied to a long stick.
    static func rocketTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = rocketSize(unit: h)
        return cached("rocket", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            Brush.stroke(ctx, [CGPoint(x: w * 0.5, y: 0), CGPoint(x: w * 0.52, y: ht * 0.3), CGPoint(x: w * 0.5, y: ht * 0.6)],
                         maxWidth: max(1.2, w * 0.12), color: Palette.rust.mixed(with: Palette.peach, 0.3), minF: 0.7)
            let tube = CGRect(x: w * 0.15, y: ht * 0.52, width: w * 0.7, height: ht * 0.34)
            ctx.saveGState()
            ctx.clip(to: tube)
            ctx.setFillColor(Palette.magenta)
            ctx.fill(tube)
            let stripe = tube.height / 5
            var y = tube.minY - tube.width
            while y < tube.maxY {
                let band = CGMutablePath()
                band.addLines(between: [CGPoint(x: tube.minX, y: y), CGPoint(x: tube.maxX, y: y + tube.width * 0.7),
                                        CGPoint(x: tube.maxX, y: y + tube.width * 0.7 + stripe * 0.5), CGPoint(x: tube.minX, y: y + stripe * 0.5)])
                band.closeSubpath()
                fill(ctx, band, Palette.ghost)
                y += stripe
            }
            ctx.setFillColor(Palette.shadowInk.withAlpha(0.22))
            ctx.fill(CGRect(x: tube.minX + tube.width * 0.62, y: tube.minY, width: tube.width, height: tube.height))
            ctx.restoreGState()
            let nose = CGMutablePath()
            nose.addLines(between: [CGPoint(x: w * 0.1, y: tube.maxY), CGPoint(x: w * 0.9, y: tube.maxY), CGPoint(x: w * 0.5, y: ht)])
            nose.closeSubpath()
            fillShaded(ctx, nose, Palette.brass, from: 0.55)
            // The fuse, hanging from the bottom of the tube.
            Brush.stroke(ctx, [CGPoint(x: w * 0.32, y: tube.minY), CGPoint(x: w * 0.24, y: tube.minY - ht * 0.03),
                               CGPoint(x: w * 0.14, y: tube.minY - ht * 0.04)], maxWidth: max(0.8, w * 0.07), color: Palette.soot, minF: 0.8, endF: 0.4)
        }
    }

    /// The chakri's wheel turns on a stake this far up its picture, and is this wide (both as fractions of the unit).
    static let chakriHub: CGFloat = 0.5
    static let chakriWheel: CGFloat = 0.54

    /// A wooden stake standing in a little mound of earth, for the chakri's wheel to spin on.
    private static func drawChakriStand(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let wood = Palette.rust.mixed(with: Palette.peach, 0.25)
        Brush.stroke(ctx, [CGPoint(x: w * 0.5, y: ht * 0.04), CGPoint(x: w * 0.51, y: ht * 0.28), CGPoint(x: w * 0.5, y: ht * chakriHub)],
                     maxWidth: max(2, w * 0.07), color: wood, minF: 0.8, endF: 0.6)
        let mound = CGMutablePath()
        mound.move(to: CGPoint(x: w * 0.22, y: 0))
        mound.addQuadCurve(to: CGPoint(x: w * 0.78, y: 0), control: CGPoint(x: w * 0.5, y: ht * 0.2))
        mound.closeSubpath()
        fillShaded(ctx, mound, Palette.clay.mixed(with: Palette.plum, 0.25), from: 0.6)
    }

    /// The chakri: a coil of green and pink paper wound round a brass pin.
    static func chakriTexture(size d: CGFloat, scale: CGFloat) -> SKTexture {
        cached("chakri", size: CGSize(width: d, height: d), scale: scale) { ctx in
            let c = CGPoint(x: d / 2, y: d / 2), radius = d * 0.45
            for (offset, color) in [(CGFloat(0), Palette.green.mixed(with: Palette.teal, 0.3)), (CGFloat.pi, Palette.magenta)] {
                let points = (0...64).map { i -> CGPoint in
                    let t = CGFloat(i) / 64
                    let a = offset - t * 1.6 * .pi * 2
                    let r = radius * (1 - 0.8 * t)
                    return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                }
                Brush.trail(ctx, points, maxWidth: d * 0.11, color: color, minF: 0.5)
            }
            dot(ctx, c, d * 0.08, Palette.brass)
            dot(ctx, CGPoint(x: c.x + d * 0.02, y: c.y - d * 0.02), d * 0.035, shade(Palette.brass, 0.35))
        }
    }

    // MARK: Kandil

    /// Where the kandil hangs from its stand's hook, as a fraction of the stand's size.
    static let kandilHook = CGPoint(x: 0.7, y: 0.9)

    /// A brass stand: a weighted foot, a pole and an arm curving over into a hook.
    private static func drawKandilStand(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let brass = Palette.brass
        Brush.stroke(ctx, [p(0.2, 0.03), p(0.2, 0.5), p(0.2, 0.95)], maxWidth: max(1.6, h * 0.035), color: shade(brass, 0.12), minF: 1)
        Brush.stroke(ctx, [p(0.2, 0.93), p(0.24, 1.0), p(0.62, 0.995), p(0.7, 0.95)], maxWidth: max(1.4, h * 0.03), color: brass, minF: 0.9, endF: 0.6)
        Brush.stroke(ctx, [p(0.7, 0.96), p(0.71, 0.93), p(kandilHook.x, kandilHook.y)], maxWidth: max(1, h * 0.02), color: brass, minF: 0.8)
        dot(ctx, p(0.2, 0.95), max(1.4, h * 0.03), brass)
        fillShaded(ctx, CGPath(ellipseIn: CGRect(x: w * 0.02, y: 0, width: w * 0.36, height: ht * 0.05), transform: nil), brass, from: 0.6)
    }

    static func kandilSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.34).rounded(), height: (h * 0.6).rounded()) }

    /// An akash kandil: a diamond-shaped paper lantern with a glowing marigold window, a frill of paper points
    /// and long paper tails.
    static func kandilTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = kandilSize(unit: h)
        return cached("kandil", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            // The tails, behind.
            for (end, color) in [(p(0.28, 0.02), Palette.marigold), (p(0.72, 0.03), Palette.teal), (p(0.5, 0.0), Palette.magenta.mixed(with: Palette.peach, 0.2))] {
                Brush.stroke(ctx, [p(0.5, 0.36), CGPoint(x: (end.x + w * 0.5) / 2 + w * 0.06, y: ht * 0.2), end],
                             maxWidth: w * 0.12, color: color, minF: 0.9, endF: 0.25)
            }
            for (from, to) in [(p(0.06, 0.6), p(0.03, 0.4)), (p(0.94, 0.6), p(0.97, 0.4))] {
                Brush.stroke(ctx, [from, CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2), to], maxWidth: w * 0.07, color: Palette.marigold, minF: 0.9, endF: 0.2)
            }
            // The string and cap.
            ctx.setFillColor(Palette.soot)
            ctx.fill(CGRect(x: w * 0.49, y: ht * 0.86, width: max(0.8, w * 0.03), height: ht * 0.14))
            let cap = CGMutablePath()
            cap.addLines(between: [p(0.36, 0.84), p(0.64, 0.84), p(0.5, 0.92)])
            cap.closeSubpath()
            fillShaded(ctx, cap, Palette.brass, from: 0.55)
            // The diamond, darker on the right, with a frill of points along its lower edges.
            let top = p(0.5, 0.86), left = p(0.04, 0.6), bottom = p(0.5, 0.34), right = p(0.96, 0.6)
            for (edge, color) in [([top, left, bottom], Palette.magenta), ([top, right, bottom], shade(Palette.magenta, 0.3))] {
                let half = CGMutablePath()
                half.addLines(between: edge)
                half.closeSubpath()
                fill(ctx, half, color)
            }
            for (from, to, color) in [(left, bottom, Palette.marigold), (bottom, right, shade(Palette.marigold, 0.25))] {
                for i in 0..<4 {
                    let t0 = CGFloat(i) / 4, t1 = CGFloat(i + 1) / 4
                    let a = CGPoint(x: from.x + (to.x - from.x) * t0, y: from.y + (to.y - from.y) * t0)
                    let b = CGPoint(x: from.x + (to.x - from.x) * t1, y: from.y + (to.y - from.y) * t1)
                    let point = CGMutablePath()
                    point.addLines(between: [a, b, CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - ht * 0.05)])
                    point.closeSubpath()
                    fill(ctx, point, color)
                }
            }
            // The glowing window in the middle.
            let c = p(0.5, 0.6)
            for (edge, color) in [([p(0.5, 0.74), p(0.3, 0.6), p(0.5, 0.46)], Palette.marigold.mixed(with: Palette.candlelight, 0.4)),
                                  ([p(0.5, 0.74), p(0.7, 0.6), p(0.5, 0.46)], Palette.marigold)] {
                let half = CGMutablePath()
                half.addLines(between: edge)
                half.closeSubpath()
                fill(ctx, half, color)
            }
            dot(ctx, c, w * 0.04, Palette.magenta)
            Brush.stroke(ctx, [top, p(0.5, 0.6), bottom], maxWidth: max(0.8, w * 0.035), color: Palette.brass, minF: 1)
        }
    }

    // MARK: Flower bowl

    /// Where the bowl's floating diya sits, as (middle, base, width, height).
    private static func bowlDiya(size: CGSize) -> (cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) {
        let dw = size.width * 0.16
        return (size.width * 0.6, size.height * 0.58, dw, dw / 1.72)
    }

    /// Where the floating diya's flame burns, from the middle of the bowl's bottom edge.
    static func bowlFlame(size: CGSize) -> CGPoint {
        let diya = bowlDiya(size: size), spot = flameSpots(.diya)[0]
        return CGPoint(x: diya.cx + spot.x * diya.w - size.width / 2, y: diya.base + spot.y * diya.h)
    }

    /// A wide brass urli full of water, with marigolds, rose petals and a little diya floating in it.
    private static func drawFlowerBowl(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let brass = Palette.brass
        // Handles, then the foot and the bowl.
        ctx.setStrokeColor(shade(brass, 0.15))
        ctx.setLineWidth(max(1.2, h * 0.03))
        for x in [0.04, 0.96] as [CGFloat] {
            ctx.strokeEllipse(in: CGRect(x: w * x - w * 0.045, y: ht * 0.5, width: w * 0.09, height: ht * 0.2))
        }
        fill(ctx, CGPath(ellipseIn: CGRect(x: w * 0.36, y: 0, width: w * 0.28, height: ht * 0.12), transform: nil), shade(brass, 0.3))
        let bowl = CGMutablePath()
        bowl.move(to: p(0.06, 0.64))
        bowl.addCurve(to: p(0.5, 0.06), control1: p(0.07, 0.25), control2: p(0.3, 0.06))
        bowl.addCurve(to: p(0.94, 0.64), control1: p(0.7, 0.06), control2: p(0.93, 0.25))
        bowl.closeSubpath()
        fillShaded(ctx, bowl, brass, from: 0.68)
        Brush.stroke(ctx, [p(0.12, 0.38), p(0.5, 0.26), p(0.88, 0.38)], maxWidth: max(0.8, h * 0.014), color: shade(brass, 0.4), minF: 0.4)
        // The rim, and the water inside it.
        let rim = CGRect(x: w * 0.05, y: ht * 0.48, width: w * 0.9, height: ht * 0.32)
        ctx.setFillColor(brass.mixed(with: Palette.peach, 0.2))
        ctx.fillEllipse(in: rim)
        let water = rim.insetBy(dx: w * 0.035, dy: ht * 0.045)
        ctx.setFillColor(Palette.teal.mixed(with: Palette.royal, 0.2).mixed(with: Palette.ghost, 0.12))
        ctx.fillEllipse(in: water)
        Brush.stroke(ctx, [p(0.16, 0.6), p(0.26, 0.57), p(0.36, 0.6)], maxWidth: max(0.6, h * 0.012), color: Palette.ghost.withAlpha(0.5), minF: 0.2)
        Brush.stroke(ctx, [p(0.66, 0.56), p(0.76, 0.53), p(0.86, 0.57)], maxWidth: max(0.6, h * 0.012), color: Palette.ghost.withAlpha(0.5), minF: 0.2)
        // Floating rose petals, marigolds and a little diya.
        let rose = Palette.magenta.mixed(with: Palette.candyPink, 0.5)
        for (x, y, a) in [(0.33, 0.56, 0.4), (0.5, 0.58, -0.6), (0.78, 0.68, 0.9), (0.45, 0.72, 1.6)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = p(x, y)
            fill(ctx, petalPath(from: CGPoint(x: c.x - cos(a) * w * 0.035, y: c.y - sin(a) * w * 0.02),
                                to: CGPoint(x: c.x + cos(a) * w * 0.035, y: c.y + sin(a) * w * 0.02), width: w * 0.04), rose)
        }
        marigold(ctx, center: p(0.22, 0.66), radius: w * 0.07, color: Palette.marigold)
        marigold(ctx, center: p(0.4, 0.66), radius: w * 0.06, color: Palette.orange.mixed(with: Palette.marigold, 0.25))
        marigold(ctx, center: p(0.82, 0.62), radius: w * 0.055, color: Palette.marigold)
        let diya = bowlDiya(size: size)
        drawDiya(ctx, kind: .diyaBrass, cx: diya.cx, base: diya.base, w: diya.w, h: diya.h, variant: 1)
    }

    // MARK: Garlands

    /// The marigold garland along the top of the Dock: marigolds strung close together, orange and yellow by
    /// turns, with a pair of mango leaves tucked in behind them now and then. `k` is the size unit.
    static func garlandTexture(width: CGFloat, height: CGFloat, seed: Int, unit k: CGFloat, scale: CGFloat) -> SKTexture {
        cached("garland-\(seed)-\(Int(k * 100))", size: CGSize(width: width, height: height), scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(seed) &* 7919 &+ 5)
            let r = 6.2 * k
            func middle(_ x: CGFloat) -> CGFloat { height * 0.44 + sin(x / (37 * k)) * 1.4 * k }
            var x = r * 2 + rng.float(20...40) * k
            while x < width - r * 3 {
                let c = CGPoint(x: x, y: middle(x))
                mangoLeaf(ctx, from: c, angle: 118, length: 11 * k, dark: true)
                mangoLeaf(ctx, from: c, angle: 62, length: 11 * k)
                x += rng.float(70...110) * k
            }
            x = r * 1.1
            var i = 0
            while x < width - r * 1.1 {
                let color = i % 2 == 0 ? Palette.orange.mixed(with: Palette.marigold, 0.25) : Palette.marigold
                marigold(ctx, center: CGPoint(x: x, y: middle(x) + rng.float(-0.6...0.6) * k), radius: r * rng.float(0.92...1.04), color: color)
                x += r * 1.55
                i += 1
            }
        }
    }

    /// Strings of marigolds hanging from a top corner of the Dock, longest at the outside, each ending in a
    /// little brass bell. Drawn for the left corner; the right one is a mirror image.
    static func strandTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        cached("strand", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let r = w * 0.15
            let strings: [CGFloat] = [0.2, 0.5, 0.8]
            for (i, fx) in strings.enumerated() {
                let length = ht * [0.96, 0.74, 0.52][i]
                let x = w * fx
                var y = ht - r * 0.9
                var k = i
                while y > ht - length + r * 1.6 {
                    marigold(ctx, center: CGPoint(x: x, y: y), radius: r, color: k % 2 == 0 ? Palette.orange.mixed(with: Palette.marigold, 0.25) : Palette.marigold)
                    y -= r * 1.5
                    k += 1
                }
                // A little bell.
                let bell = CGMutablePath()
                bell.move(to: CGPoint(x: x - r * 0.7, y: y - r * 0.2))
                bell.addQuadCurve(to: CGPoint(x: x, y: y + r * 0.8), control: CGPoint(x: x - r * 0.75, y: y + r * 0.75))
                bell.addQuadCurve(to: CGPoint(x: x + r * 0.7, y: y - r * 0.2), control: CGPoint(x: x + r * 0.75, y: y + r * 0.75))
                bell.closeSubpath()
                fillShaded(ctx, bell, Palette.brass, from: 0.58)
                dot(ctx, CGPoint(x: x, y: y - r * 0.3), r * 0.22, shade(Palette.brass, 0.3))
            }
        }
    }

    // MARK: Peacock

    static func peacockSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 1.2).rounded(), height: (h * 0.72).rounded()) }
    /// Where the tail fans out from, as a fraction of the peacock's size.
    static let peacockRump = CGPoint(x: 0.62, y: 0.44)

    private static var tailGreen: CGColor { Palette.green.mixed(with: Palette.teal, 0.45) }

    /// One eye on a peacock feather: a brass edge, a teal ring, royal blue and a dark middle.
    private static func featherEye(_ ctx: CGContext, center c: CGPoint, size s: CGFloat) {
        for (scale, color) in [(1.0, Palette.brass), (0.74, Palette.teal), (0.5, Palette.royal), (0.24, Palette.soot)] as [(CGFloat, CGColor)] {
            ctx.setFillColor(color)
            ctx.fillEllipse(in: CGRect(x: c.x - s * scale, y: c.y - s * scale * 1.25, width: s * scale * 2, height: s * scale * 2.5))
        }
    }

    /// The peacock walking, facing right: a royal blue body and neck, a crest, a cream-and-brown wing and long
    /// legs. Its long train is a separate texture (`trainTexture`), so it can fold away when the tail fans out.
    static func peacockTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = peacockSize(unit: h)
        return cached("peacock", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let leg = Palette.stone.mixed(with: Palette.rust, 0.3)
            for (top, foot) in [(p(0.66, 0.32), p(0.63, 0.01)), (p(0.72, 0.32), p(0.75, 0.01))] {
                Brush.stroke(ctx, [top, CGPoint(x: (top.x + foot.x) / 2, y: ht * 0.16), foot], maxWidth: max(1.2, w * 0.016), color: leg, minF: 1)
                Brush.stroke(ctx, [foot, CGPoint(x: foot.x + w * 0.02, y: foot.y), CGPoint(x: foot.x + w * 0.04, y: foot.y + ht * 0.01)],
                             maxWidth: max(1, w * 0.012), color: leg, minF: 0.8, endF: 0.4)
            }
            // The body, leaning forward.
            var t = CGAffineTransform(translationX: w * 0.7, y: ht * 0.44).rotated(by: -0.35)
            let body = CGPath(ellipseIn: CGRect(x: -w * 0.13, y: -ht * 0.16, width: w * 0.26, height: ht * 0.32), transform: &t)
            fillShaded(ctx, body, Palette.royal, from: 0.62, amount: 0.3)
            // The wing.
            fill(ctx, petalPath(from: p(0.6, 0.46), to: p(0.76, 0.34), width: w * 0.08), Palette.peach.mixed(with: Palette.rust, 0.4))
            for i in 0..<3 {
                let s = 0.3 + CGFloat(i) * 0.2
                let a = CGPoint(x: w * (0.6 + 0.16 * s), y: ht * (0.46 - 0.12 * s))
                Brush.stroke(ctx, [CGPoint(x: a.x - w * 0.015, y: a.y - ht * 0.03), a, CGPoint(x: a.x + w * 0.015, y: a.y + ht * 0.03)],
                             maxWidth: max(0.8, w * 0.01), color: Palette.rust.mixed(with: Palette.plum, 0.3), minF: 0.5)
            }
            // The neck and head, with the crest, an eye patch and a beak.
            Brush.stroke(ctx, [p(0.74, 0.5), p(0.8, 0.64), p(0.84, 0.84)], maxWidth: w * 0.075, color: Palette.royal, minF: 0.85, endF: 0.55)
            dot(ctx, p(0.845, 0.86), w * 0.042, Palette.royal)
            for (dx, dy) in [(-0.035, 0.12), (0.0, 0.135), (0.03, 0.12)] as [(CGFloat, CGFloat)] {
                let tip = p(0.84 + dx, 0.86 + dy)
                Brush.stroke(ctx, [p(0.84, 0.9), CGPoint(x: (p(0.84, 0.9).x + tip.x) / 2, y: (p(0.84, 0.9).y + tip.y) / 2), tip],
                             maxWidth: max(0.7, w * 0.008), color: Palette.royal, minF: 1)
                dot(ctx, tip, w * 0.012, Palette.teal)
            }
            ctx.setFillColor(Palette.ghost)
            ctx.fillEllipse(in: CGRect(x: w * 0.836, y: ht * 0.84, width: w * 0.03, height: ht * 0.05))
            dot(ctx, p(0.853, 0.867), w * 0.008, Palette.soot)
            let beak = CGMutablePath()
            beak.addLines(between: [p(0.875, 0.875), p(0.92, 0.85), p(0.875, 0.835)])
            beak.closeSubpath()
            fill(ctx, beak, Palette.stone.mixed(with: Palette.peach, 0.3))
        }
    }

    /// The peacock's long train, trailing behind it along the Dock, dotted with eyes.
    static func trainTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = peacockSize(unit: h)
        return cached("peacock-train", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let train = CGMutablePath()
            train.move(to: p(0.64, 0.52))
            train.addCurve(to: p(0.02, 0.3), control1: p(0.42, 0.56), control2: p(0.14, 0.46))
            train.addQuadCurve(to: p(0.05, 0.08), control: p(-0.03, 0.17))
            train.addCurve(to: p(0.62, 0.3), control1: p(0.26, 0.1), control2: p(0.46, 0.18))
            train.closeSubpath()
            fill(ctx, train, tailGreen)
            ctx.saveGState()
            ctx.addPath(train)
            ctx.clip()
            for i in 0..<5 {
                let f = CGFloat(i)
                Brush.stroke(ctx, [p(0.62, 0.48 - f * 0.04), p(0.32, 0.4 - f * 0.05), p(0.02, 0.27 - f * 0.04)],
                             maxWidth: ht * 0.018, color: shade(tailGreen, 0.3), minF: 0.4, endF: 0.2)
            }
            for (x, y) in [(0.08, 0.2), (0.15, 0.31), (0.22, 0.17), (0.29, 0.33), (0.36, 0.22), (0.44, 0.36), (0.5, 0.26)] as [(CGFloat, CGFloat)] {
                featherEye(ctx, center: p(x, y), size: w * 0.022)
            }
            ctx.restoreGState()
        }
    }

    static func fanSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 1.3).rounded(), height: (h * 0.72).rounded()) }
    /// How far up the fan's picture its pivot is (it fans out around the middle of its bottom edge).
    static let fanPivot: CGFloat = 0.06

    /// The peacock's tail fanned out: a half-wheel of green feathers, each row of eyes a little smaller than the one outside it.
    static func fanTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = fanSize(unit: h)
        return cached("peacock-fan", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let c = CGPoint(x: w / 2, y: ht * fanPivot)
            let r = min(w * 0.47, ht * 0.88)
            let from = 0.08 * CGFloat.pi, to = 0.92 * CGFloat.pi
            // A scalloped edge of feather tips, then the fan.
            for i in 0...18 {
                let a = from + (to - from) * CGFloat(i) / 18
                dot(ctx, CGPoint(x: c.x + cos(a) * r * 0.97, y: c.y + sin(a) * r * 0.97), r * 0.08, tailGreen)
            }
            let fan = CGMutablePath()
            fan.move(to: c)
            fan.addArc(center: c, radius: r * 0.98, startAngle: from, endAngle: to, clockwise: false)
            fan.closeSubpath()
            fillShaded(ctx, fan, tailGreen, from: 0.68, amount: 0.2)
            for i in 0...16 {
                let a = from + (to - from) * CGFloat(i) / 16
                Brush.stroke(ctx, [c, CGPoint(x: c.x + cos(a) * r * 0.5, y: c.y + sin(a) * r * 0.5), CGPoint(x: c.x + cos(a) * r * 0.95, y: c.y + sin(a) * r * 0.95)],
                             maxWidth: max(0.8, r * 0.018), color: tailGreen.mixed(with: Palette.brass, 0.35), minF: 0.6, endF: 0.2)
            }
            for (ring, count, eye) in [(0.84, 13, 0.06), (0.62, 9, 0.05), (0.4, 6, 0.04)] as [(CGFloat, Int, CGFloat)] {
                for i in 0..<count {
                    let a = from + (to - from) * (CGFloat(i) + 0.5) / CGFloat(count)
                    featherEye(ctx, center: CGPoint(x: c.x + cos(a) * r * ring, y: c.y + sin(a) * r * ring), size: r * eye)
                }
            }
        }
    }

    // MARK: Fireworks

    /// A spark: a bright dot with a white-hot middle.
    static func sparkTexture(color: CGColor, size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("spark-\(color.rgbKey)", size: CGSize(width: s, height: s), scale: scale) { ctx in
            dot(ctx, CGPoint(x: s / 2, y: s / 2), s / 2, color)
            dot(ctx, CGPoint(x: s / 2, y: s / 2), s * 0.24, color.mixed(with: .hex(0xFFFFFF), 0.7))
        }
    }

    /// A spark's streak as it flies out of a firework: bright at its head (the right end), thinning to a tail.
    static func streakTexture(color: CGColor, length: CGFloat, scale: CGFloat) -> SKTexture {
        let size = CGSize(width: length, height: max(2, (length * 0.22).rounded()))
        return cached("streak-\(color.rgbKey)", size: size, scale: scale) { ctx in
            let y = size.height / 2
            Brush.trail(ctx, [CGPoint(x: length - size.height / 2, y: y), CGPoint(x: length * 0.5, y: y), CGPoint(x: 0, y: y)],
                        maxWidth: size.height * 0.85, color: color, minF: 0.1)
            dot(ctx, CGPoint(x: length - size.height / 2, y: y), size.height * 0.3, color.mixed(with: .hex(0xFFFFFF), 0.7))
        }
    }

    /// A petal flying out (marigold or rose), for confetti.
    static func petalTexture(color: CGColor, size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("petal-\(color.rgbKey)", size: CGSize(width: s, height: s), scale: scale) { ctx in
            fill(ctx, petalPath(from: CGPoint(x: s * 0.1, y: s * 0.3), to: CGPoint(x: s * 0.9, y: s * 0.7), width: s * 0.5), color)
        }
    }

    /// A firework frozen mid-burst, for pictures: rays of sparks streaking out from a bright middle, each
    /// ending in a spark, with a ring of smaller sparks inside.
    static func drawFirework(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, colors: [CGColor], rays: Int = 16, seed: Int = 1) {
        guard !colors.isEmpty else { return }
        var rng = SeededRandom(seed: UInt64(seed) &* 6151 &+ 3)
        let offset = rng.float(0...(.pi * 2))
        for i in 0..<rays {
            let a = offset + CGFloat(i) / CGFloat(rays) * .pi * 2
            let color = colors[i % colors.count]
            let length = r * rng.float(0.85...1.05)
            let tip = CGPoint(x: c.x + cos(a) * length, y: c.y + sin(a) * length - r * 0.06)
            let from = CGPoint(x: c.x + cos(a) * r * 0.32, y: c.y + sin(a) * r * 0.32)
            Brush.trail(ctx, [tip, CGPoint(x: (tip.x + from.x) / 2, y: (tip.y + from.y) / 2), from], maxWidth: max(1, r * 0.07), color: color, minF: 0.1)
            dot(ctx, tip, max(0.8, r * 0.055), color.mixed(with: .hex(0xFFFFFF), 0.45))
            if i % 2 == 0 {
                dot(ctx, CGPoint(x: c.x + cos(a + 0.2) * r * 0.58, y: c.y + sin(a + 0.2) * r * 0.58), max(0.6, r * 0.035), color)
            }
        }
        dot(ctx, c, max(1, r * 0.08), colors[0].mixed(with: .hex(0xFFFFFF), 0.6))
    }

    // MARK: Whole pictures, for the app window's tiles

    /// An extra with its moving parts (the rocket, the chakri's wheel, the kandil, the little flames) put together.
    static func tile(_ kind: DecorKind, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = CozyArt.size(of: kind, unit: h)
        let base = CozyArt.texture(kind, unit: h, variant: 1, scale: scale)
        let flame = CGSize(width: (h * 0.08).rounded(), height: (h * 0.13).rounded())
        func drawFlame(_ ctx: CGContext, at spot: CGPoint, small: Bool = false) {
            let f = small ? CGSize(width: flame.width * 0.7, height: flame.height * 0.7) : flame
            ctx.draw(SpookyArt.flameTexture(size: f, scale: scale).cgImage(),
                     in: CGRect(x: size.width / 2 + spot.x - f.width / 2, y: spot.y - f.height * 0.12, width: f.width, height: f.height))
        }
        switch kind {
        case .rocket:
            return cached("rocket-tile", size: size, scale: scale) { ctx in
                let rocket = rocketSize(unit: h)
                ctx.draw(rocketTexture(unit: h, scale: scale).cgImage(),
                         in: CGRect(x: (size.width - rocket.width) / 2, y: (size.height * rocketFoot).rounded(), width: rocket.width, height: rocket.height))
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
            }
        case .chakri:
            return cached("chakri-tile", size: size, scale: scale) { ctx in
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                let d = (h * chakriWheel).rounded()
                ctx.draw(chakriTexture(size: d, scale: scale).cgImage(),
                         in: CGRect(x: (size.width - d) / 2, y: size.height * chakriHub - d / 2, width: d, height: d))
            }
        case .kandil:
            return cached("kandil-tile", size: size, scale: scale) { ctx in
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                let kandil = kandilSize(unit: h)
                ctx.draw(kandilTexture(unit: h, scale: scale).cgImage(),
                         in: CGRect(x: size.width * kandilHook.x - kandil.width / 2, y: size.height * kandilHook.y - kandil.height,
                                    width: kandil.width, height: kandil.height))
            }
        case .rangoli:
            return cached("rangoli-tile", size: size, scale: scale) { ctx in
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                for spot in rangoliFlames(size: size) { drawFlame(ctx, at: spot, small: true) }
            }
        case .flowerBowl:
            return cached("bowl-tile", size: size, scale: scale) { ctx in
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                drawFlame(ctx, at: bowlFlame(size: size), small: true)
            }
        default:
            return base
        }
    }

    private static func flameLength(_ kind: PumpkinKind, height: CGFloat) -> CGFloat {
        (height * (kind.look.shape == .lampStand ? 0.15 : 0.2)).rounded()
    }

    /// The size of `litLamp`: the lamp, with room above it for the flames.
    static func litLampSize(_ kind: PumpkinKind, height: CGFloat) -> CGSize {
        let size = PumpkinArt.size(of: kind, height: height)
        return CGSize(width: size.width, height: size.height + flameLength(kind, height: height))
    }

    /// A lamp with its flames lit, for pictures in the app window.
    static func litLamp(_ kind: PumpkinKind, height: CGFloat, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let body = PumpkinArt.bodySize(of: kind, height: height)
        let flameHeight = flameLength(kind, height: height)
        let flame = CGSize(width: (flameHeight * 0.6).rounded(), height: flameHeight)
        let canvas = litLampSize(kind, height: height)
        return cached("lit-\(kind)", size: canvas, scale: scale) { ctx in
            ctx.draw(PumpkinArt.texture(kind: kind, height: height, variant: 1, scale: scale).cgImage(), in: CGRect(origin: .zero, size: size))
            for spot in flameSpots(kind.look.shape) {
                let x = size.width / 2 + spot.x * body.width, y = PumpkinArt.pad + spot.y * body.height
                ctx.draw(SpookyArt.flameTexture(size: flame, scale: scale).cgImage(),
                         in: CGRect(x: x - flame.width / 2, y: y - flame.height * 0.12, width: flame.width, height: flame.height))
            }
        }
    }
}

private extension CGColor {
    /// A short key for caching textures by color.
    var rgbKey: String {
        (components ?? []).map { String(Int(($0 * 255).rounded())) }.joined(separator: ".")
    }
}
