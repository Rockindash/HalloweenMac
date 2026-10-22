import AppKit
import SpriteKit

// Haunting while you're away: the eyes that open in the dark and the wispy ghosts that gather over
// the Dock. Same flat style as the rest of Halloween: flat fills and no outlines.

enum HauntingArt {
    private static var cache: [String: SKTexture] = [:]
    static func clearCache() { cache.removeAll() }

    private static func cached(_ key: String, size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> SKTexture {
        let key = "\(key)-\(Int(size.width * 10))x\(Int(size.height * 10))-\(scale)"
        if let texture = cache[key] { return texture }
        if cache.count > 60 { cache.removeAll() }
        let texture = TextureMaker.make(size: size, scale: scale, draw: draw)
        cache[key] = texture
        return texture
    }

    /// How many looks of eyes there are.
    static let eyeKinds = 3

    /// A pair of eyes, for something `unit` tall (the pumpkins' height).
    static func eyesSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.3).rounded(), height: (h * 0.12).rounded()) }

    /// The color eyes glow in the dark: a sickly yellow-green.
    static var eyeColor: CGColor { Palette.slime.mixed(with: Palette.mustard, 0.55) }

    /// A pair of glowing eyes peering out of the dark: round and wide, narrowed and mean, or one
    /// bigger than the other.
    static func eyesTexture(kind: Int, size: CGSize, scale: CGFloat) -> SKTexture {
        cached("haunt-eyes-\(kind % eyeKinds)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let glow = eyeColor
            for (i, cx) in [w * 0.24, w * 0.76].enumerated() {
                var r = ht * 0.46
                if kind % eyeKinds == 2 && i == 1 { r *= 0.72 }
                let eye = CGRect(x: cx - r, y: ht / 2 - r, width: r * 2, height: r * 2)
                ctx.saveGState()
                if kind % eyeKinds == 1 {
                    // Narrowed: the top of each eye slants down toward the nose.
                    let lid = CGMutablePath()
                    let inner = i == 0 ? eye.maxX : eye.minX, outer = i == 0 ? eye.minX : eye.maxX
                    lid.move(to: CGPoint(x: outer, y: eye.minY - 1))
                    lid.addLine(to: CGPoint(x: outer, y: eye.maxY))
                    lid.addLine(to: CGPoint(x: inner, y: eye.midY + r * 0.15))
                    lid.addLine(to: CGPoint(x: inner, y: eye.minY - 1))
                    lid.closeSubpath()
                    ctx.addPath(lid)
                    ctx.clip()
                }
                ctx.setFillColor(glow)
                ctx.fillEllipse(in: eye)
                // A dark pupil, looking slightly to one side.
                ctx.setFillColor(Palette.soot)
                let p = r * 0.42
                ctx.fillEllipse(in: CGRect(x: cx - p + r * 0.18, y: ht / 2 - p - r * 0.08, width: p * 2, height: p * 2))
                ctx.restoreGState()
            }
        }
    }

    /// A wispy ghost for gathering over the Dock, for something `unit` tall.
    static func wispSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.4).rounded(), height: (h * 0.52).rounded()) }

    /// A wispy, see-through ghost seen from the front: a round head, two hollow eyes, an open "ooo"
    /// mouth, and a ragged hem that trails away.
    static func wispTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = wispSize(unit: h)
        return cached("haunt-wisp", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
            let body = CGMutablePath()
            body.move(to: p(0.06, 0.2))
            body.addLine(to: p(0.06, 0.6))
            body.addCurve(to: p(0.94, 0.6), control1: p(0.06, 1.06), control2: p(0.94, 1.06))
            body.addLine(to: p(0.94, 0.2))
            // A ragged hem: three points trailing down.
            body.addQuadCurve(to: p(0.78, 0.06), control: p(0.9, 0.04))
            body.addQuadCurve(to: p(0.62, 0.18), control: p(0.7, 0.18))
            body.addQuadCurve(to: p(0.5, 0.0), control: p(0.6, 0.0))
            body.addQuadCurve(to: p(0.36, 0.18), control: p(0.4, 0.0))
            body.addQuadCurve(to: p(0.2, 0.04), control: p(0.3, 0.18))
            body.addQuadCurve(to: p(0.06, 0.2), control: p(0.08, 0.04))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.setFillColor(Palette.ghost.withAlpha(0.82))
            ctx.fillPath()
            // A faint shade down the right side, like the rest of the art.
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            ctx.setFillColor(Palette.stone.withAlpha(0.22))
            ctx.fill(CGRect(x: w * 0.68, y: 0, width: w * 0.32, height: ht))
            ctx.restoreGState()
            // Hollow eyes and an "ooo" mouth.
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: w * 0.27, y: ht * 0.62, width: w * 0.15, height: ht * 0.15))
            ctx.fillEllipse(in: CGRect(x: w * 0.58, y: ht * 0.62, width: w * 0.15, height: ht * 0.15))
            ctx.fillEllipse(in: CGRect(x: w * 0.43, y: ht * 0.36, width: w * 0.14, height: ht * 0.17))
        }
    }

    /// A quit app's spirit: its icon at the top, with a wispy tail below it.
    static func spiritSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.5).rounded(), height: (h * 0.8).rounded()) }

    /// How much of the spirit's height its icon takes, from the top.
    static let spiritIconFraction: CGFloat = 0.62

    /// A pale, see-through ghost of an app's own icon, with hollow eyes and an "ooo" mouth, trailing a
    /// ragged wisp of a tail. `key` names the app, so each app's spirit is drawn once.
    static func spiritTexture(icon: NSImage, key: String, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = spiritSize(unit: h)
        return cached("spirit-\(key)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            let side = min(w, ht * spiritIconFraction)
            let iconRect = CGRect(x: (w - side) / 2, y: ht - side, width: side, height: side)
            // The icon, washed pale (only where the icon is; its transparent corners stay clear).
            var proposed = CGRect(origin: .zero, size: CGSize(width: side * scale, height: side * scale))
            if let image = icon.cgImage(forProposedRect: &proposed, context: nil, hints: nil) {
                ctx.draw(image, in: iconRect)
                ctx.saveGState()
                ctx.setBlendMode(.sourceAtop)
                ctx.setFillColor(Palette.ghost.withAlpha(0.6))
                ctx.fill(iconRect)
                ctx.restoreGState()
            } else {
                ctx.setFillColor(Palette.ghost.withAlpha(0.8))
                ctx.fill(iconRect.insetBy(dx: side * 0.1, dy: side * 0.1))
            }
            // The tail, behind the icon: from under it, narrowing to a curl at the bottom.
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: iconRect.minX + side * 0.18, y: iconRect.minY + side * 0.2))
            tail.addQuadCurve(to: CGPoint(x: w * 0.42, y: 0), control: CGPoint(x: w * 0.12, y: ht * 0.1))
            tail.addQuadCurve(to: CGPoint(x: w * 0.6, y: ht * 0.2), control: CGPoint(x: w * 0.62, y: ht * 0.04))
            tail.addQuadCurve(to: CGPoint(x: iconRect.maxX - side * 0.18, y: iconRect.minY + side * 0.2),
                              control: CGPoint(x: w * 0.86, y: ht * 0.22))
            tail.closeSubpath()
            ctx.saveGState()
            ctx.setBlendMode(.destinationOver)
            ctx.addPath(tail)
            ctx.setFillColor(Palette.ghost.withAlpha(0.7))
            ctx.fillPath()
            ctx.restoreGState()
            // Hollow eyes and a mouth.
            ctx.setFillColor(Palette.soot.withAlpha(0.85))
            let eye = side * 0.16
            ctx.fillEllipse(in: CGRect(x: iconRect.midX - side * 0.24, y: iconRect.minY + side * 0.52, width: eye, height: eye * 1.25))
            ctx.fillEllipse(in: CGRect(x: iconRect.midX + side * 0.08, y: iconRect.minY + side * 0.52, width: eye, height: eye * 1.25))
            ctx.fillEllipse(in: CGRect(x: iconRect.midX - side * 0.07, y: iconRect.minY + side * 0.22, width: side * 0.14, height: side * 0.17))
        }
    }
}
