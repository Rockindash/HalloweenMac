import AppKit
import SpriteKit

// Halloween's art: tombstones, crows, zombie hands, coffins, a witch's broom, a black cat, a bubbling
// cauldron, candy corn, dripping candles, a friendly ghost, bats, a dangling spider and cobwebs.
// Same flat harvest-wagon style as everything else: flat fills, a darker right side,
// tapered brush strokes and no outlines.

enum SpookyArt {
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

    /// Fills `path`, then darkens its right side (from `fraction` of the way across).
    private static func fillShaded(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, from fraction: CGFloat = 0.66, amount: CGFloat = 0.28) {
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(shade(color, amount))
        ctx.fill(CGRect(x: box.minX + box.width * fraction, y: box.minY, width: box.width, height: box.height))
        ctx.restoreGState()
    }

    // MARK: The extras

    static func draw(_ kind: DecorKind, _ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        switch kind {
        case .coffin: drawCoffin(ctx, size: size, h: h)
        case .broom: drawBroom(ctx, size: size, h: h, rng: &rng)
        case .blackCat: drawCat(ctx, size: size, h: h)
        case .cauldron: drawCauldron(ctx, size: size, h: h)
        case .candyCorn: drawCandyCornPile(ctx, size: size, h: h, rng: &rng)
        case .candles: drawCandles(ctx, size: size, h: h)
        default: break
        }
    }

    /// A coffin lying on its side: the classic six-sided shape, head to the left.
    private static func drawCoffin(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let outline = CGMutablePath()
        outline.addLines(between: [p(0.03, 0.26), p(0.03, 0.74), p(0.28, 0.98), p(0.97, 0.8), p(0.97, 0.2), p(0.28, 0.02)])
        outline.closeSubpath()
        let wood = Palette.plum.mixed(with: Palette.soot, 0.35)
        fillShaded(ctx, outline, wood, from: 0.72, amount: 0.3)
        // The lid, a little lighter, set in from the edge.
        let lid = CGMutablePath()
        lid.addLines(between: [p(0.09, 0.32), p(0.09, 0.68), p(0.29, 0.86), p(0.91, 0.71), p(0.91, 0.29), p(0.29, 0.14)])
        lid.closeSubpath()
        fillShaded(ctx, lid, wood.mixed(with: Palette.rust, 0.28), from: 0.72, amount: 0.22)
        // Wood grain and brass handles.
        for y in [CGFloat(0.42), 0.58] {
            Brush.stroke(ctx, [p(0.36, y), p(0.6, y + 0.02), p(0.84, y - 0.01)], maxWidth: max(1, h * 0.018),
                         color: wood.mixed(with: Palette.shadowInk, 0.2), minF: 0.2)
        }
        ctx.setFillColor(Palette.mustard.mixed(with: Palette.rust, 0.25))
        for x in [CGFloat(0.42), 0.72] {
            ctx.addPath(CGPath(roundedRect: CGRect(x: x * w, y: 0.03 * ht, width: w * 0.09, height: ht * 0.08),
                               cornerWidth: ht * 0.03, cornerHeight: ht * 0.03, transform: nil))
            ctx.fillPath()
        }
    }

    // MARK: Tombstones (Halloween's main objects, standing where pumpkins would)

