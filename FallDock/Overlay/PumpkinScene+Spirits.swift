import AppKit
import CoreImage
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

    /// The key for an app's icon found by its name in the Dock.
    static func titleKey(_ title: String) -> String { "title:" + title.lowercased() }

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
    var spirits: [SKNode] { effectsLayer.children.filter { $0.name == Self.spiritName } }

    /// Where on the Dock a spirit comes from or goes to: its icon (scene x), or, when that's not known,
    /// somewhere among the open apps near the Dock's right end.
    private func spiritX(_ x: CGFloat?) -> CGFloat {
        // (The Dock may already have shrunk to close the gap the app's icon left, so it can be just past the end.)
        if let x { return x.clamped(to: 0...max(size.width, 1)) }
        return dockRect.maxX - dockRect.width * CGFloat.random(in: 0.12...0.3)
    }

    /// A spirit: the ghost hugging the app's icon, inside a node that can blur it, so it can fade away
    /// (or into being) like a breath of mist.
    private func makeSpirit(icon: NSImage, key: String) -> SKEffectNode {
        let h = pumpkinHeight
        let ghost = SKSpriteNode(texture: HauntingArt.spiritTexture(icon: icon, key: key, unit: h, scale: pixelScale),
                                 size: HauntingArt.spiritSize(unit: h))
        ghost.name = "ghost"
        // Anchored on the icon it carries, so the icon starts and ends right on the app's own.
        ghost.anchorPoint = HauntingArt.spiritIconCenter
        let diameter = (ghost.size.width * 1.5).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.ghost, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.blendMode = .add
        glow.alpha = 0.2
        glow.zPosition = -0.1
        ghost.addChild(glow)
        let spirit = SKEffectNode()
        spirit.name = Self.spiritName
        spirit.zPosition = 15
        spirit.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 0])
        spirit.shouldCenterFilter = true
        spirit.shouldEnableEffects = false
        spirit.addChild(ghost)
        return spirit
    }

    /// Blurs a spirit from `from` to `to` points of blur over `duration`.
    private static func blur(from: CGFloat, to: CGFloat, duration: TimeInterval) -> SKAction {
        .customAction(withDuration: duration) { node, elapsed in
            guard let effect = node as? SKEffectNode else { return }
            let t = duration > 0 ? min(1, elapsed / CGFloat(duration)) : 1
            let radius = from + (to - from) * t
            effect.shouldEnableEffects = radius > 0.05
            effect.filter?.setValue(radius, forKey: kCIInputRadiusKey)
        }
    }

    /// An app quit: its spirit pops up out of its icon (at scene x `x`), lingers a moment above it,
    /// then blurs away into nothing.
    func releaseSpirit(icon: NSImage, key: String, atSceneX x: CGFloat?) {
        guard Settings.theme == .halloween, dockRect.width > 200 else { return }
        let spirit = makeSpirit(icon: icon, key: key)
        let start = CGPoint(x: spiritX(x), y: dockRect.midY)
        spirit.position = start
        spirit.alpha = 0
        spirit.setScale(0.6)
        effectsLayer.addChild(spirit)
        let h = pumpkinHeight
        guard !Self.reduceMotion else {
            spirit.run(.sequence([.group([.fadeAlpha(to: 0.9, duration: 0.4), .scale(to: 1, duration: 0.4),
                                          .moveBy(x: 0, y: h * 0.9, duration: 0.6)]),
                                  .wait(forDuration: 0.8),
                                  .group([.fadeOut(withDuration: 1), Self.blur(from: 0, to: 10, duration: 1)]),
                                  .removeFromParent()]))
            return
        }
        // A gentle sway while it's out.
        if let ghost = spirit.childNode(withName: "ghost") {
            let sway = SKAction.sequence([.rotate(toAngle: 0.1, duration: 0.5), .rotate(toAngle: -0.1, duration: 0.5)])
            sway.timingMode = .easeInEaseOut
            ghost.run(.repeatForever(sway))
        }
        let rise = SKAction.moveBy(x: 0, y: h * 0.9, duration: 0.6)
        rise.timingMode = .easeOut
        let bob = SKAction.sequence([.moveBy(x: 0, y: h * 0.06, duration: 0.45), .moveBy(x: 0, y: -h * 0.06, duration: 0.45)])
        bob.timingMode = .easeInEaseOut
        let drift = SKAction.moveBy(x: h * 0.08 * (Bool.random() ? 1 : -1), y: h * 0.25, duration: 1.3)
        drift.timingMode = .easeIn
        spirit.run(.sequence([
            .group([rise, .fadeAlpha(to: 0.92, duration: 0.3), .scale(to: 1, duration: 0.45)]),
            bob,
            // Blurs out as it swells a little and fades, like breath on a cold night.
            .group([Self.blur(from: 0, to: 14, duration: 1.3), .fadeOut(withDuration: 1.3), .scale(to: 1.25, duration: 1.3), drift]),
            .removeFromParent(),
        ]))
    }

    /// An app whose spirit left came back: the spirit blurs into being just above its icon (at scene x
    /// `x`), then dives down into the icon and vanishes into it with a soft flash.
    func returnSpirit(icon: NSImage, key: String, toSceneX x: CGFloat?) {
        guard Settings.theme == .halloween, dockRect.width > 200 else { return }
        let spirit = makeSpirit(icon: icon, key: key)
        let end = CGPoint(x: spiritX(x), y: dockRect.midY)
        let h = pumpkinHeight
        spirit.position = CGPoint(x: end.x, y: end.y + h * 1.15)
        spirit.alpha = 0
        spirit.setScale(1.2)
        spirit.shouldEnableEffects = true
        spirit.filter?.setValue(14, forKey: kCIInputRadiusKey)
        effectsLayer.addChild(spirit)
        let flash = SKAction.run { [weak self] in self?.spiritFlash(at: end) }
        let dive = SKAction.move(to: end, duration: Self.reduceMotion ? 0.8 : 0.45)
        dive.timingMode = .easeIn
        spirit.run(.sequence([
            // Out of the mist.
            .group([Self.blur(from: 14, to: 0, duration: 0.9), .fadeAlpha(to: 0.92, duration: 0.9), .scale(to: 1, duration: 0.9)]),
            .wait(forDuration: 0.3),
            .group([dive, .scale(to: 0.45, duration: 0.45)]),
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
