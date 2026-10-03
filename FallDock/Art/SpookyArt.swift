import AppKit
import SpriteKit

// Halloween's art: jack-o'-lantern faces, coffins, tombstones, a black cat, a bubbling cauldron,
// candy corn, dripping candles, a friendly ghost, bats, a dangling spider and cobwebs.
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
        case .tombstone: drawTombstone(ctx, size: size, h: h, rng: &rng)
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

    // MARK: Jack-o'-lantern faces

    static let faceCount = 4

    /// A carved face to lay over a pumpkin sprite of the same kind and height (same size and anchor).
    /// Each cut shows the pumpkin's dark wall, then candlelight inside, brightest in the middle.
    static func faceTexture(kind: PumpkinKind, height: CGFloat, face: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let body = PumpkinArt.bodySize(of: kind, height: height)
        return cached("face-\(kind)-\(Int(height))-\(face)", size: size, scale: scale) { ctx in
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
        func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2), transform: nil)
        }
        switch face % faceCount {
        case 0:
            // Classic: triangle eyes and nose, a wide grin with two square teeth.
            let mouth = CGMutablePath()
            mouth.move(to: p(-0.27, 0.36))
            mouth.addQuadCurve(to: p(0.27, 0.36), control: p(0, 0.08))
            mouth.addQuadCurve(to: p(-0.27, 0.36), control: p(0, 0.24))
            mouth.addRect(CGRect(origin: p(-0.12, 0.27), size: CGSize(width: w * 0.07, height: h * 0.06)))
            mouth.addRect(CGRect(origin: p(0.05, 0.27), size: CGSize(width: w * 0.07, height: h * 0.06)))
            return [
                polygon([p(-0.24, 0.52), p(-0.06, 0.52), p(-0.15, 0.68)]),
                polygon([p(0.06, 0.52), p(0.24, 0.52), p(0.15, 0.68)]),
                polygon([p(-0.05, 0.4), p(0.05, 0.4), p(0, 0.48)]),
                mouth,
            ]
        case 1:
            // Happy: round eyes and a big grin with a row of pointy teeth along the top.
            var smile: [CGPoint] = []
            for i in 0...10 {
                let t = CGFloat(i) / 10
                let tooth: CGFloat = i % 2 == 1 && i < 10 ? 0.06 : 0
                smile.append(p(-0.3 + 0.6 * t, 0.42 - 0.1 * sin(.pi * t) - tooth))
            }
            for i in stride(from: 10, through: 0, by: -1) {
                let t = CGFloat(i) / 10
                smile.append(p(-0.3 + 0.6 * t, 0.42 - 0.3 * sin(.pi * t)))
            }
            return [ellipse(p(-0.15, 0.62), w * 0.075, h * 0.11), ellipse(p(0.15, 0.62), w * 0.075, h * 0.11),
                    polygon([p(-0.04, 0.47), p(0.04, 0.47), p(0, 0.53)]), polygon(smile)]
        case 2:
            // Spooky: slanted eyes and a jagged mouth.
            var jagged: [CGPoint] = []
            for i in 0...6 { jagged.append(p(-0.26 + CGFloat(i) * 0.52 / 6, i % 2 == 0 ? 0.32 : 0.25)) }
            for i in stride(from: 6, through: 0, by: -1) { jagged.append(p(-0.26 + CGFloat(i) * 0.52 / 6, i % 2 == 0 ? 0.18 : 0.12)) }
            return [polygon([p(-0.25, 0.6), p(-0.06, 0.52), p(-0.1, 0.62)]),
                    polygon([p(0.25, 0.6), p(0.06, 0.52), p(0.1, 0.62)]),
                    polygon([p(-0.04, 0.4), p(0.04, 0.4), p(0, 0.47)]), polygon(jagged)]
        default:
            // Surprised: round eyes, a little nose and an "O" mouth.
            return [ellipse(p(-0.14, 0.58), w * 0.07, h * 0.11), ellipse(p(0.14, 0.58), w * 0.07, h * 0.11),
                    polygon([p(-0.035, 0.43), p(0.035, 0.43), p(0, 0.48)]), ellipse(p(0, 0.25), w * 0.09, h * 0.11)]
        }
    }

    private static func carve(_ ctx: CGContext, _ cut: CGPath) {
        let box = cut.boundingBoxOfPath
        func scaled(_ s: CGFloat, dy: CGFloat = 0) -> CGPath {
            var t = CGAffineTransform(translationX: box.midX, y: box.midY + dy).scaledBy(x: s, y: s).translatedBy(x: -box.midX, y: -box.midY)
            return cut.copy(using: &t) ?? cut
        }
        // The cut wall, candlelight, and its bright middle. Even-odd filling leaves teeth uncut.
        ctx.addPath(cut)
        ctx.setFillColor(Palette.rust.mixed(with: Palette.shadowInk, 0.55))
        ctx.fillPath(using: .evenOdd)
        ctx.addPath(scaled(0.84, dy: box.height * 0.05))
        ctx.setFillColor(Palette.mustard.mixed(with: Palette.orange, 0.25))
        ctx.fillPath(using: .evenOdd)
        ctx.addPath(scaled(0.5, dy: box.height * 0.08))
        ctx.setFillColor(Palette.peach)
        ctx.fillPath(using: .evenOdd)
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
