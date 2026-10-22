import CoreGraphics
import SpriteKit

/// Haunting while you're away: decides when the ghosts gather over the Dock and when they scatter.
/// It only reads how long ago the Mac last had any input; it never sees what was typed or clicked.
struct HauntingClock {
    /// How long the Mac sits untouched before the Dock gets haunted.
    static let awayAfter: TimeInterval = 120
    /// After Try It, how long to keep hands off before the ghosts come.
    static let tryItAfter: TimeInterval = 3
    /// How long Try It waits for hands to come off before giving up.
    static let tryItWaits: TimeInterval = 60

    enum Change: Equatable { case gather, scatter }

    private(set) var isHaunting = false
    private var lastIdle: TimeInterval = 0
    /// When Try It was clicked (on the same clock as `now`), while it's still waiting.
    private var tryItAt: TimeInterval?

    /// Try It: haunt as soon as the Mac has been left alone for a moment, rather than two minutes.
    mutating func tryIt(now: TimeInterval) {
        tryItAt = now
    }

    var isWaitingToTry: Bool { tryItAt != nil }

    /// Called every so often with how many seconds ago the last input was (`idle`), and whether
    /// the Dock can be haunted right now (Halloween on the Dock, the switch on, the harvest showing).
    mutating func update(idle: TimeInterval, now: TimeInterval, allowed: Bool) -> Change? {
        defer { lastIdle = idle }
        if let at = tryItAt, now - at > Self.tryItWaits || !allowed { tryItAt = nil }
        if isHaunting {
            // Any input at all since last time brings the count back down: someone's back.
            guard !allowed || idle < lastIdle else { return nil }
            isHaunting = false
            return .scatter
        }
        guard allowed, idle >= (tryItAt == nil ? Self.awayAfter : Self.tryItAfter) else { return nil }
        isHaunting = true
        tryItAt = nil
        return .gather
    }

    /// Seconds since the last key press, click, scroll or pointer move anywhere on the Mac.
    static func secondsSinceInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}

/// Haunting while you're away: while nobody's at the Mac, ghosts drift in and gather over the Dock,
/// eyes open and blink in the dark between the jack-o'-lanterns, and the candles burn an eerie green.
/// The moment anyone touches the Mac, the eyes snap shut and the ghosts scatter. None of it can be
/// clicked, so it never gets in the way.
extension PumpkinScene {
    private static let ghostName = "haunt-ghost"
    private static let eyesName = "haunt-eyes"
    private static let leavingName = "haunt-leaving"

    /// The ghosts and eyes showing right now (not counting any on their way out).
    var hauntGhosts: [SKSpriteNode] { effectsLayer.children.compactMap { $0.name == Self.ghostName ? $0 as? SKSpriteNode : nil } }
    var hauntEyes: [SKSpriteNode] { pumpkinLayer.children.compactMap { $0.name == Self.eyesName ? $0 as? SKSpriteNode : nil } }
    var isHaunted: Bool { !hauntGhosts.isEmpty || !hauntEyes.isEmpty }

    /// How many ghosts and pairs of eyes fit along this Dock.
    var hauntCounts: (ghosts: Int, eyes: Int) {
        let span = dockRect.width / max(pumpkinHeight, 1)
        return (Int((span / 4).rounded()).clamped(to: 2...6), Int((span / 2).rounded()).clamped(to: 3...10))
    }

    /// The ghosts gather and the eyes open. Without `animated`, they're just there (after the harvest
    /// was grown afresh while haunted).
    func haunt(animated: Bool = true) {
        guard Settings.theme == .halloween, dockRect.width > 200, !isHaunted else { return }
        let motion = animated && !Self.reduceMotion
        let counts = hauntCounts
        for i in 0..<counts.eyes { openEyes(index: i, of: counts.eyes, motion: motion) }
        for i in 0..<counts.ghosts { gatherGhost(index: i, of: counts.ghosts, motion: motion) }
        tintCandles(haunted: true, duration: motion ? 1.5 : 0)
    }