    /// A tombstone sprite the same size as a pumpkin of that kind and height would be.
    static func tombstoneTexture(kind: PumpkinKind, height: CGFloat, variant: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let body = PumpkinArt.bodySize(of: kind, height: height)
        return cached("tomb-\(kind)-\(Int(height))-\(variant % 3)", size: size, scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(variant + 7) &* 977)
            let box = CGRect(x: (size.width - body.width) / 2, y: PumpkinArt.pad, width: body.width, height: body.height * 1.08)
            drawTomb(kind, ctx, box: box, mossy: variant % 3 != 0, rng: &rng)
        }
    }

    private static func drawTomb(_ kind: PumpkinKind, _ ctx: CGContext, box: CGRect, mossy: Bool, rng: inout SeededRandom) {
        let w = box.width, ht = box.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: box.minX + x * w, y: box.minY + y * ht) }
        let stone = Palette.stone
        let carved = shade(stone, 0.45)
        ctx.saveGState()
        if kind == .tombCracked {
            // It's been leaning for a century or two.
            ctx.translateBy(x: box.midX, y: box.minY)
            ctx.rotate(by: -0.08)
            ctx.translateBy(x: -box.midX, y: -box.minY)
        }
        let shape = CGMutablePath()
        switch kind {
        case .tombObelisk:
            // A tall pillar with a pointed top, on a wider base.
            shape.addRect(CGRect(x: box.minX, y: box.minY, width: w, height: ht * 0.1))
            shape.addLines(between: [p(0.14, 0.1), p(0.14, 0.82), p(0.5, 1), p(0.86, 0.82), p(0.86, 0.1)])
            shape.closeSubpath()
        case .tombSkull, .tombBoo:
            // A slab with rounded top corners.
            let r = w * (kind == .tombBoo ? 0.14 : 0.22)
            shape.move(to: p(0.04, 0))
            shape.addLine(to: CGPoint(x: box.minX + w * 0.04, y: box.maxY - r))
            shape.addQuadCurve(to: CGPoint(x: box.minX + w * 0.04 + r, y: box.maxY), control: CGPoint(x: box.minX + w * 0.04, y: box.maxY))
            shape.addLine(to: CGPoint(x: box.maxX - w * 0.04 - r, y: box.maxY))
            shape.addQuadCurve(to: CGPoint(x: box.maxX - w * 0.04, y: box.maxY - r), control: CGPoint(x: box.maxX - w * 0.04, y: box.maxY))
            shape.addLine(to: p(0.96, 0))
            shape.closeSubpath()
        default:
            // The classic: straight sides and a round top.
            let radius = w * 0.4
            shape.move(to: p(0.1, 0))
            shape.addLine(to: CGPoint(x: box.minX + w * 0.1, y: box.maxY - radius))
            shape.addArc(center: CGPoint(x: box.midX, y: box.maxY - radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
            shape.addLine(to: p(0.9, 0))
            shape.closeSubpath()
        }
        fillShaded(ctx, shape, stone, from: 0.7, amount: 0.25)

        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        switch kind {
        case .tombRound:
            engrave("RIP", ctx, center: p(0.5, 0.56), size: w * 0.24, color: carved)
            Brush.stroke(ctx, [p(0.3, 0.32), p(0.7, 0.32), p(0.7, 0.32)], maxWidth: max(1, w * 0.025), color: carved, minF: 1)
        case .tombObelisk:
            Brush.stroke(ctx, [p(0.5, 0.3), p(0.5, 0.5), p(0.5, 0.7)], maxWidth: max(1, w * 0.06), color: carved, minF: 1)
            ctx.setFillColor(carved)
            ctx.fillEllipse(in: CGRect(x: box.minX + w * 0.4, y: box.minY + ht * 0.74, width: w * 0.2, height: w * 0.2))
        case .tombSkull:
            skull(ctx, center: p(0.5, 0.58), size: w * 0.42, color: carved)
            Brush.stroke(ctx, [p(0.24, 0.24), p(0.5, 0.24), p(0.76, 0.24)], maxWidth: max(1, w * 0.025), color: carved, minF: 1)
        case .tombCracked:
            engrave("RIP", ctx, center: p(0.48, 0.5), size: w * 0.22, color: carved.withAlpha(0.6))
            // A chunk knocked off the top right, and a crack running down from it.
            ctx.setBlendMode(.clear)
            let chip = CGMutablePath()
            chip.addLines(between: [p(0.62, 1.05), p(0.66, 0.86), p(0.78, 0.9), p(0.86, 0.76), p(1.05, 0.8), p(1.05, 1.05)])
            chip.closeSubpath()
            ctx.addPath(chip)
            ctx.fillPath()
            ctx.setBlendMode(.normal)
            Brush.stroke(ctx, [p(0.7, 0.86), p(0.58, 0.6), p(0.66, 0.34), p(0.56, 0.12)], maxWidth: max(1, w * 0.03), color: carved, minF: 0.6, endF: 0.1)
        case .tombBoo:
            engrave("BOO!", ctx, center: p(0.5, 0.5), size: ht * 0.36, color: carved)
        default:
            break
        }
        // Moss creeping over the top.
        if mossy {
            ctx.setFillColor(Palette.green.withAlpha(0.75))
            let top = kind == .tombObelisk ? 0.84 : 0.94
            for _ in 0..<4 {
                let x = rng.float(0.2...0.7)
                ctx.fillEllipse(in: CGRect(x: box.minX + w * x, y: box.minY + ht * CGFloat(top) - w * 0.05, width: w * rng.float(0.1...0.2), height: w * 0.12))
            }
        }
        ctx.restoreGState()
        ctx.restoreGState()

        // Tufts of grass at the foot.
        for _ in 0..<8 {
            let x = box.minX + rng.float(-0.05...1.05) * w
            let lean = rng.float(-3...3)
            Brush.stroke(ctx, [CGPoint(x: x, y: box.minY - 1), CGPoint(x: x + lean * 0.5, y: box.minY + ht * 0.05),
                               CGPoint(x: x + lean, y: box.minY + ht * rng.float(0.08...0.14))],
                         maxWidth: max(1.2, w * 0.04), color: Palette.green, minF: 0.9, endF: 0.1)
        }
    }

    /// Letters carved into stone.
    private static func engrave(_ text: String, _ ctx: CGContext, center: CGPoint, size: CGFloat, color: CGColor) {
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color) ?? .gray]
        let textSize = (text as NSString).size(withAttributes: attributes)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        (text as NSString).draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A cute little skull, carved in.
    private static func skull(_ ctx: CGContext, center c: CGPoint, size s: CGFloat, color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: c.x - s / 2, y: c.y - s * 0.3, width: s, height: s * 0.8))
        ctx.fill(CGRect(x: c.x - s * 0.28, y: c.y - s * 0.5, width: s * 0.56, height: s * 0.3))
        ctx.setFillColor(Palette.stone)
        ctx.fillEllipse(in: CGRect(x: c.x - s * 0.3, y: c.y - s * 0.08, width: s * 0.22, height: s * 0.24))
        ctx.fillEllipse(in: CGRect(x: c.x + s * 0.08, y: c.y - s * 0.08, width: s * 0.22, height: s * 0.24))
        for i in 0..<3 {
            ctx.fill(CGRect(x: c.x - s * 0.2 + CGFloat(i) * s * 0.16, y: c.y - s * 0.48, width: s * 0.06, height: s * 0.16))
        }
    }

    /// A witch's broom, leaning: a crooked handle and a bundle of straw tied with twine.
    private static func drawBroom(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        Brush.stroke(ctx, [p(0.82, 0.98), p(0.6, 0.7), p(0.48, 0.3)], maxWidth: h * 0.06, color: Palette.rust.mixed(with: Palette.plum, 0.4), minF: 0.8)
        let straw = Palette.mustard.mixed(with: Palette.peach, 0.15)
        let bundle = CGMutablePath()
        bundle.addLines(between: [p(0.38, 0.36), p(0.56, 0.38), p(0.86, 0.02), p(0.04, 0.02)])
        bundle.closeSubpath()
        fillShaded(ctx, bundle, straw, from: 0.6, amount: 0.2)
        for _ in 0..<9 {
            let x0 = rng.float(0.4...0.54), x1 = rng.float(0.06...0.84)
            Brush.stroke(ctx, [p(x0, 0.34), p((x0 + x1) / 2, 0.18), p(x1, 0.03)], maxWidth: max(0.8, h * 0.014),
                         color: Palette.mustard.mixed(with: Palette.rust, 0.4), minF: 0.4, endF: 0.2)
        }
        Brush.stroke(ctx, [p(0.36, 0.32), p(0.47, 0.33), p(0.6, 0.34)], maxWidth: h * 0.05, color: Palette.plum, minF: 1)
    }

    // MARK: Crows

    static func crowSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.36).rounded(), height: (h * 0.32).rounded()) }

    /// A crow perched, facing right.
    static func crowTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = crowSize(unit: h)
        return cached("crow", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let feathers = Palette.soot
            // Legs, tail, body, a wing with a purple sheen, head, beak and eye.
            for x in [CGFloat(0.44), 0.54] {
                Brush.stroke(ctx, [p(x, 0.22), p(x, 0.1), p(x + 0.04, 0.02)], maxWidth: max(1, h * 0.02), color: Palette.mustard.mixed(with: Palette.rust, 0.3), minF: 1)
            }
            let tail = CGMutablePath()
            tail.addLines(between: [p(0.3, 0.38), p(0.02, 0.2), p(0.06, 0.12), p(0.36, 0.26)])
            tail.closeSubpath()
            ctx.addPath(tail)
            ctx.setFillColor(feathers)
            ctx.fillPath()
            fillShaded(ctx, CGPath(ellipseIn: CGRect(x: w * 0.2, y: ht * 0.18, width: w * 0.56, height: ht * 0.48), transform: nil), feathers, from: 0.7)
            Brush.stroke(ctx, [p(0.3, 0.5), p(0.46, 0.36), p(0.66, 0.34)], maxWidth: ht * 0.16, color: feathers.mixed(with: Palette.witch, 0.35), minF: 0.6, endF: 0.2)
            ctx.setFillColor(feathers)
            ctx.fillEllipse(in: CGRect(x: w * 0.56, y: ht * 0.5, width: w * 0.3, height: ht * 0.34))
            let beak = CGMutablePath()
            beak.addLines(between: [p(0.84, 0.7), p(1.0, 0.62), p(0.84, 0.58)])
            beak.closeSubpath()
            ctx.addPath(beak)
            ctx.setFillColor(Palette.mustard.mixed(with: Palette.rust, 0.3))
            ctx.fillPath()
            ctx.setFillColor(Palette.ghost)
            ctx.fillEllipse(in: CGRect(x: w * 0.7, y: ht * 0.66, width: w * 0.07, height: w * 0.07))
            ctx.setFillColor(feathers)
            ctx.fillEllipse(in: CGRect(x: w * 0.725, y: ht * 0.675, width: w * 0.035, height: w * 0.035))
        }
    }

    /// A crow in flight, wings up (`frame` 0) or down (1), facing right.
    static func flyingCrowTexture(frame: Int, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = CGSize(width: (h * 0.5).rounded(), height: (h * 0.32).rounded())
        return cached("crow-fly-\(frame)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let feathers = Palette.soot
            let up = frame == 0
            let wing = CGMutablePath()
            wing.addLines(between: [p(0.36, 0.5), p(up ? 0.3 : 0.34, up ? 1.0 : 0.02), p(0.62, 0.5)])
            wing.closeSubpath()
            ctx.addPath(wing)
            ctx.setFillColor(feathers.mixed(with: Palette.witch, 0.25))
            ctx.fillPath()
            ctx.setFillColor(feathers)
            ctx.fillEllipse(in: CGRect(x: w * 0.18, y: ht * 0.36, width: w * 0.56, height: ht * 0.28))
            let tail = CGMutablePath()
            tail.addLines(between: [p(0.22, 0.52), p(0.0, 0.62), p(0.0, 0.38), p(0.22, 0.46)])
            tail.closeSubpath()
            ctx.addPath(tail)
            ctx.fillPath()
            ctx.fillEllipse(in: CGRect(x: w * 0.66, y: ht * 0.4, width: w * 0.18, height: ht * 0.3))
            let beak = CGMutablePath()
            beak.addLines(between: [p(0.82, 0.58), p(0.96, 0.53), p(0.82, 0.48)])
            beak.closeSubpath()
            ctx.addPath(beak)
            ctx.setFillColor(Palette.mustard.mixed(with: Palette.rust, 0.3))
            ctx.fillPath()
        }
    }

    // MARK: Zombie hand

    static func handSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.3).rounded(), height: (h * 0.46).rounded()) }

    /// A zombie hand reaching up out of the ground, with a torn sleeve.
    static func handTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = handSize(unit: h)
        return cached("hand", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let skin = Palette.slime.mixed(with: Palette.stone, 0.45)
            // Forearm and palm.
            fillShaded(ctx, CGPath(roundedRect: CGRect(x: w * 0.32, y: 0, width: w * 0.36, height: ht * 0.55), cornerWidth: w * 0.08, cornerHeight: w * 0.08, transform: nil), skin, from: 0.62)
            fillShaded(ctx, CGPath(roundedRect: CGRect(x: w * 0.22, y: ht * 0.42, width: w * 0.56, height: ht * 0.26), cornerWidth: w * 0.14, cornerHeight: w * 0.14, transform: nil), skin, from: 0.66)
            // Fingers, a little crooked, and a thumb.
            for (i, x) in [0.29, 0.42, 0.56, 0.69].enumerated() {
                let length = [0.24, 0.3, 0.28, 0.22][i]
                Brush.stroke(ctx, [p(CGFloat(x), 0.64), p(CGFloat(x) + 0.02, 0.64 + CGFloat(length) * 0.6), p(CGFloat(x) - 0.03, 0.64 + CGFloat(length))],
                             maxWidth: w * 0.12, color: skin, minF: 0.8, endF: 0.6)
            }
            Brush.stroke(ctx, [p(0.24, 0.5), p(0.1, 0.58), p(0.06, 0.7)], maxWidth: w * 0.12, color: skin, minF: 0.8, endF: 0.6)
            // A torn, purple sleeve at the bottom.
            let sleeve = CGMutablePath()
            sleeve.addLines(between: [p(0.24, 0), p(0.24, 0.2), p(0.34, 0.15), p(0.42, 0.24), p(0.52, 0.16), p(0.62, 0.23), p(0.76, 0.17), p(0.76, 0)])
            sleeve.closeSubpath()
            fillShaded(ctx, sleeve, Palette.witch.mixed(with: Palette.soot, 0.3), from: 0.62)
        }
    }

    // The black cat is three pieces: its body, its tail (which swishes) and its eyes (which blink).

    /// Where the cat's tail joins its body, as a fraction of its size.
    static let catTailBase = CGPoint(x: 0.66, y: 0.1)

    private static func drawCat(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let fur = Palette.soot
        // Sitting body, a bit like a pear.
        let body = CGMutablePath()
        body.move(to: p(0.2, 0.02))
        body.addCurve(to: p(0.36, 0.56), control1: p(0.12, 0.2), control2: p(0.22, 0.46))
        body.addLine(to: p(0.64, 0.56))
        body.addCurve(to: p(0.8, 0.02), control1: p(0.78, 0.46), control2: p(0.88, 0.2))
        body.closeSubpath()
        fillShaded(ctx, body, fur, from: 0.64, amount: 0.25)
        // Head and pointy ears.
        let head = CGPath(ellipseIn: CGRect(x: w * 0.25, y: ht * 0.48, width: w * 0.5, height: ht * 0.36), transform: nil)
        fillShaded(ctx, head, fur, from: 0.7, amount: 0.22)
        for dir in [CGFloat(-1), 1] {
            let ear = CGMutablePath()
            ear.addLines(between: [p(0.5 + dir * 0.06, 0.78), p(0.5 + dir * 0.22, 0.98), p(0.5 + dir * 0.24, 0.7)])
            ear.closeSubpath()
            ctx.addPath(ear)
            ctx.setFillColor(fur)
            ctx.fillPath()
            let inner = CGMutablePath()
            inner.addLines(between: [p(0.5 + dir * 0.11, 0.78), p(0.5 + dir * 0.2, 0.91), p(0.5 + dir * 0.21, 0.75)])
            inner.closeSubpath()
            ctx.addPath(inner)
            ctx.setFillColor(Palette.plum.mixed(with: Palette.peach, 0.3))
            ctx.fillPath()
        }
        // Nose, mouth and whiskers.
        ctx.setFillColor(Palette.plum.mixed(with: Palette.peach, 0.45))
        ctx.fillEllipse(in: CGRect(x: w * 0.47, y: ht * 0.565, width: w * 0.06, height: ht * 0.03))
        let whisker = Palette.ghost.withAlpha(0.7)
        for dir in [CGFloat(-1), 1] {
            for dy in [CGFloat(0.01), -0.02] {
                Brush.stroke(ctx, [p(0.5 + dir * 0.08, 0.57), p(0.5 + dir * 0.2, 0.58 + dy), p(0.5 + dir * 0.32, 0.57 + dy * 2)],
                             maxWidth: max(0.6, h * 0.01), color: whisker, minF: 0.6, endF: 0.1)
            }
        }
        // Front paws.
        ctx.setFillColor(fur.mixed(with: Palette.ghost, 0.08))
        ctx.fillEllipse(in: CGRect(x: w * 0.34, y: 0, width: w * 0.14, height: ht * 0.06))
        ctx.fillEllipse(in: CGRect(x: w * 0.52, y: 0, width: w * 0.14, height: ht * 0.06))
    }

    static func catTailTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        cached("cat-tail", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            Brush.stroke(ctx, [p(catTailBase.x, catTailBase.y), p(1.0, 0.08), p(0.98, 0.52), p(0.84, 0.56)],
                         maxWidth: w * 0.1, color: Palette.soot, minF: 0.8, endF: 0.35)
        }
    }

    /// Where the cat's eyes go, from the middle of its bottom edge, and their size.
    static func catEyes(catSize size: CGSize) -> (center: CGPoint, size: CGSize) {
        (CGPoint(x: 0, y: size.height * 0.665), CGSize(width: (size.width * 0.34).rounded(), height: (size.height * 0.1).rounded()))
    }

    /// Two glowing almond eyes with slit pupils.
    static func catEyesTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        cached("cat-eyes", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            for cx in [w * 0.22, w * 0.78] {
                let eye = CGMutablePath()
                eye.move(to: CGPoint(x: cx - w * 0.2, y: ht / 2))
                eye.addQuadCurve(to: CGPoint(x: cx + w * 0.2, y: ht / 2), control: CGPoint(x: cx, y: ht * 1.15))
                eye.addQuadCurve(to: CGPoint(x: cx - w * 0.2, y: ht / 2), control: CGPoint(x: cx, y: -ht * 0.15))
                ctx.addPath(eye)
                ctx.setFillColor(Palette.slime.mixed(with: Palette.mustard, 0.45))
                ctx.fillPath()
                ctx.setFillColor(Palette.soot)
                ctx.fillEllipse(in: CGRect(x: cx - w * 0.035, y: ht * 0.1, width: w * 0.07, height: ht * 0.8))
            }
        }
    }

    /// Where the brew's surface is, as a fraction of the cauldron's height.
    static let brewLevel: CGFloat = 0.68

    private static func drawCauldron(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let iron = Palette.soot.mixed(with: Palette.plum, 0.2)
        // Little feet, a round pot, a rim and the bubbling brew.
        ctx.setFillColor(iron)
        for x in [w * 0.24, w * 0.66] {
            ctx.fill(CGRect(x: x, y: 0, width: w * 0.1, height: ht * 0.12))
        }
        let pot = CGPath(ellipseIn: CGRect(x: w * 0.08, y: ht * 0.05, width: w * 0.84, height: ht * 0.7), transform: nil)
        fillShaded(ctx, pot, iron, from: 0.66, amount: 0.3)
        // A shine on the left.
        Brush.stroke(ctx, [CGPoint(x: w * 0.2, y: ht * 0.25), CGPoint(x: w * 0.17, y: ht * 0.4), CGPoint(x: w * 0.24, y: ht * 0.56)],
                     maxWidth: h * 0.04, color: Palette.ghost.withAlpha(0.18), minF: 0.3, endF: 0.2)
        let rim = CGRect(x: w * 0.04, y: ht * (brewLevel - 0.08), width: w * 0.92, height: ht * 0.16)
        ctx.setFillColor(iron.mixed(with: Palette.ghost, 0.12))
        ctx.fillEllipse(in: rim)
        let brew = rim.insetBy(dx: w * 0.06, dy: ht * 0.03)
        ctx.setFillColor(Palette.slime)
        ctx.fillEllipse(in: brew)
        ctx.setFillColor(Palette.slime.mixed(with: Palette.ghost, 0.35))
        ctx.fillEllipse(in: CGRect(x: brew.minX + brew.width * 0.18, y: brew.midY - 1, width: brew.width * 0.22, height: brew.height * 0.4))
        ctx.fillEllipse(in: CGRect(x: brew.minX + brew.width * 0.58, y: brew.midY - 2, width: brew.width * 0.14, height: brew.height * 0.32))
        // A drip over the rim.
        Brush.stroke(ctx, [CGPoint(x: w * 0.7, y: rim.midY), CGPoint(x: w * 0.72, y: rim.minY - ht * 0.04), CGPoint(x: w * 0.71, y: rim.minY - ht * 0.1)],
                     maxWidth: h * 0.05, color: Palette.slime, minF: 1, endF: 0.7)
    }

    private static func drawCandyCornPile(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        let s = h * 0.17
        // Bottom row first, so the pile builds up.
        let spots: [(CGFloat, CGFloat)] = [(0.16, 0.24), (0.36, 0.22), (0.58, 0.24), (0.8, 0.22), (0.27, 0.5), (0.5, 0.52), (0.71, 0.48), (0.48, 0.8)]
        for (x, y) in spots {
            candyCorn(ctx, center: CGPoint(x: w * x, y: ht * y), size: s, angle: rng.float(-60...60))
        }
    }

    /// One candy corn: a rounded triangle with a yellow base, an orange middle and a white tip.
    static func candyCorn(_ ctx: CGContext, center c: CGPoint, size s: CGFloat, angle: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: angle * .pi / 180)
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: -s * 0.42, y: -s * 0.42))
        shape.addQuadCurve(to: CGPoint(x: s * 0.42, y: -s * 0.42), control: CGPoint(x: 0, y: -s * 0.56))
        shape.addQuadCurve(to: CGPoint(x: 0, y: s * 0.55), control: CGPoint(x: s * 0.26, y: s * 0.1))
        shape.addQuadCurve(to: CGPoint(x: -s * 0.42, y: -s * 0.42), control: CGPoint(x: -s * 0.26, y: s * 0.1))
        shape.closeSubpath()
        ctx.addPath(shape)
        ctx.clip()
        ctx.setFillColor(Palette.mustard)
        ctx.fill(CGRect(x: -s, y: -s, width: s * 2, height: s * 0.68))
        ctx.setFillColor(Palette.orange)
        ctx.fill(CGRect(x: -s, y: -s * 0.32, width: s * 2, height: s * 0.42))
        ctx.setFillColor(Palette.ghost)
        ctx.fill(CGRect(x: -s, y: s * 0.1, width: s * 2, height: s))
        ctx.setFillColor(Palette.shadowInk.withAlpha(0.18))
        ctx.fill(CGRect(x: s * 0.12, y: -s, width: s, height: s * 2))
        ctx.restoreGState()
    }

    static func candyCornTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("candy-corn", size: CGSize(width: s, height: s), scale: scale) { ctx in
            candyCorn(ctx, center: CGPoint(x: s / 2, y: s / 2), size: s * 0.9, angle: 0)
        }
    }

    /// The tops of the three candles' wicks, as fractions of the candles' size.
    static let candleWicks: [CGPoint] = [CGPoint(x: 0.3, y: 0.76), CGPoint(x: 0.58, y: 0.58), CGPoint(x: 0.8, y: 0.42)]

    private static func drawCandles(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let widths: [CGFloat] = [0.24, 0.22, 0.2]
        let wax = Palette.ghost.mixed(with: Palette.peach, 0.3)
        for (i, wick) in candleWicks.enumerated() {
            let cw = w * widths[i]
            let top = wick.y * ht - ht * 0.06
            let rect = CGRect(x: wick.x * w - cw / 2, y: 0, width: cw, height: top)
            fillShaded(ctx, CGPath(roundedRect: rect, cornerWidth: cw * 0.2, cornerHeight: cw * 0.2, transform: nil), wax, from: 0.62, amount: 0.18)
            // Drips running down from the top.
            ctx.setFillColor(wax.mixed(with: Palette.ghost, 0.5))
            for (dx, length) in [(-0.3, 0.16), (0.18, 0.26)] {
                let x = rect.midX + cw * CGFloat(dx)
                Brush.stroke(ctx, [CGPoint(x: x, y: top), CGPoint(x: x, y: top - ht * CGFloat(length) / 2), CGPoint(x: x, y: top - ht * CGFloat(length))],
                             maxWidth: cw * 0.26, color: wax.mixed(with: Palette.ghost, 0.5), minF: 1, endF: 0.8)
            }
            // The wick.
            Brush.stroke(ctx, [CGPoint(x: wick.x * w, y: top), CGPoint(x: wick.x * w + 0.5, y: top + ht * 0.03), CGPoint(x: wick.x * w, y: wick.y * ht)],
                         maxWidth: max(1, h * 0.018), color: Palette.soot, minF: 1)
        }
    }

    /// A candle flame: an orange teardrop with a yellow heart.
    static func flameTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        cached("flame", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func drop(_ inset: CGFloat) -> CGPath {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: w / 2, y: ht - inset * ht * 0.6))
                path.addCurve(to: CGPoint(x: w / 2, y: inset * ht * 0.3), control1: CGPoint(x: w * (1 - inset), y: ht * 0.45),
                              control2: CGPoint(x: w * (0.95 - inset), y: inset * ht * 0.3))
                path.addCurve(to: CGPoint(x: w / 2, y: ht - inset * ht * 0.6), control1: CGPoint(x: w * (0.05 + inset), y: inset * ht * 0.3),
                              control2: CGPoint(x: w * inset, y: ht * 0.45))
                return path
            }
            ctx.addPath(drop(0))
            ctx.setFillColor(Palette.orange)
            ctx.fillPath()
            ctx.addPath(drop(0.28))
            ctx.setFillColor(Palette.mustard.mixed(with: Palette.ghost, 0.4))
            ctx.fillPath()
        }
    }

    // MARK: The ghost

    static func ghostSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.56).rounded(), height: (h * 0.72).rounded()) }

    /// A friendly sheet ghost with a wavy hem, rosy cheeks and a little "o" of a mouth.
    static func ghostTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = ghostSize(unit: h)
        return cached("ghost", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let sheet = CGMutablePath()
            sheet.move(to: p(0.08, 0.14))
            sheet.addLine(to: p(0.08, 0.6))
            sheet.addArc(center: p(0.5, 0.6), radius: w * 0.42, startAngle: .pi, endAngle: 0, clockwise: true)
            sheet.addLine(to: p(0.92, 0.14))
            // A wavy hem of three scallops.
            for i in 0..<3 {
                let x0 = 0.92 - CGFloat(i) * 0.28
                sheet.addQuadCurve(to: p(x0 - 0.14, 0.02), control: p(x0 - 0.03, 0.02))
                sheet.addQuadCurve(to: p(x0 - 0.28, 0.14), control: p(x0 - 0.25, 0.02))
            }
            sheet.closeSubpath()
            fillShaded(ctx, sheet, Palette.ghost, from: 0.7, amount: 0.12)
            // Little arms.
            ctx.setFillColor(Palette.ghost.mixed(with: Palette.stone, 0.15))
            ctx.fillEllipse(in: CGRect(x: 0, y: ht * 0.36, width: w * 0.16, height: ht * 0.1))
            ctx.fillEllipse(in: CGRect(x: w * 0.84, y: ht * 0.4, width: w * 0.16, height: ht * 0.1))
            // Eyes, cheeks and mouth.
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: w * 0.3, y: ht * 0.6, width: w * 0.12, height: ht * 0.12))
            ctx.fillEllipse(in: CGRect(x: w * 0.56, y: ht * 0.6, width: w * 0.12, height: ht * 0.12))
            ctx.setFillColor(Palette.ghost)
            ctx.fillEllipse(in: CGRect(x: w * 0.33, y: ht * 0.67, width: w * 0.04, height: ht * 0.035))
            ctx.fillEllipse(in: CGRect(x: w * 0.59, y: ht * 0.67, width: w * 0.04, height: ht * 0.035))
            ctx.setFillColor(Palette.orange.withAlpha(0.35))
            ctx.fillEllipse(in: CGRect(x: w * 0.2, y: ht * 0.53, width: w * 0.12, height: ht * 0.06))
            ctx.fillEllipse(in: CGRect(x: w * 0.66, y: ht * 0.53, width: w * 0.12, height: ht * 0.06))
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: w * 0.45, y: ht * 0.46, width: w * 0.09, height: ht * 0.09))
        }
    }

    // MARK: Bats

    static func batSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.5).rounded(), height: (h * 0.28).rounded()) }

    /// A little bat, wings up (`frame` 0) or down (1).
    static func batTexture(frame: Int, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = batSize(unit: h)
        return cached("bat-\(frame)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let body = Palette.soot
            let up = frame == 0
            for dir in [CGFloat(-1), 1] {
                let wing = CGMutablePath()
                let root = CGPoint(x: w / 2 + dir * w * 0.06, y: ht * 0.5)
                let tip = CGPoint(x: w / 2 + dir * w * 0.48, y: up ? ht * 0.95 : ht * 0.15)
                wing.move(to: CGPoint(x: root.x, y: root.y + ht * 0.12))
                wing.addQuadCurve(to: tip, control: CGPoint(x: w / 2 + dir * w * 0.25, y: up ? ht * 0.98 : ht * 0.55))
                // Scalloped trailing edge.
                var last = tip
                for i in 1...3 {
                    let t = CGFloat(i) / 3
                    let next = CGPoint(x: tip.x + (root.x - tip.x) * t, y: tip.y + (root.y - ht * 0.08 - tip.y) * t)
                    let mid = CGPoint(x: (last.x + next.x) / 2, y: (last.y + next.y) / 2 + (up ? ht * 0.1 : ht * 0.12))
                    wing.addQuadCurve(to: next, control: mid)
                    last = next
                }
                wing.closeSubpath()
                ctx.addPath(wing)
                ctx.setFillColor(body)
                ctx.fillPath()
            }
            ctx.setFillColor(body)
            ctx.fillEllipse(in: CGRect(x: w * 0.42, y: ht * 0.28, width: w * 0.16, height: ht * 0.5))
            for dir in [CGFloat(-1), 1] {
                let ear = CGMutablePath()
                ear.addLines(between: [CGPoint(x: w / 2 + dir * w * 0.02, y: ht * 0.7), CGPoint(x: w / 2 + dir * w * 0.06, y: ht * 0.9),
                                       CGPoint(x: w / 2 + dir * w * 0.075, y: ht * 0.66)])
                ctx.setFillColor(body)
                ctx.addPath(ear)
                ctx.fillPath()
                ctx.setFillColor(Palette.mustard)
                ctx.fillEllipse(in: CGRect(x: w / 2 + dir * w * 0.035 - w * 0.012, y: ht * 0.58, width: w * 0.024, height: ht * 0.06))
            }
        }
    }

    // MARK: Cobwebs and a spider

    /// Web threads: pale on a dark Dock, stone gray on a light one.
    static var webColor: CGColor { Palette.appearance == .dark ? Palette.ghost.withAlpha(0.6) : Palette.stone.withAlpha(0.85) }

    /// A cobweb tucked into a corner: threads fanning out from the bottom-left, joined by sagging loops.
    static func cobwebTexture(size: CGSize, scale: CGFloat) -> SKTexture {
        cached("cobweb", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let thread = webColor
            let spokes = (0...5).map { i -> CGFloat in CGFloat(i) / 5 * .pi / 2 }
            ctx.setStrokeColor(thread)
            ctx.setLineWidth(max(0.8, w * 0.012))
            ctx.setLineCap(.round)
            for a in spokes {
                ctx.move(to: .zero)
                ctx.addLine(to: CGPoint(x: cos(a) * w * 0.98, y: sin(a) * ht * 0.98))
            }
            ctx.strokePath()
            for ring in [0.3, 0.52, 0.74, 0.94] as [CGFloat] {
                for i in 0..<(spokes.count - 1) {
                    let a0 = spokes[i], a1 = spokes[i + 1]
                    let p0 = CGPoint(x: cos(a0) * w * ring, y: sin(a0) * ht * ring)
                    let p1 = CGPoint(x: cos(a1) * w * ring, y: sin(a1) * ht * ring)
                    // Each loop sags toward the corner.
                    let mid = CGPoint(x: cos((a0 + a1) / 2) * w * ring * 0.86, y: sin((a0 + a1) / 2) * ht * ring * 0.86)
                    ctx.move(to: p0)
                    ctx.addQuadCurve(to: p1, control: mid)
                }
            }
            ctx.strokePath()
        }
    }

    static func spiderTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("spider", size: CGSize(width: s, height: s), scale: scale) { ctx in
            let c = CGPoint(x: s / 2, y: s * 0.45)
            for dir in [CGFloat(-1), 1] {
                for i in 0..<4 {
                    let a = (-35 + CGFloat(i) * 25) * .pi / 180
                    let knee = CGPoint(x: c.x + dir * s * 0.28, y: c.y + sin(a) * s * 0.25 + s * 0.12)
                    let foot = CGPoint(x: c.x + dir * s * 0.46, y: c.y + sin(a) * s * 0.4 - s * 0.06)
                    Brush.stroke(ctx, [c, knee, foot], maxWidth: max(0.8, s * 0.05), color: Palette.soot, minF: 0.8, endF: 0.4)
                }
            }
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: c.x - s * 0.18, y: c.y - s * 0.2, width: s * 0.36, height: s * 0.36))
            ctx.fillEllipse(in: CGRect(x: c.x - s * 0.11, y: c.y + s * 0.1, width: s * 0.22, height: s * 0.2))
            ctx.setFillColor(Palette.ghost)
            ctx.fillEllipse(in: CGRect(x: c.x - s * 0.08, y: c.y + s * 0.17, width: s * 0.06, height: s * 0.06))
            ctx.fillEllipse(in: CGRect(x: c.x + s * 0.02, y: c.y + s * 0.17, width: s * 0.06, height: s * 0.06))
        }
    }

    // MARK: Bubbles

    /// A bubble of potion with a little shine.
    static func bubbleTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("bubble", size: CGSize(width: s, height: s), scale: scale) { ctx in
            ctx.setFillColor(Palette.slime.mixed(with: Palette.green, 0.2))
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: s, height: s))
            ctx.setFillColor(Palette.slime.mixed(with: Palette.ghost, 0.4))
            ctx.fillEllipse(in: CGRect(x: s * 0.12, y: s * 0.12, width: s * 0.76, height: s * 0.76))
            ctx.setFillColor(Palette.ghost.withAlpha(0.85))
            ctx.fillEllipse(in: CGRect(x: s * 0.24, y: s * 0.55, width: s * 0.22, height: s * 0.2))
        }
    }

    // MARK: Words

    /// Chunky rounded words with a plum edge, for "Boo!", "Meow!" and friends.
    static func labelTexture(_ text: String, pointSize: CGFloat, color: CGColor, scale: CGFloat) -> (SKTexture, CGSize) {
        let base = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: pointSize) } ?? base
        let fill: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color) ?? .white]
        let edgeWidth = pointSize * 0.16
        let textSize = (text as NSString).size(withAttributes: fill)
        let size = CGSize(width: ceil(textSize.width + edgeWidth * 2 + 4), height: ceil(textSize.height + edgeWidth * 2 + 4))
        let texture = cached("label-\(text)-\(color.components ?? [])", size: size, scale: scale) { ctx in
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let origin = NSPoint(x: edgeWidth + 2, y: edgeWidth + 2)
            let edge: [NSAttributedString.Key: Any] = [.font: font, .strokeColor: NSColor(cgColor: Palette.night) ?? .black,
                                                       .strokeWidth: edgeWidth / pointSize * 200]
            (text as NSString).draw(at: origin, withAttributes: edge)
            (text as NSString).draw(at: origin, withAttributes: fill)
            NSGraphicsContext.restoreGraphicsState()
        }
        return (texture, size)
    }

    // MARK: Whole pictures, for the app window's tiles

    /// An extra with its moving parts (the cat's tail and eyes, the candles' flames) put together.
    static func tile(_ kind: DecorKind, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = CozyArt.size(of: kind, unit: h)
        let base = CozyArt.texture(kind, unit: h, variant: 1, scale: scale)
        switch kind {
        case .blackCat:
            return cached("cat-tile", size: size, scale: scale) { ctx in
                ctx.draw(catTailTexture(size: size, scale: scale).cgImage(), in: CGRect(origin: .zero, size: size))
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                let eyes = catEyes(catSize: size)
                ctx.draw(catEyesTexture(size: eyes.size, scale: scale).cgImage(),
                         in: CGRect(x: size.width / 2 + eyes.center.x - eyes.size.width / 2, y: eyes.center.y - eyes.size.height / 2,
                                    width: eyes.size.width, height: eyes.size.height))
            }
        case .candles:
            return cached("candles-tile", size: size, scale: scale) { ctx in
                ctx.draw(base.cgImage(), in: CGRect(origin: .zero, size: size))
                let flame = CGSize(width: h * 0.1, height: h * 0.16)
                for wick in candleWicks {
                    ctx.draw(flameTexture(size: flame, scale: scale).cgImage(),
                             in: CGRect(x: wick.x * size.width - flame.width / 2, y: wick.y * size.height - flame.height * 0.15,
                                        width: flame.width, height: flame.height))
                }
            }
        default:
            return base
        }
    }
}
