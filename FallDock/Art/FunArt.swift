import AppKit
import SpriteKit

// Art for the playful bits: jack-o'-lantern faces, sparkles on golden pumpkins, bats,
// a single acorn for the squirrel, and the bouncy words that pop up after a combo.
// Same flat harvest-wagon style and colors as everything else.

enum FunArt {
    private static var cache: [String: SKTexture] = [:]

    private static func cached(_ key: String, size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> SKTexture {
        if let texture = cache[key] { return texture }
        if cache.count > 200 { cache.removeAll() }
        let texture = TextureMaker.make(size: size, scale: scale, draw: draw)
        cache[key] = texture
        return texture
    }

    // MARK: Jack-o'-lantern faces

    /// How many different faces there are.
    static let faceCount = 4

    /// A carved face to lay over a pumpkin sprite of the same kind and height (same size and anchor).
    /// Each cut shows the pumpkin's dark wall, then candlelight inside, brightest in the middle.
    static func faceTexture(kind: PumpkinKind, height: CGFloat, face: Int, scale: CGFloat) -> SKTexture {
        let size = PumpkinArt.size(of: kind, height: height)
        let body = PumpkinArt.bodySize(of: kind, height: height)
        return cached("face-\(kind)-\(Int(height))-\(face)-\(scale)", size: size, scale: scale) { ctx in
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
            return [
                polygon([p(-0.24, 0.52), p(-0.06, 0.52), p(-0.15, 0.68)]),
                polygon([p(0.06, 0.52), p(0.24, 0.52), p(0.15, 0.68)]),
                polygon([p(-0.05, 0.4), p(0.05, 0.4), p(0, 0.48)]),
                mouthWithTeeth(mouth, teeth: [CGRect(origin: p(-0.12, 0.27), size: CGSize(width: w * 0.07, height: h * 0.06)),
                                              CGRect(origin: p(0.05, 0.27), size: CGSize(width: w * 0.07, height: h * 0.06))]),
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
            return [ellipse(p(-0.14, 0.58), w * 0.065, h * 0.1), ellipse(p(0.14, 0.58), w * 0.065, h * 0.1),
                    polygon([p(-0.035, 0.43), p(0.035, 0.43), p(0, 0.48)]), ellipse(p(0, 0.25), w * 0.08, h * 0.1)]
        }
    }

    /// A grin with square teeth left uncut (the pumpkin skin shows through).
    private static func mouthWithTeeth(_ mouth: CGPath, teeth: [CGRect]) -> CGPath {
        let path = CGMutablePath()
        path.addPath(mouth)
        for tooth in teeth { path.addRect(tooth) }
        return path
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

    // MARK: Sparkles

    /// A four-pointed twinkle.
    static func sparkleTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("sparkle-\(Int(s))-\(scale)", size: CGSize(width: s, height: s), scale: scale) { ctx in
            let c = s / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c, y: s))
            path.addQuadCurve(to: CGPoint(x: s, y: c), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: c, y: 0), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: 0, y: c), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: c, y: s), control: CGPoint(x: c, y: c))
            ctx.addPath(path)
            ctx.setFillColor(Palette.peach)
            ctx.fillPath()
        }
    }

    // MARK: Bats

    static func batSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.5).rounded(), height: (h * 0.28).rounded()) }

    /// A little bat, wings up (`frame` 0) or down (1).
    static func batTexture(frame: Int, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = batSize(unit: h)
        return cached("bat-\(frame)-\(Int(h))-\(scale)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let body = Palette.shadowInk.mixed(with: Palette.plum, 0.35)
            let up = frame == 0
            for dir in [CGFloat(-1), 1] {
                let wing = CGMutablePath()
                let root = CGPoint(x: w / 2 + dir * w * 0.06, y: ht * 0.5)
                let tip = CGPoint(x: w / 2 + dir * w * 0.48, y: up ? ht * 0.95 : ht * 0.15)
                wing.move(to: CGPoint(x: root.x, y: root.y + ht * 0.12))
                wing.addQuadCurve(to: tip, control: CGPoint(x: w / 2 + dir * w * 0.25, y: up ? ht * 0.98 : ht * 0.55))
                // Scalloped trailing edge.
                let scallops = 3
                var last = tip
                for i in 1...scallops {
                    let t = CGFloat(i) / CGFloat(scallops)
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
            // Ears and eyes.
            for dir in [CGFloat(-1), 1] {
                let ear = CGMutablePath()
                ear.addLines(between: [CGPoint(x: w / 2 + dir * w * 0.02, y: ht * 0.7), CGPoint(x: w / 2 + dir * w * 0.06, y: ht * 0.9),
                                       CGPoint(x: w / 2 + dir * w * 0.075, y: ht * 0.66)])
                ctx.addPath(ear)
                ctx.fillPath()
                ctx.setFillColor(Palette.mustard)
                ctx.fillEllipse(in: CGRect(x: w / 2 + dir * w * 0.035 - w * 0.012, y: ht * 0.58, width: w * 0.024, height: ht * 0.06))
                ctx.setFillColor(body)
            }
        }
    }

    // MARK: Acorn

    /// One acorn, standing up, for the squirrel.
    static func acornTexture(size s: CGFloat, scale: CGFloat) -> SKTexture {
        cached("acorn-\(Int(s))-\(scale)", size: CGSize(width: s * 0.9, height: s), scale: scale) { ctx in
            CozyArt.acorn(ctx, bottom: CGPoint(x: s * 0.45, y: 1), size: s * 0.92, angle: 0)
        }
    }

    // MARK: Words

    /// Chunky rounded words in orange with a plum edge, for combos and finds.
    static func labelTexture(_ text: String, pointSize: CGFloat, color: CGColor = Palette.orange, scale: CGFloat) -> (SKTexture, CGSize) {
        let base = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: pointSize) } ?? base
        let fill: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color) ?? .orange]
        let edgeWidth = pointSize * 0.16
        let textSize = (text as NSString).size(withAttributes: fill)
        let size = CGSize(width: ceil(textSize.width + edgeWidth * 2 + 4), height: ceil(textSize.height + edgeWidth * 2 + 4))
        let key = "label-\(text)-\(Int(pointSize))-\(color.components ?? [])-\(scale)"
        let texture = cached(key, size: size, scale: scale) { ctx in
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let origin = NSPoint(x: edgeWidth + 2, y: edgeWidth + 2)
            // The plum edge: a wide stroke drawn first, then the fill on top.
            let edge: [NSAttributedString.Key: Any] = [.font: font, .strokeColor: NSColor(cgColor: Palette.plum) ?? .black,
                                                       .strokeWidth: edgeWidth / pointSize * 200]
            (text as NSString).draw(at: origin, withAttributes: edge)
            (text as NSString).draw(at: origin, withAttributes: fill)
            NSGraphicsContext.restoreGraphicsState()
        }
        return (texture, size)
    }
}
