import AppKit
import SpriteKit

// Halloween's art: jack-o'-lantern faces, crypt pedestals, tombstones, a black cat, a bubbling cauldron,
// assorted candy, dripping candles, a skull, a zombie hand, a friendly ghost, bats, a dangling spider,
// cobwebs and purple graveyard dirt.
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
        case .crypt: drawCrypt(ctx, size: size, h: h)
        case .tombstone: drawTombstone(ctx, size: size, h: h, rng: &rng)
        case .blackCat: drawCat(ctx, size: size, h: h)
        case .cauldron: drawCauldron(ctx, size: size, h: h)
        case .candy: drawCandyPile(ctx, size: size, h: h)
        case .skull: drawSkull(ctx, size: size, h: h)
        case .candles: drawCandles(ctx, size: size, h: h)
        default: break
        }
    }

    /// A crumbling stone crypt pedestal: a plinth, a block of stone courses with a carved bat, an
    /// overhanging top slab, cracks, moss and a cobweb in the corner.
    private static func drawCrypt(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let stone = Palette.stone.mixed(with: Palette.witch, 0.25)
        let mortar = shade(stone, 0.35)
        // Plinth, body and top slab.
        fillShaded(ctx, CGPath(rect: CGRect(x: w * 0.04, y: 0, width: w * 0.92, height: ht * 0.14), transform: nil), shade(stone, 0.1), from: 0.78)
        let body = CGRect(x: w * 0.12, y: ht * 0.14, width: w * 0.76, height: ht * 0.62)
        fillShaded(ctx, CGPath(rect: body, transform: nil), stone, from: 0.74, amount: 0.22)
        let slab = CGRect(x: w * 0.04, y: ht * 0.76, width: w * 0.92, height: ht * 0.2)
        fillShaded(ctx, CGPath(roundedRect: slab, cornerWidth: ht * 0.03, cornerHeight: ht * 0.03, transform: nil),
                   stone.mixed(with: Palette.ghost, 0.15), from: 0.8, amount: 0.2)
        // Stone courses.
        ctx.saveGState()
        ctx.clip(to: body)
        ctx.setFillColor(mortar)
        let rows = 3
        for row in 0..<rows {
            let y = body.minY + body.height * CGFloat(row) / CGFloat(rows)
            ctx.fill(CGRect(x: body.minX, y: y, width: body.width, height: max(0.8, h * 0.012)))
            let offset: CGFloat = row % 2 == 0 ? 0.33 : 0.16
            var x = body.minX + body.width * offset
            while x < body.maxX {
                ctx.fill(CGRect(x: x, y: y, width: max(0.8, h * 0.012), height: body.height / CGFloat(rows)))
                x += body.width * 0.34
            }
        }
        ctx.restoreGState()
        // A bat carved into the middle (on a smooth plaque).
        let plaque = CGRect(x: w * 0.36, y: ht * 0.3, width: w * 0.28, height: ht * 0.32)
        ctx.setFillColor(stone.mixed(with: Palette.ghost, 0.1))
        ctx.addPath(CGPath(roundedRect: plaque, cornerWidth: ht * 0.04, cornerHeight: ht * 0.04, transform: nil))
        ctx.fillPath()
        let bat = batSize(unit: h * 0.6)
        ctx.draw(batTexture(frame: 0, unit: h * 0.6, scale: 2).cgImage(),
                 in: CGRect(x: plaque.midX - bat.width / 2, y: plaque.midY - bat.height / 2, width: bat.width, height: bat.height))
        // Cracks, a chip off the slab, moss.
        Brush.stroke(ctx, [p(0.22, 0.7), p(0.27, 0.5), p(0.22, 0.34)], maxWidth: max(1, h * 0.02), color: mortar, minF: 0.5, endF: 0.1)
        Brush.stroke(ctx, [p(0.8, 0.62), p(0.74, 0.46), p(0.79, 0.3)], maxWidth: max(1, h * 0.018), color: mortar, minF: 0.5, endF: 0.1)
        ctx.setFillColor(Palette.green.withAlpha(0.8))
        for (x, y, r) in [(0.1, 0.94, 0.05), (0.16, 0.92, 0.04), (0.84, 0.13, 0.04), (0.9, 0.12, 0.05)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: w * x - h * r, y: ht * y - h * r * 0.6, width: h * r * 2, height: h * r * 1.2))
        }
        // A cobweb tucked under the slab's left corner.
        ctx.setStrokeColor(webColor)
        ctx.setLineWidth(max(0.6, h * 0.008))
        let corner = CGPoint(x: body.minX, y: slab.minY)
        for a in stride(from: CGFloat(0), through: .pi / 2, by: .pi / 8) {
            ctx.move(to: corner)
            ctx.addLine(to: CGPoint(x: corner.x + cos(a) * h * 0.2, y: corner.y - sin(a) * h * 0.2))
        }
        for r in [0.1, 0.17] as [CGFloat] {
            ctx.move(to: CGPoint(x: corner.x + h * r, y: corner.y))
            ctx.addQuadCurve(to: CGPoint(x: corner.x, y: corner.y - h * r), control: CGPoint(x: corner.x + h * r * 0.5, y: corner.y - h * r * 0.5))
        }
        ctx.strokePath()
    }

    /// A rounded gravestone with "RIP", a crack and tufts of grass.
    private static func drawTombstone(_ ctx: CGContext, size: CGSize, h: CGFloat, rng: inout SeededRandom) {
        let w = size.width, ht = size.height
        let stone = CGMutablePath()
        let left = w * 0.12, right = w * 0.88, top = ht * 0.96, base = ht * 0.05
        let radius = (right - left) / 2
        stone.move(to: CGPoint(x: left, y: base))
        stone.addLine(to: CGPoint(x: left, y: top - radius))
        stone.addArc(center: CGPoint(x: w / 2, y: top - radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
        stone.addLine(to: CGPoint(x: right, y: base))
        stone.closeSubpath()
        fillShaded(ctx, stone, Palette.stone, from: 0.7, amount: 0.25)

        // "RIP", carved in.
        let font = NSFont.systemFont(ofSize: h * 0.15, weight: .heavy)
        let text = "RIP" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: shade(Palette.stone, 0.45)) ?? .gray]
        let textSize = text.size(withAttributes: attributes)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        text.draw(at: NSPoint(x: w / 2 - textSize.width / 2, y: ht * 0.52 - textSize.height / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()

        // A crack, and moss at the foot.
        Brush.stroke(ctx, [CGPoint(x: w * 0.3, y: top - radius * 0.3), CGPoint(x: w * 0.38, y: ht * 0.7), CGPoint(x: w * 0.32, y: ht * 0.62)],
                     maxWidth: max(1, h * 0.02), color: shade(Palette.stone, 0.5), minF: 0.4, endF: 0.1)
        for _ in 0..<7 {
            let x = rng.float(w * 0.08...w * 0.92)
            let lean = rng.float(-3...3)
            Brush.stroke(ctx, [CGPoint(x: x, y: 0), CGPoint(x: x + lean * 0.5, y: ht * 0.07), CGPoint(x: x + lean, y: ht * rng.float(0.1...0.16))],
                         maxWidth: max(1.2, h * 0.025), color: Palette.green, minF: 0.9, endF: 0.1)
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

    /// A heap of assorted candy: a lollipop, a candy cane, wrapped sweets and an eyeball candy.
    private static func drawCandyPile(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let s = h * 0.26
        candyCane(ctx, bottom: CGPoint(x: w * 0.2, y: ht * 0.06), height: ht * 0.92, angle: 8)
        lollipop(ctx, bottom: CGPoint(x: w * 0.66, y: ht * 0.08), height: ht * 0.9, angle: -10, color: Palette.candyPink)
        wrapped(ctx, center: CGPoint(x: w * 0.3, y: ht * 0.2), size: s, angle: -15, color: Palette.candyMint)
        wrapped(ctx, center: CGPoint(x: w * 0.74, y: ht * 0.2), size: s, angle: 20, color: Palette.candyPurple)
        eyeball(ctx, center: CGPoint(x: w * 0.5, y: ht * 0.2), radius: s * 0.4, iris: Palette.candyMint.mixed(with: Palette.witch, 0.4))
        wrapped(ctx, center: CGPoint(x: w * 0.52, y: ht * 0.46), size: s * 0.9, angle: 5, color: Palette.candyPink)
    }

    /// A wrapped sweet with twisted ends.
    static func wrapped(_ ctx: CGContext, center c: CGPoint, size s: CGFloat, angle: CGFloat, color: CGColor) {
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: angle * .pi / 180)
        for dir in [CGFloat(-1), 1] {
            let twist = CGMutablePath()
            twist.addLines(between: [CGPoint(x: dir * s * 0.3, y: 0), CGPoint(x: dir * s * 0.62, y: s * 0.24), CGPoint(x: dir * s * 0.55, y: 0),
                                     CGPoint(x: dir * s * 0.62, y: -s * 0.24)])
            twist.closeSubpath()
            ctx.addPath(twist)
            ctx.setFillColor(color.mixed(with: Palette.ghost, 0.25))
            ctx.fillPath()
        }
        let body = CGRect(x: -s * 0.36, y: -s * 0.24, width: s * 0.72, height: s * 0.48)
        ctx.setFillColor(color)
        ctx.fillEllipse(in: body)
        // Stripes and a shine.
        ctx.saveGState()
        ctx.addEllipse(in: body)
        ctx.clip()
        ctx.setFillColor(Palette.ghost.withAlpha(0.6))
        for x in [-0.18, 0.06] as [CGFloat] {
            ctx.fill(CGRect(x: s * x, y: -s * 0.3, width: s * 0.08, height: s * 0.6))
        }
        ctx.setFillColor(Palette.shadowInk.withAlpha(0.15))
        ctx.fill(CGRect(x: -s, y: -s, width: s * 2, height: s * 0.84))
        ctx.restoreGState()
        ctx.restoreGState()
    }

    /// A swirly lollipop on a stick.
    static func lollipop(_ ctx: CGContext, bottom: CGPoint, height: CGFloat, angle: CGFloat, color: CGColor) {
        ctx.saveGState()
        ctx.translateBy(x: bottom.x, y: bottom.y)
        ctx.rotate(by: angle * .pi / 180)
        let r = height * 0.26
        Brush.stroke(ctx, [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: height * 0.4), CGPoint(x: 0, y: height - r * 1.6)], maxWidth: max(1.2, r * 0.18),
                     color: Palette.ghost, minF: 1)
        let center = CGPoint(x: 0, y: height - r)
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: -r, y: center.y - r, width: r * 2, height: r * 2))
        // The swirl.
        var points: [CGPoint] = []
        for i in 0...40 {
            let t = CGFloat(i) / 40
            let a = t * .pi * 4
            points.append(CGPoint(x: center.x + cos(a) * r * 0.85 * t, y: center.y + sin(a) * r * 0.85 * t))
        }
        Brush.trail(ctx, points.reversed(), maxWidth: r * 0.3, color: Palette.ghost.withAlpha(0.85), minF: 0.2)
        ctx.restoreGState()
    }

    /// A white candy cane with red stripes.
    static func candyCane(_ ctx: CGContext, bottom: CGPoint, height: CGFloat, angle: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: bottom.x, y: bottom.y)
        ctx.rotate(by: angle * .pi / 180)
        let width = height * 0.16
        var points: [CGPoint] = []
        for i in 0...16 { points.append(CGPoint(x: 0, y: height * 0.7 * CGFloat(i) / 16)) }
        for i in 1...16 {
            let a = CGFloat.pi - CGFloat.pi * CGFloat(i) / 16
            points.append(CGPoint(x: height * 0.16 + cos(a) * height * 0.16, y: height * 0.7 + sin(a) * height * 0.2))
        }
        ctx.addPath(Brush.outline(points) { _ in width })
        ctx.setFillColor(Palette.ghost)
        ctx.fillPath()
        // Diagonal stripes, clipped to the cane.
        ctx.saveGState()
        ctx.addPath(Brush.outline(points) { _ in width })
        ctx.clip()
        ctx.setFillColor(Palette.candyRed)
        var y = -height * 0.1
        while y < height * 1.2 {
            let stripe = CGMutablePath()
            stripe.addLines(between: [CGPoint(x: -width * 2, y: y), CGPoint(x: height * 0.5, y: y + height * 0.2),
                                      CGPoint(x: height * 0.5, y: y + height * 0.2 + width * 0.6), CGPoint(x: -width * 2, y: y + width * 0.6)])
            stripe.closeSubpath()
            ctx.addPath(stripe)
            ctx.fillPath()
            y += width * 1.4
        }
        ctx.restoreGState()
        ctx.restoreGState()
    }

    /// A round eyeball candy with a colored iris.
    static func eyeball(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, iris: CGColor) {
        ctx.setFillColor(Palette.ghost)
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setFillColor(Palette.stone.withAlpha(0.35))
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.2, y: c.y - r, width: r * 1.2, height: r * 1.6))
        ctx.setFillColor(iris)
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.15, y: c.y - r * 0.35, width: r * 0.8, height: r * 0.8))
        ctx.setFillColor(Palette.soot)
        ctx.fillEllipse(in: CGRect(x: c.x + r * 0.03, y: c.y - r * 0.16, width: r * 0.42, height: r * 0.42))
        ctx.setFillColor(Palette.ghost)
        ctx.fillEllipse(in: CGRect(x: c.x + r * 0.08, y: c.y + r * 0.06, width: r * 0.14, height: r * 0.14))
    }

    /// One piece of candy for flinging: `variant` picks which.
    static func candyTexture(variant: Int, size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("candy-\(variant % 5)", size: CGSize(width: s, height: s), scale: scale) { ctx in
            let c = CGPoint(x: s / 2, y: s / 2)
            switch variant % 5 {
            case 0: wrapped(ctx, center: c, size: s * 0.8, angle: 0, color: Palette.candyPink)
            case 1: wrapped(ctx, center: c, size: s * 0.8, angle: 0, color: Palette.candyMint)
            case 2: wrapped(ctx, center: c, size: s * 0.8, angle: 0, color: Palette.candyPurple)
            case 3: eyeball(ctx, center: c, radius: s * 0.32, iris: Palette.candyPurple)
            default: lollipop(ctx, bottom: CGPoint(x: s / 2, y: s * 0.05), height: s * 0.9, angle: 0, color: Palette.candyMint)
            }
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

    // MARK: Jack-o'-lantern faces

    static let faceCount = 4

    /// A carved face to lay over a pumpkin sprite of the same kind and height (same size and anchor):
    /// bright candlelight in each cut, with the orange wall of the pumpkin showing along its top edge.
    static func faceTexture(kind: PumpkinKind, height: CGFloat, face: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let body = PumpkinArt.bodySize(of: kind, height: height)
        return cached("face-\(kind)-\(Int(height))-\(face % faceCount)", size: size, scale: scale) { ctx in
            let cx = size.width / 2, base = PumpkinArt.pad
            // Faces on tall pumpkins stay narrower.
            let w = min(body.width, body.height * 1.15), h = body.height
            for cut in faceCuts(face, cx: cx, base: base, w: w, h: h) {
                carve(ctx, cut)
            }
        }
    }

    private static func faceCuts(_ face: Int, cx: CGFloat, base: CGFloat, w: CGFloat, h: CGFloat) -> [CGPath] {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: cx + x * w, y: base + y * h) }
        func polygon(_ points: [CGPoint]) -> CGPath {
            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            return path
        }
        /// A wide grin, with square teeth left uncut along the top (and one at the bottom).
        func grin(top: CGFloat, depth: CGFloat, width: CGFloat, teeth: [CGFloat], bottomTooth: Bool) -> CGPath {
            let path = CGMutablePath()
            // A flat-ish top lip and a deep, round bottom.
            path.move(to: p(-width, top + 0.02))
            path.addQuadCurve(to: p(width, top + 0.02), control: p(0, top - depth * 2.6))
            path.addQuadCurve(to: p(-width, top + 0.02), control: p(0, top - depth * 0.15))
            let tooth = CGSize(width: w * 0.1, height: h * 0.09)
            for x in teeth {
                path.addRect(CGRect(x: cx + x * w - tooth.width / 2, y: base + (top - depth * 0.1) * h - tooth.height, width: tooth.width, height: tooth.height * 1.2))
            }
            if bottomTooth {
                path.addRect(CGRect(x: cx - tooth.width / 2, y: base + (top - depth * 1.32) * h - tooth.height * 0.2, width: tooth.width, height: tooth.height))
            }
            return path
        }
        switch face % faceCount {
        case 0:
            // Pointy triangle eyes leaning in, and a big toothy grin.
            return [polygon([p(-0.31, 0.5), p(-0.06, 0.5), p(-0.1, 0.72)]),
                    polygon([p(0.31, 0.5), p(0.06, 0.5), p(0.1, 0.72)]),
                    grin(top: 0.4, depth: 0.14, width: 0.34, teeth: [-0.12, 0.12], bottomTooth: true)]
        case 1:
            // Happy closed eyes, curved like rainbows, and a wide grin.
            func happyEye(_ x: CGFloat) -> CGPath {
                let eye = CGMutablePath()
                eye.move(to: p(x - 0.15, 0.54))
                eye.addQuadCurve(to: p(x + 0.15, 0.54), control: p(x, 0.82))
                eye.addQuadCurve(to: p(x - 0.15, 0.54), control: p(x, 0.66))
                return eye
            }
            return [happyEye(-0.17), happyEye(0.17), grin(top: 0.42, depth: 0.15, width: 0.36, teeth: [-0.16, 0, 0.16], bottomTooth: false)]
        case 2:
            // Big round eyes and a grin with a gap-toothed smile.
            func round(_ x: CGFloat) -> CGPath {
                CGPath(ellipseIn: CGRect(x: cx + (x - 0.12) * w, y: base + 0.5 * h, width: w * 0.24, height: h * 0.24), transform: nil)
            }
            return [round(-0.17), round(0.17), grin(top: 0.4, depth: 0.13, width: 0.3, teeth: [-0.1, 0.1], bottomTooth: true)]
        default:
            // Mischievous: eyes slanting down toward the middle, and a jagged grin.
            var jagged: [CGPoint] = []
            for i in 0...8 {
                let t = CGFloat(i) / 8
                jagged.append(p(-0.32 + 0.64 * t, 0.4 - 0.08 * sin(.pi * t) + (i % 2 == 0 ? 0 : -0.06)))
            }
            for i in stride(from: 8, through: 0, by: -1) {
                let t = CGFloat(i) / 8
                jagged.append(p(-0.32 + 0.64 * t, 0.36 - 0.24 * sin(.pi * t)))
            }
            return [polygon([p(-0.3, 0.68), p(-0.06, 0.56), p(-0.26, 0.5)]),
                    polygon([p(0.3, 0.68), p(0.06, 0.56), p(0.26, 0.5)]),
                    polygon(jagged)]
        }
    }

    private static func carve(_ ctx: CGContext, _ cut: CGPath) {
        let box = cut.boundingBoxOfPath
        // The orange inside wall, then the candlelight shifted down a little so the wall shows along
        // the top edge. Even-odd filling leaves teeth uncut.
        ctx.addPath(cut)
        ctx.setFillColor(Palette.orange.mixed(with: Palette.rust, 0.35))
        ctx.fillPath(using: .evenOdd)
        ctx.saveGState()
        ctx.addPath(cut)
        ctx.clip(using: .evenOdd)
        var down = CGAffineTransform(translationX: 0, y: -box.height * 0.16)
        ctx.addPath(cut.copy(using: &down) ?? cut)
        ctx.setFillColor(Palette.candlelight)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    // MARK: The ghost

    static func ghostSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.82).rounded(), height: (h * 0.56).rounded()) }

    /// A cute ghost seen from the side, flying right: a round head, a body that trails off into a
    /// wavy, curling tail, dot eyes, a little smile and rosy cheeks.
    static func ghostTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = ghostSize(unit: h)
        return cached("ghost-side", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let r = ht * 0.42
            let head = p(0.7, 0.52)
            let body = CGMutablePath()
            body.move(to: CGPoint(x: head.x, y: head.y + r))
            body.addArc(center: head, radius: r, startAngle: .pi / 2, endAngle: -.pi / 2.4, clockwise: true)
            // A wavy underside that sweeps back and up into a curling tail.
            body.addQuadCurve(to: p(0.48, 0.14), control: p(0.6, 0.04))
            body.addQuadCurve(to: p(0.3, 0.26), control: p(0.38, 0.12))
            body.addQuadCurve(to: p(0.13, 0.5), control: p(0.2, 0.3))
            body.addQuadCurve(to: p(0.04, 0.88), control: p(0.03, 0.62))
            // The tail tip curls over and the top runs back to the head.
            body.addQuadCurve(to: p(0.2, 0.72), control: p(0.14, 0.92))
            body.addCurve(to: CGPoint(x: head.x, y: head.y + r), control1: p(0.3, 0.86), control2: p(0.48, 0.98))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.setFillColor(Palette.ghost)
            ctx.fillPath()
            // A cool blue shade along the underside.
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.setFillColor(Palette.witch.mixed(with: Palette.ghost, 0.75).withAlpha(0.6))
            ctx.fillEllipse(in: CGRect(x: -w * 0.1, y: -ht * 0.6, width: w * 1.1, height: ht * 0.9))
            ctx.restoreGState()
            // A little arm.
            ctx.setFillColor(Palette.ghost)
            ctx.fillEllipse(in: CGRect(x: w * 0.52, y: ht * 0.26, width: w * 0.14, height: ht * 0.14))
            // Face, on the front of the head.
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: w * 0.7, y: ht * 0.56, width: w * 0.055, height: ht * 0.1))
            ctx.fillEllipse(in: CGRect(x: w * 0.84, y: ht * 0.56, width: w * 0.055, height: ht * 0.1))
            ctx.setStrokeColor(Palette.soot)
            ctx.setLineWidth(max(1, h * 0.022))
            ctx.addArc(center: p(0.8, 0.52), radius: w * 0.04, startAngle: -.pi * 0.15, endAngle: -.pi * 0.85, clockwise: true)
            ctx.strokePath()
            ctx.setFillColor(Palette.candyPink.withAlpha(0.55))
            ctx.fillEllipse(in: CGRect(x: w * 0.63, y: ht * 0.46, width: w * 0.07, height: ht * 0.07))
            ctx.fillEllipse(in: CGRect(x: w * 0.9, y: ht * 0.46, width: w * 0.06, height: ht * 0.07))
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

    /// How far a cobweb of size `s` reaches in over the Dock's top corner, across and down.
    static func cobwebOverlap(size s: CGFloat) -> CGFloat { (s * 0.3).rounded() }

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

    // MARK: Zombie hand

    static func handSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.3).rounded(), height: (h * 0.46).rounded()) }

    /// A zombie hand reaching up out of the ground, with a torn sleeve.
    static func handTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = handSize(unit: h)
        return cached("hand", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let skin = Palette.slime.mixed(with: Palette.stone, 0.45)
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

    // MARK: Skull

    /// A cute skull with big round eye sockets, resting on a crossed bone.
    private static func drawSkull(_ ctx: CGContext, size: CGSize, h: CGFloat) {
        let w = size.width, ht = size.height
        let bone = Palette.ghost.mixed(with: Palette.peach, 0.35)
        // The bone behind it, lying across.
        Brush.stroke(ctx, [CGPoint(x: w * 0.1, y: ht * 0.16), CGPoint(x: w * 0.5, y: ht * 0.12), CGPoint(x: w * 0.9, y: ht * 0.2)],
                     maxWidth: h * 0.06, color: bone, minF: 1)
        for end in [CGPoint(x: w * 0.08, y: ht * 0.16), CGPoint(x: w * 0.92, y: ht * 0.2)] {
            for dy in [CGFloat(-1), 1] {
                ctx.setFillColor(bone)
                ctx.fillEllipse(in: CGRect(x: end.x - h * 0.04, y: end.y + dy * h * 0.025 - h * 0.035, width: h * 0.07, height: h * 0.07))
            }
        }
        // Cranium and jaw.
        let skull = CGMutablePath()
        skull.addEllipse(in: CGRect(x: w * 0.2, y: ht * 0.26, width: w * 0.6, height: ht * 0.72))
        skull.addRoundedRect(in: CGRect(x: w * 0.32, y: ht * 0.1, width: w * 0.36, height: ht * 0.3), cornerWidth: w * 0.06, cornerHeight: w * 0.06)
        fillShaded(ctx, skull, bone, from: 0.68, amount: 0.15)
        // Eye sockets with a twinkle, a little nose and teeth.
        ctx.setFillColor(Palette.soot)
        ctx.fillEllipse(in: CGRect(x: w * 0.3, y: ht * 0.46, width: w * 0.16, height: ht * 0.24))
        ctx.fillEllipse(in: CGRect(x: w * 0.54, y: ht * 0.46, width: w * 0.16, height: ht * 0.24))
        ctx.setFillColor(Palette.ghost)
        ctx.fillEllipse(in: CGRect(x: w * 0.36, y: ht * 0.6, width: w * 0.04, height: ht * 0.05))
        ctx.fillEllipse(in: CGRect(x: w * 0.6, y: ht * 0.6, width: w * 0.04, height: ht * 0.05))
        let nose = CGMutablePath()
        nose.addLines(between: [CGPoint(x: w * 0.47, y: ht * 0.36), CGPoint(x: w * 0.53, y: ht * 0.36), CGPoint(x: w * 0.5, y: ht * 0.43)])
        nose.closeSubpath()
        ctx.setFillColor(Palette.soot)
        ctx.addPath(nose)
        ctx.fillPath()
        for i in 0..<3 {
            ctx.fill(CGRect(x: w * (0.4 + CGFloat(i) * 0.08), y: ht * 0.13, width: w * 0.02, height: ht * 0.12))
        }
    }

    // MARK: Purple dirt

    /// A band of purple graveyard dirt along the Dock, with a lumpy top, pebbles and tufts of grass.
    static func dirtTexture(width: CGFloat, height: CGFloat, seed: Int, unit k: CGFloat, scale: CGFloat) -> SKTexture {
        cached("dirt-\(seed)-\(Int(k * 100))", size: CGSize(width: width, height: height), scale: scale) { ctx in
            var rng = SeededRandom(seed: UInt64(seed) &* 3571 &+ 11)
            let soil = Palette.witch.mixed(with: Palette.soot, 0.45)
            func top(_ x: CGFloat) -> CGFloat {
                height * 0.42 + (sin(x / (23 * k)) * 2.2 + sin(x / (61 * k)) * 3.4 + sin(x / (9 * k)) * 0.8) * k
            }
            // Rounded ends, so it doesn't stop square.
            let dirt = CGMutablePath()
            dirt.move(to: CGPoint(x: 0, y: 0))
            dirt.addQuadCurve(to: CGPoint(x: 8 * k, y: top(8 * k)), control: CGPoint(x: 0, y: top(0)))
            var x = 8 * k
            while x < width - 8 * k {
                dirt.addLine(to: CGPoint(x: x, y: top(x)))
                x += 3
            }
            dirt.addQuadCurve(to: CGPoint(x: width, y: 0), control: CGPoint(x: width, y: top(width)))
            dirt.closeSubpath()
            ctx.addPath(dirt)
            ctx.setFillColor(soil)
            ctx.fillPath()
            // A lighter crust along the top.
            x = 4 * k
            while x < width - 4 * k {
                Brush.stroke(ctx, [CGPoint(x: x, y: top(x) - 1.6 * k), CGPoint(x: x + 6 * k, y: top(x + 6 * k) - 1.4 * k),
                                   CGPoint(x: x + 12 * k, y: top(x + 12 * k) - 1.6 * k)],
                             maxWidth: 2.4 * k, color: soil.mixed(with: Palette.witch, 0.55), minF: 0.3)
                x += rng.float(14...26) * k
            }
            // Pebbles.
            for _ in 0..<Int(width / (14 * k)) {
                let px = rng.float(6 * k...(width - 6 * k))
                let py = rng.float(1...max(2, top(px) - 3 * k))
                let r = rng.float(0.8...1.8) * k
                ctx.setFillColor(rng.float(0...1) < 0.5 ? Palette.soot.withAlpha(0.6) : Palette.stone.withAlpha(0.55))
                ctx.fillEllipse(in: CGRect(x: px - r, y: py - r * 0.7, width: r * 2, height: r * 1.4))
            }
            // Tufts of grass poking out.
            x = rng.float(10...30) * k
            while x < width - 10 * k {
                for blade in 0..<3 {
                    let bx = x + CGFloat(blade) * 1.6 * k
                    let lean = rng.float(-2.5...2.5) * k
                    Brush.stroke(ctx, [CGPoint(x: bx, y: top(bx) - 1), CGPoint(x: bx + lean * 0.4, y: top(bx) + 3 * k),
                                       CGPoint(x: bx + lean, y: top(bx) + rng.float(5...8) * k)],
                                 maxWidth: 1.6 * k, color: Palette.green.mixed(with: Palette.slime, 0.3), minF: 0.9, endF: 0.1)
                }
                x += rng.float(40...90) * k
            }
        }
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
