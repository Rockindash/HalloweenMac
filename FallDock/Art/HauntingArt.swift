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
}
