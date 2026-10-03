import AppKit
import SpriteKit

/// The Dock's magnification settings, and the curve icons follow as the pointer moves along the
/// Dock. Pumpkins, decorations and the vine use it to grow, rise and spread with the icons.
struct DockMagnifier: Equatable {
    var enabled = false
    /// Icon size at rest.
    var tile: CGFloat = 48
    /// Icon size right under the pointer.
    var large: CGFloat = 64

    static func current() -> DockMagnifier {
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let tile = CGFloat(dock?.double(forKey: "tilesize") ?? 0)
        let large = CGFloat(dock?.double(forKey: "largesize") ?? 0)
        return DockMagnifier(enabled: dock?.bool(forKey: "magnification") == true,
                             tile: tile > 0 ? tile : 48,
                             large: large > 0 ? large : 128)
    }

    var maxScale: CGFloat { enabled ? max(1, large / tile) : 1 }

    /// How far from the pointer icons still grow.
    var reach: CGFloat { tile * 3 }

    /// 1 right under the pointer, easing to 0 at `reach`.
    private func falloff(_ d: CGFloat) -> CGFloat {
        let a = abs(d)
        guard a < reach else { return 0 }
        return (cos(.pi * a / reach) + 1) / 2
    }

    /// Size multiplier `d` points from the pointer. `strength` (0...1) fades magnification in and out.
    func scale(at d: CGFloat, strength: CGFloat) -> CGFloat {
        1 + (maxScale - 1) * falloff(d) * strength
    }

    /// How far the top of the icons rises `d` points from the pointer.
    func lift(at d: CGFloat, strength: CGFloat) -> CGFloat {
        tile * (scale(at: d, strength: strength) - 1)
    }

    /// How far things `d` points from the pointer are pushed sideways as the icons spread apart:
    /// the extra width of every magnified icon between them and the pointer.
    func shift(at d: CGFloat, strength: CGFloat) -> CGFloat {
        let a = min(abs(d), reach)
        let extra = a / 2 + reach / (2 * .pi) * sin(.pi * a / reach)
        return (d < 0 ? -1 : 1) * (maxScale - 1) * extra * strength
    }
}

/// Something sitting on the Dock: a pumpkin, a decoration or the squirrel.
/// `PumpkinScene.update` places it every frame from where it rests plus the Dock's magnification,
/// so animations change the properties below rather than the node's position or scale.
class DockSprite: SKSpriteNode {
    /// Where the middle of its bottom edge rests, in scene coordinates, with no magnification.
    var restX: CGFloat = 0
    var restY: CGFloat = 0
    /// How high it sits on something else (a pumpkin on a hay bale). Grows with magnification.
    var perch: CGFloat = 0
    /// A hop or bounce, added on top.
    var bounce: CGFloat = 0
    /// Growing in when it appears, and growing a little while the pointer is over it.
    var popScale: CGFloat = 1
    var hoverScale: CGFloat = 1
    /// -1 to face left (only the squirrel turns around).
    var facing: CGFloat = 1
    /// Set while something else (a smash) moves and scales the node directly.
    var isDetached = false
    /// Whether clicking it does something, so the pointer turns into a hand over it.
    var isInteractive: Bool { true }

    /// An action that animates one of the properties above, from its value when the action starts.
    static func animate(_ property: ReferenceWritableKeyPath<DockSprite, CGFloat>, to target: CGFloat,
                        duration: TimeInterval, curve: SKActionTimingMode = .easeInEaseOut) -> SKAction {
        var start: CGFloat?
        let tween = SKAction.customAction(withDuration: duration) { node, elapsed in
            guard let sprite = node as? DockSprite else { return }
            let from = start ?? sprite[keyPath: property]
            start = from
            let t = duration > 0 ? min(1, CGFloat(elapsed) / CGFloat(duration)) : 1
            sprite[keyPath: property] = from + (target - from) * ease(t, curve)
        }
        return .sequence([tween, .customAction(withDuration: 0) { node, _ in
            (node as? DockSprite)?[keyPath: property] = target
        }])
    }

    /// A quick hop: up by `height`, then back down.
    static func hop(height: CGFloat, duration: TimeInterval) -> SKAction {
        .sequence([
            animate(\.bounce, to: height, duration: duration * 0.45, curve: .easeOut),
            animate(\.bounce, to: 0, duration: duration * 0.55, curve: .easeIn),
        ])
    }

    private static func ease(_ t: CGFloat, _ curve: SKActionTimingMode) -> CGFloat {
        switch curve {
        case .linear: return t
        case .easeIn: return t * t
        case .easeOut: return 1 - (1 - t) * (1 - t)
        default: return t * t * (3 - 2 * t)
        }
    }
}

/// A decoration in a gap between pumpkins.
final class DecorNode: DockSprite {
    let kind: DecorKind
    /// Which gap it sits in, so it can be placed again when the Dock changes width.
    let gap: Int
    /// The leaf pile hides for a while after it's scattered.
    var isScattered = false

    init(kind: DecorKind, gap: Int, texture: SKTexture, size: CGSize) {
        self.kind = kind
        self.gap = gap
        super.init(texture: texture, color: .clear, size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isInteractive: Bool { kind != .hayBale && !isScattered }
}

/// The squirrel that drops by now and then.
final class SquirrelNode: DockSprite {
    var isFleeing = false
}
