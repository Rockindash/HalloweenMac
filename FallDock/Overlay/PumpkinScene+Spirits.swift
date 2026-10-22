import AppKit
import SpriteKit

/// Spirits of quit apps: remembers where each app's icon sits in the Dock, so that when an app quits
/// (and its icon may already be gone) its spirit can rise from the right spot, and which apps' spirits
/// left recently, so reopening one brings its spirit back.
struct SpiritLedger {
    /// How long a spirit that left waits to come back when its app is opened again.
    static let remembers: TimeInterval = 600

    /// Each app's Dock icon, by `key(for:)`: the middle of its icon across the screen.
    private(set) var iconX: [String: CGFloat] = [:]
    /// The apps whose spirits have left, and when.
    private var departed: [String: TimeInterval] = [:]

    /// The same app always gets the same key, however its location is spelled.
    static func key(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    /// Where the Dock's app icons are now. An app whose icon has gone (it quit) keeps its last spot.
    mutating func noteIcons(_ frames: [String: CGRect]) {
        for (key, frame) in frames { iconX[key] = frame.midX }
    }

    /// Where the Dock's app icons probably are (the middle of each across the screen), by key.
    mutating func noteIconX(_ xs: [String: CGFloat]) {
        for (key, x) in xs { iconX[key] = x }
    }

    /// Where each open app's icon probably is when the Dock can't be asked (without Accessibility), by
    /// bundle identifier: Finder first, then the apps kept in the Dock in their order, then (after a
    /// divider) the other open apps in the order they opened. The same tile sizes as
    /// `DockLocator.estimatedDockWidth`.
    static func estimatedIconX(kept: [String], open: [String], dockFrame: CGRect, tileSize: CGFloat) -> [String: CGFloat] {
        let icon = tileSize > 0 ? tileSize : dockFrame.height * 0.78
        let pitch = icon + max(4, icon * 0.1)
        let finder = "com.apple.finder"
        var section1 = [finder]
        for id in kept where !section1.contains(id) { section1.append(id) }
        var section2: [String] = []
        for id in open where !section1.contains(id) && !section2.contains(id) { section2.append(id) }
        var xs: [String: CGFloat] = [:]
        for (i, id) in section1.enumerated() {
            xs[id] = dockFrame.minX + 10 + (CGFloat(i) + 0.5) * pitch
        }
        for (i, id) in section2.enumerated() {
            xs[id] = dockFrame.minX + 10 + 14 + (CGFloat(section1.count + i) + 0.5) * pitch
        }
        return xs
    }

    /// The app at `key` quit: its spirit leaves now. Returns where its icon was, if known.
    mutating func quit(_ key: String, now: TimeInterval) -> CGFloat? {
        departed[key] = now
        departed = departed.filter { now - $0.value <= Self.remembers }
        return iconX[key]
    }

    /// The app at `key` opened: whether its spirit left recently and comes back now.
    mutating func launched(_ key: String, now: TimeInterval) -> Bool {
        guard let left = departed.removeValue(forKey: key) else { return false }
        return now - left <= Self.remembers
    }
}

/// Spirits of quit apps (Halloween): quit an app and a little ghost hugging its icon floats up out
/// of its spot in the Dock and drifts away; open it again soon after and the spirit swoops back down into
/// its icon. Nothing here can be clicked.
extension PumpkinScene {
    static let spiritName = "spirit"

    /// The spirits on screen right now, leaving or coming back.
    var spirits: [SKSpriteNode] { effectsLayer.children.compactMap { $0.name == Self.spiritName ? $0 as? SKSpriteNode : nil } }

    /// Where on the Dock a spirit comes from or goes to: its icon (scene x), or, when that's not known
    /// (no Accessibility access), somewhere among the open apps near the Dock's right end.
    private func spiritX(_ x: CGFloat?) -> CGFloat {
        // (The Dock may already have shrunk to close the gap the app's icon left, so it can be just past the end.)
        if let x { return x.clamped(to: 0...max(size.width, 1)) }
        return dockRect.maxX - dockRect.width * CGFloat.random(in: 0.12...0.3)
    }

    private func makeSpirit(icon: NSImage, key: String) -> SKSpriteNode {
        let h = pumpkinHeight
        let spirit = SKSpriteNode(texture: HauntingArt.spiritTexture(icon: icon, key: key, unit: h, scale: pixelScale),
                                  size: HauntingArt.spiritSize(unit: h))
        spirit.name = Self.spiritName
        // Anchored on the icon it carries, so the icon starts and ends right on the app's own.
        spirit.anchorPoint = HauntingArt.spiritIconCenter
        spirit.zPosition = 15
        let diameter = (spirit.size.width * 1.5).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.ghost, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.blendMode = .add
        glow.alpha = 0.2
        glow.zPosition = -0.1
        spirit.addChild(glow)
        return spirit
    }