    /// Someone's back: the eyes snap shut, the ghosts flee off the nearest side, and the candles warm up
    /// again. Without `animated`, they're just gone.
    func unhaunt(animated: Bool = true) {
        let motion = animated && !Self.reduceMotion
        for eyes in hauntEyes {
            eyes.name = Self.leavingName
            eyes.removeAllActions()
            guard animated else { eyes.removeFromParent(); continue }
            eyes.run(.sequence([motion ? .scaleY(to: 0.05, duration: 0.07) : .fadeOut(withDuration: 0.25), .removeFromParent()]))
        }
        for ghost in hauntGhosts {
            ghost.name = Self.leavingName
            ghost.removeAllActions()
            guard animated else { ghost.removeFromParent(); continue }
            guard motion else {
                ghost.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
                continue
            }
            let toRight = ghost.position.x > size.width / 2
            let exitX = toRight ? size.width + ghost.size.width : -ghost.size.width
            ghost.xScale = toRight ? abs(ghost.xScale) : -abs(ghost.xScale)
            let dash = SKAction.move(to: CGPoint(x: exitX, y: ghost.position.y + CGFloat.random(in: -10...30)),
                                     duration: Double(abs(exitX - ghost.position.x) / 1100) + Double.random(in: 0...0.15))
            dash.timingMode = .easeIn
            ghost.run(.sequence([.wait(forDuration: Double.random(in: 0...0.12)), dash, .removeFromParent()]))
        }
        tintCandles(haunted: false, duration: animated ? 0.4 : 0)
    }

    // MARK: Eyes

    /// A pair of eyes opening in the dark: low ones peer over the tops of the jack-o'-lanterns, the
    /// rest hang in the air above the Dock.
    private func openEyes(index i: Int, of count: Int, motion: Bool) {
        let h = pumpkinHeight
        let size = HauntingArt.eyesSize(unit: h)
        let eyes = SKSpriteNode(texture: HauntingArt.eyesTexture(kind: i, size: size, scale: pixelScale), size: size)
        eyes.name = Self.eyesName
        // Spread out along the Dock, never quite evenly.
        let lane = dockRect.width / CGFloat(count)
        let x = dockRect.minX + lane * (CGFloat(i) + CGFloat.random(in: 0.25...0.75))
        let low = i % 3 != 2
        let y = low ? dockRect.maxY + h * CGFloat.random(in: 0.75...0.95) : dockRect.maxY + h * CGFloat.random(in: 1.2...1.8)
        eyes.position = CGPoint(x: x, y: y)
        // Behind the pumpkins and extras, so the low ones peek out over them.
        eyes.zPosition = low ? -0.8 : 12
        eyes.xScale = Bool.random() ? 1 : -1
        pumpkinLayer.addChild(eyes)
        guard motion else { return }
        eyes.yScale = 0.05
        eyes.alpha = 0
        let blink = SKAction.sequence([.scaleY(to: 0.08, duration: 0.06), .scaleY(to: 1, duration: 0.09)])
        let look = SKAction.sequence([.moveBy(x: CGFloat.random(in: -3...3), y: 0, duration: 0.4), .wait(forDuration: 1),
                                      .move(to: eyes.position, duration: 0.4)])
        eyes.run(.sequence([
            // One by one, slowly.
            .wait(forDuration: Double(i) * 0.7 + Double.random(in: 0...0.5)),
            .group([.fadeIn(withDuration: 0.4), .scaleY(to: 1, duration: 0.4)]),
            .repeatForever(.sequence([.wait(forDuration: 2.5, withRange: 3), Bool.random() ? blink : .group([blink, look])])),
        ]))
    }

    // MARK: Ghosts

