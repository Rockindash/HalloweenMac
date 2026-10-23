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

    // MARK: Ghosts

    /// A gathering ghost, for something `unit` tall.
    static func wispSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.5).rounded(), height: (h * 0.6).rounded()) }

    /// A cute ghost seen from the front, the same style as the friendly ghost that flies by: a round
    /// dome, a scalloped hem, a cool shade underneath and down its right side, dot eyes with a glint,
    /// rosy cheeks, and an "ooo" mouth with its little arms up, ready to say boo.
    static func wispTexture(unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = wispSize(unit: h)
        return cached("haunt-ghost", size: size, scale: scale) { ctx in
            drawGhost(ctx, size: size, unit: h, armsUp: true)
            let w = size.width, ht = size.height
            // "Ooo".
            ctx.setFillColor(Palette.soot)
            ctx.fillEllipse(in: CGRect(x: w * 0.42, y: ht * 0.4, width: w * 0.12, height: ht * 0.12))
        }
    }

    /// The ghost's body, arms and eyes, filling `size`. The mouth is left to each kind of ghost. Arms are
    /// raised, down at its sides, or (nil) left off for a ghost that draws its own hands.
    private static func drawGhost(_ ctx: CGContext, size: CGSize, unit h: CGFloat, armsUp: Bool?) {
        let w = size.width, ht = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * ht) }
        let body = CGMutablePath()
        body.move(to: p(0.1, 0.14))
        body.addLine(to: p(0.12, 0.58))
        body.addCurve(to: p(0.5, 0.99), control1: p(0.12, 0.88), control2: p(0.3, 0.99))
        body.addCurve(to: p(0.88, 0.58), control1: p(0.7, 0.99), control2: p(0.88, 0.88))
        body.addLine(to: p(0.92, 0.14))
        // A scalloped hem: three round lobes.
        body.addQuadCurve(to: p(0.65, 0.12), control: p(0.8, -0.04))
        body.addQuadCurve(to: p(0.37, 0.12), control: p(0.51, -0.04))
        body.addQuadCurve(to: p(0.1, 0.14), control: p(0.22, -0.04))
        body.closeSubpath()

        // Little arms, behind the body's edges, their outer ends raised when they're up.
        ctx.setFillColor(Palette.ghost)
        let arm = CGSize(width: w * 0.2, height: ht * 0.13)
        let armY = armsUp == true ? ht * 0.52 : ht * 0.3
        for (x, tilt) in armsUp == nil ? [] : [(w * 0.02, CGFloat(-0.5)), (w * 0.78, 0.5)] {
            ctx.saveGState()
            ctx.translateBy(x: x + arm.width / 2, y: armY + arm.height / 2)
            ctx.rotate(by: armsUp == true ? tilt : 0)
            ctx.fillEllipse(in: CGRect(x: -arm.width / 2, y: -arm.height / 2, width: arm.width, height: arm.height))
            ctx.restoreGState()
        }

        ctx.addPath(body)
        ctx.setFillColor(Palette.ghost)
        ctx.fillPath()
        // A cool shade under the hem and down the right side, like the rest of the art.
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        let shade = Palette.witch.mixed(with: Palette.ghost, 0.75)
        ctx.setFillColor(shade.withAlpha(0.6))
        ctx.fillEllipse(in: CGRect(x: -w * 0.2, y: -ht * 0.42, width: w * 1.4, height: ht * 0.6))
        ctx.setFillColor(shade.withAlpha(0.35))
        ctx.fillEllipse(in: CGRect(x: w * 0.7, y: ht * 0.05, width: w * 0.5, height: ht * 0.9))
        ctx.restoreGState()

        // Dot eyes with a glint, and rosy cheeks.
        ctx.setFillColor(Palette.soot)
        let eye = CGSize(width: w * 0.11, height: ht * 0.13)
        for x in [w * 0.32, w * 0.57] {
            ctx.fillEllipse(in: CGRect(x: x, y: ht * 0.58, width: eye.width, height: eye.height))
        }
        ctx.setFillColor(Palette.ghost)
        for x in [w * 0.32, w * 0.57] {
            ctx.fillEllipse(in: CGRect(x: x + eye.width * 0.5, y: ht * 0.58 + eye.height * 0.55, width: eye.width * 0.35, height: eye.width * 0.35))
        }
        ctx.setFillColor(Palette.candyPink.withAlpha(0.5))
        ctx.fillEllipse(in: CGRect(x: w * 0.2, y: ht * 0.5, width: w * 0.12, height: ht * 0.07))
        ctx.fillEllipse(in: CGRect(x: w * 0.68, y: ht * 0.5, width: w * 0.12, height: ht * 0.07))
    }

    // MARK: Spirits of quit apps

    /// A quit app's spirit, for something `unit` tall.
    static func spiritSize(unit h: CGFloat) -> CGSize { CGSize(width: (h * 0.56).rounded(), height: (h * 0.64).rounded()) }

    /// Where the app's icon sits on its spirit, as fractions of the spirit's size from its bottom left.
    static let spiritIcon = CGRect(x: 0.27, y: 0.08, width: 0.46, height: 0.36)

    /// A quit app's spirit: the cute ghost, hugging the app's own icon (so you can tell which app it
    /// was) in its little arms, with a small sad mouth. `key` names the app, so each is drawn once.
    static func spiritTexture(icon: NSImage, key: String, unit h: CGFloat, scale: CGFloat) -> SKTexture {
        let size = spiritSize(unit: h)
        return cached("spirit-\(key)", size: size, scale: scale) { ctx in
            let w = size.width, ht = size.height
            drawGhost(ctx, size: size, unit: h, armsUp: nil)
            // A small, wobbly frown above the icon.
            ctx.setStrokeColor(Palette.soot)
            ctx.setLineWidth(max(1, h * 0.018))
            ctx.addArc(center: CGPoint(x: w * 0.5, y: ht * 0.49), radius: w * 0.05, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            ctx.strokePath()

            // The icon, hugged in front of the body, in its own colors.
            let side = min(w * spiritIcon.width, ht * spiritIcon.height)
            let iconRect = CGRect(x: w * 0.5 - side / 2, y: ht * spiritIcon.minY, width: side, height: side)
            var proposed = CGRect(origin: .zero, size: CGSize(width: side * scale, height: side * scale))
            if let image = icon.cgImage(forProposedRect: &proposed, context: nil, hints: nil) {
                ctx.draw(image, in: iconRect)
            } else {
                ctx.setFillColor(Palette.stone)
                ctx.fill(iconRect.insetBy(dx: side * 0.12, dy: side * 0.12))
            }
            // Two little hands holding it, one on each side.
            ctx.setFillColor(Palette.ghost)
            let hand = side * 0.3
            ctx.fillEllipse(in: CGRect(x: iconRect.minX - hand * 0.45, y: iconRect.midY - hand * 0.6, width: hand, height: hand * 0.85))
            ctx.fillEllipse(in: CGRect(x: iconRect.maxX - hand * 0.55, y: iconRect.midY - hand * 0.6, width: hand, height: hand * 0.85))
        }
    }

    /// The middle of the icon on a spirit, as a fraction of its size (the spirit's anchor).
    static var spiritIconCenter: CGPoint { CGPoint(x: 0.5, y: spiritIcon.minY + min(spiritIcon.height, spiritIcon.width * 0.56 / 0.64) / 2) }
}