    /// An app quit: its spirit rises out of its icon (at scene x `x`) and drifts up off the top.
    func releaseSpirit(icon: NSImage, key: String, atSceneX x: CGFloat?) {
        guard Settings.theme == .halloween, dockRect.width > 200 else { return }
        let spirit = makeSpirit(icon: icon, key: key)
        let start = CGPoint(x: spiritX(x), y: dockRect.midY)
        spirit.position = start
        spirit.alpha = 0
        spirit.setScale(0.6)
        effectsLayer.addChild(spirit)
        guard !Self.reduceMotion else {
            spirit.run(.sequence([.group([.fadeAlpha(to: 0.85, duration: 0.4), .scale(to: 1, duration: 0.4),
                                          .moveBy(x: 0, y: pumpkinHeight * 0.8, duration: 1.2)]),
                                  .fadeOut(withDuration: 0.8), .removeFromParent()]))
            return
        }
        // Up and away, swaying side to side like a wisp of smoke.
        let top = size.height + spirit.size.height
        let sway = pumpkinHeight * 0.35 * (Bool.random() ? 1 : -1)
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: CGPoint(x: start.x + sway * 0.5, y: (start.y + top) / 2),
                      control1: CGPoint(x: start.x + sway, y: start.y + (top - start.y) * 0.2),
                      control2: CGPoint(x: start.x - sway, y: start.y + (top - start.y) * 0.35))
        path.addCurve(to: CGPoint(x: start.x + sway * 1.5, y: top),
                      control1: CGPoint(x: start.x + sway * 1.6, y: start.y + (top - start.y) * 0.65),
                      control2: CGPoint(x: start.x - sway * 0.4, y: start.y + (top - start.y) * 0.85))
        let wobble = SKAction.sequence([.rotate(toAngle: 0.12, duration: 0.6), .rotate(toAngle: -0.12, duration: 0.6)])
        wobble.timingMode = .easeInEaseOut
        spirit.run(.repeatForever(wobble))
        spirit.run(.sequence([
            .group([.fadeAlpha(to: 0.85, duration: 0.35), .scale(to: 1, duration: 0.45)]),
            .group([.follow(path, asOffset: false, orientToPath: false, duration: 3.6),
                    .sequence([.wait(forDuration: 2.6), .fadeOut(withDuration: 1)])]),
            .removeFromParent(),
        ]))
    }

    /// An app whose spirit left came back: the spirit swoops down from above into its icon (at scene x
    /// `x`) and vanishes into it with a soft flash.
    func returnSpirit(icon: NSImage, key: String, toSceneX x: CGFloat?) {
        guard Settings.theme == .halloween, dockRect.width > 200 else { return }
        let spirit = makeSpirit(icon: icon, key: key)
        let end = CGPoint(x: spiritX(x), y: dockRect.midY)
        let fromLeft = Bool.random()
        let start = CGPoint(x: end.x + pumpkinHeight * (fromLeft ? -1.6 : 1.6), y: size.height - spirit.size.height * 0.3)
        spirit.position = start
        spirit.alpha = 0
        effectsLayer.addChild(spirit)
        let flash = SKAction.run { [weak self] in self?.spiritFlash(at: end) }
        guard !Self.reduceMotion else {
            spirit.position = CGPoint(x: end.x, y: end.y + pumpkinHeight * 0.8)
            spirit.run(.sequence([.fadeAlpha(to: 0.85, duration: 0.4), .group([.moveTo(y: end.y, duration: 0.8), .fadeOut(withDuration: 0.8)]),
                                  flash, .removeFromParent()]))
            return
        }
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end, control1: CGPoint(x: start.x, y: end.y + (start.y - end.y) * 0.3),
                      control2: CGPoint(x: end.x + (start.x - end.x) * 0.6, y: end.y + pumpkinHeight * 0.4))
        let swoop = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.1)
        swoop.timingMode = .easeIn
        spirit.run(.sequence([
            .group([swoop, .fadeAlpha(to: 0.9, duration: 0.3), .sequence([.wait(forDuration: 0.7), .scale(to: 0.45, duration: 0.4)])]),
            flash,
            .group([.fadeOut(withDuration: 0.15), .scale(to: 0.2, duration: 0.15)]),
            .removeFromParent(),
        ]))
    }

    /// A soft glow where a spirit went back into its icon.
    private func spiritFlash(at point: CGPoint) {
        let diameter = (pumpkinHeight * 0.9).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.ghost, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.blendMode = .add
        glow.position = point
        glow.zPosition = 14
        glow.alpha = 0.6
        glow.setScale(0.5)
        effectsLayer.addChild(glow)
        glow.run(.sequence([.group([.scale(to: 1.3, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }
}