    /// A ghost drifts in from off the side of the screen to its spot over the Dock, then floats
    /// around it in a slow loop.
    private func gatherGhost(index i: Int, of count: Int, motion: Bool) {
        let h = pumpkinHeight
        let ghost = SKSpriteNode(texture: HauntingArt.wispTexture(unit: h, scale: pixelScale), size: HauntingArt.wispSize(unit: h))
        ghost.name = Self.ghostName
        ghost.zPosition = 9 + CGFloat(i) * 0.01
        // Gathered over the middle of the Dock, at different heights.
        let middle = dockRect.width * 0.6
        let spot = CGPoint(x: dockRect.midX - middle / 2 + middle * (CGFloat(i) + 0.5) / CGFloat(count) + CGFloat.random(in: -h * 0.3...h * 0.3),
                           y: dockRect.maxY + h * (i % 2 == 0 ? CGFloat.random(in: 0.8...1.0) : CGFloat.random(in: 1.3...1.6)))
        let diameter = (ghost.size.width * 1.6).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.ghost, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.blendMode = .add
        glow.alpha = 0.18
        glow.zPosition = -0.1
        ghost.addChild(glow)
        effectsLayer.addChild(ghost)
        guard motion else {
            ghost.position = spot
            ghost.alpha = 0.85
            return
        }
        let fromLeft = spot.x < dockRect.midX
        ghost.position = CGPoint(x: fromLeft ? -ghost.size.width : size.width + ghost.size.width, y: spot.y + h * 0.3)
        ghost.xScale = fromLeft ? 1 : -1
        ghost.alpha = 0
        let drift = SKAction.move(to: spot, duration: Double(abs(spot.x - ghost.position.x) / 140))
        drift.timingMode = .easeOut
        // Round and round its spot, bobbing, turning to face the way it goes.
        let r = h * CGFloat.random(in: 0.2...0.35)
        // (An ellipse path starts at its right edge, so put that edge on the spot: no jump at the start.)
        let loop = SKAction.follow(CGPath(ellipseIn: CGRect(x: -r * 2, y: -r * 0.5, width: r * 2, height: r), transform: nil),
                                   asOffset: true, orientToPath: false, duration: Double.random(in: 4...6))
        let turn = SKAction.sequence([.wait(forDuration: 1.5, withRange: 2), .scaleX(to: -1, duration: 0.25),
                                      .wait(forDuration: 1.5, withRange: 2), .scaleX(to: 1, duration: 0.25)])
        ghost.run(.sequence([
            .wait(forDuration: 1.5 + Double(i) * 0.9),
            .group([drift, .fadeAlpha(to: 0.85, duration: 0.8)]),
            .group([.repeatForever(loop), .repeatForever(turn)]),
        ]))
    }

    // MARK: Candles

    /// The jack-o'-lanterns' candles burn green while the Dock is haunted.
    private func tintCandles(haunted: Bool, duration: TimeInterval) {
        for case let pumpkin as PumpkinNode in pumpkinLayer.children where pumpkin.isLantern {
            guard let glow = pumpkin.childNode(withName: "candle") as? SKSpriteNode else { continue }
            glow.removeAction(forKey: "haunt")
            let tint = haunted ? SKAction.colorize(with: NSColor(cgColor: Palette.slime) ?? .green, colorBlendFactor: 1, duration: duration)
                               : SKAction.colorize(withColorBlendFactor: 0, duration: duration)
            if duration == 0 {
                glow.color = NSColor(cgColor: Palette.slime) ?? .green
                glow.colorBlendFactor = haunted ? 1 : 0
            } else {
                glow.run(tint, withKey: "haunt")
            }
        }
    }

    /// Whether a jack-o'-lantern's candle is burning green.
    func isCandleHaunted(_ pumpkin: PumpkinNode) -> Bool {
        ((pumpkin.childNode(withName: "candle") as? SKSpriteNode)?.colorBlendFactor ?? 0) > 0.5
    }
}
