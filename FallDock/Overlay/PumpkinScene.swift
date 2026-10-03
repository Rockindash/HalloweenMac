import SpriteKit

/// A pumpkin sitting on the Dock.
final class PumpkinNode: SKSpriteNode {
    let kind: PumpkinKind
    let slot: Int
    let slotHeight: CGFloat
    let variant: Int
    var isSmashing = false

    init(kind: PumpkinKind, slot: Int, slotHeight: CGFloat, variant: Int, texture: SKTexture, size: CGSize) {
        self.kind = kind
        self.slot = slot
        self.slotHeight = slotHeight
        self.variant = variant
        super.init(texture: texture, color: .clear, size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}

/// The SpriteKit scene that lives in the see-through window over the Dock.
/// Scene coordinates match the window: (0, 0) is the window's bottom-left corner.
@MainActor
final class PumpkinScene: SKScene {
    /// Called after every smash (used for the counter in the menu).
    var onSmash: (() -> Void)?

    private(set) var dockRect: CGRect = .zero
    private var pixelScale: CGFloat = 2
    private var pumpkinCount = 0
    private var pumpkinHeight: CGFloat = 40
    private var slotX: [CGFloat] = []
    private var slotScale: [CGFloat] = []
    private var pumpkins: [Int: PumpkinNode] = [:]
    private weak var hovered: PumpkinNode?

    private let vineLayer = SKNode()
    private let pumpkinLayer = SKNode()
    private let effectsLayer = SKNode()

    /// Size unit for the vine: 1 for a typical 60 pt pumpkin.
    private var unit: CGFloat { pumpkinHeight / 60 }
    private let sound = SmashSound()

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        // Points-per-meter in SpriteKit is 150, so this is a gentle ~900 pt/s² fall.
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        vineLayer.zPosition = 1
        pumpkinLayer.zPosition = 2
        effectsLayer.zPosition = 20 // above every pumpkin (each has its own small zPosition)
        addChild(vineLayer)
        addChild(pumpkinLayer)
        addChild(effectsLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: Layout

    /// Places (or moves) the pumpkins along the top edge of `dockRect` (scene coordinates).
    func configure(dockRect: CGRect, pixelScale: CGFloat, count: Int) {
        let height = (dockRect.height * 1.15).clamped(to: 40...110).rounded()
        let needsRebuild = count != pumpkinCount || height != pumpkinHeight || pixelScale != self.pixelScale
        guard needsRebuild || dockRect != self.dockRect else { return }

        self.dockRect = dockRect
        self.pixelScale = pixelScale
        self.pumpkinHeight = height
        self.pumpkinCount = count
        slotX = (0..<count).map { i in
            var rng = SeededRandom(seed: UInt64(i + 1) &* 977)
            let step = dockRect.width / CGFloat(count)
            return dockRect.minX + step * (CGFloat(i) + 0.5) + rng.float(-0.15...0.15) * step
        }
        // Mix big and small pumpkins so they look like a real harvest pile.
        slotScale = (0..<count).map { i in
            var rng = SeededRandom(seed: UInt64(i + 1) &* 7537)
            return i % 3 == 1 ? rng.float(0.66...0.8) : rng.float(0.84...1.08)
        }

        if needsRebuild {
            rebuild()
        } else {
            // The Dock just got wider or narrower: slide everything into place.
            for (slot, pumpkin) in pumpkins {
                pumpkin.run(.move(to: restingPosition(slot: slot), duration: 0.35), withKey: "move")
            }
            layoutVine()
        }
    }

    private func rebuild() {
        removeAllActions()
        pumpkinLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        pumpkins.removeAll()
        hovered = nil
        layoutVine()
        for slot in 0..<pumpkinCount {
            addPumpkin(slot: slot, grow: false)
        }
        startFallingLeaves()
    }

    private func restingPosition(slot: Int) -> CGPoint {
        // Sink 3 pt into the Dock so pumpkins look like they're sitting on it.
        // Smaller pumpkins sit a touch lower, as if they're in front.
        CGPoint(x: slotX[slot], y: dockRect.maxY - 3 - (1 - slotScale[slot]) * 5)
    }

    /// A vine running along the top of the Dock, behind the pumpkins.
    private func layoutVine() {
        vineLayer.removeAllChildren()
        let k = unit
        guard Settings.showVines, dockRect.width > 40 else { return }
        let width = (dockRect.width - 8).rounded()
        let height = (pumpkinHeight * 1.25).rounded()
        let vine = SKSpriteNode(texture: VineArt.texture(width: width, height: height, seed: pumpkinCount, unit: k, scale: pixelScale),
                                size: CGSize(width: width, height: height))
        vine.anchorPoint = .zero
        vine.position = CGPoint(x: dockRect.minX + 4, y: dockRect.maxY - 2 - VineArt.baseLevel(unit: k))
        vineLayer.addChild(vine)
    }

    // MARK: Pumpkins

    private func addPumpkin(slot: Int, grow: Bool) {
        let kind = PumpkinKind.allCases.randomElement() ?? .roundOrange
        let variant = Int.random(in: 0..<6)
        let height = (pumpkinHeight * slotScale[slot]).rounded()
        let size = PumpkinArt.size(of: kind, height: height)
        let texture = PumpkinArt.texture(kind: kind, height: height, variant: variant, scale: pixelScale)
        let pumpkin = PumpkinNode(kind: kind, slot: slot, slotHeight: height, variant: variant, texture: texture, size: size)
        pumpkin.anchorPoint = CGPoint(x: 0.5, y: 0)
        pumpkin.position = restingPosition(slot: slot)
        // Smaller pumpkins in front of bigger ones.
        pumpkin.zPosition = (1.2 - slotScale[slot]) * 10 + CGFloat(slot) * 0.01

        let shadowWidth = (size.width * 1.0).rounded()
        let shadow = SKSpriteNode(texture: PumpkinArt.shadowTexture(width: shadowWidth, scale: pixelScale),
                                  size: CGSize(width: shadowWidth, height: 8))
        shadow.position = CGPoint(x: 0, y: 2)
        shadow.zPosition = -0.5
        pumpkin.addChild(shadow)

        // A flat copy of the pumpkin in dark ink, nudged right and down: its shadow on the vine behind it.
        let cast = SKSpriteNode(texture: texture, size: size)
        cast.anchorPoint = pumpkin.anchorPoint
        cast.color = NSColor(cgColor: Palette.shadowInk) ?? .black
        cast.colorBlendFactor = 1
        cast.alpha = 0.24
        cast.position = CGPoint(x: 3 * unit, y: -1.5 * unit)
        cast.zPosition = -0.6
        pumpkin.addChild(cast)

        pumpkinLayer.addChild(pumpkin)
        pumpkins[slot] = pumpkin

        if grow {
            pumpkin.setScale(0.05)
            let pop = SKAction.scale(to: 1.12, duration: 0.35)
            pop.timingMode = .easeOut
            let settle = SKAction.scale(to: 1.0, duration: 0.18)
            settle.timingMode = .easeInEaseOut
            pumpkin.run(.sequence([pop, settle]), withKey: "grow")
        }
        startWobble(pumpkin)
    }

    private func startWobble(_ pumpkin: PumpkinNode) {
        let angle = CGFloat.random(in: 0.02...0.04)
        let duration = Double.random(in: 1.6...2.6)
        let left = SKAction.rotate(toAngle: angle, duration: duration)
        let right = SKAction.rotate(toAngle: -angle, duration: duration)
        left.timingMode = .easeInEaseOut
        right.timingMode = .easeInEaseOut
        pumpkin.run(.sequence([
            .wait(forDuration: Double.random(in: 0...1.5)),
            .repeatForever(.sequence([left, right])),
        ]), withKey: "wobble")
    }

    /// The pumpkin under `point` (scene coordinates), if any.
    func pumpkin(at point: CGPoint) -> PumpkinNode? {
        pumpkins.values
            .filter { !$0.isSmashing && $0.frame.insetBy(dx: $0.size.width * 0.08, dy: 0).contains(point) }
            .max { $0.zPosition < $1.zPosition }
    }

    func setHovered(_ pumpkin: PumpkinNode?) {
        guard pumpkin !== hovered else { return }
        if let old = hovered, !old.isSmashing {
            old.run(.scale(to: 1.0, duration: 0.12), withKey: "hover")
        }
        hovered = pumpkin
        if let pumpkin {
            let grow = SKAction.scale(to: 1.08, duration: 0.12)
            grow.timingMode = .easeOut
            pumpkin.run(grow, withKey: "hover")
        }
    }

    // MARK: Smashing

    override func mouseDown(with event: NSEvent) {
        if let pumpkin = self.pumpkin(at: event.location(in: self)) {
            smash(pumpkin)
        }
    }

    func smash(_ pumpkin: PumpkinNode) {
        guard !pumpkin.isSmashing else { return }
        pumpkin.isSmashing = true
        pumpkins[pumpkin.slot] = nil
        if hovered === pumpkin { hovered = nil }
        pumpkin.removeAllActions()

        // Squash down, then burst.
        let squash = SKAction.group([.scaleX(to: 1.2, duration: 0.07), .scaleY(to: 0.7, duration: 0.07)])
        squash.timingMode = .easeOut
        pumpkin.run(.sequence([
            squash,
            .run { [weak self, weak pumpkin] in
                guard let self, let pumpkin else { return }
                self.burst(pumpkin)
                pumpkin.removeFromParent()
            },
        ]))

        if Settings.sound { sound.play() }
        nudgeNeighbors(of: pumpkin)
        onSmash?()

        let slot = pumpkin.slot
        run(.sequence([
            .wait(forDuration: Double.random(in: 6...11)),
            .run { [weak self] in
                guard let self, self.pumpkins[slot] == nil, slot < self.pumpkinCount else { return }
                self.addPumpkin(slot: slot, grow: true)
            },
        ]), withKey: "respawn-\(slot)")
    }

    private func burst(_ pumpkin: PumpkinNode) {
        let h = pumpkin.size.height
        let center = CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + pumpkin.size.height * 0.35)

        // Splat left behind on the Dock.
        let splatWidth = (pumpkin.size.width * 1.15).rounded()
        let splat = SKSpriteNode(texture: PumpkinArt.splatTexture(kind: pumpkin.kind, width: splatWidth, scale: pixelScale),
                                 size: CGSize(width: splatWidth, height: splatWidth * 0.32))
        splat.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        splat.position = CGPoint(x: pumpkin.position.x, y: dockRect.maxY - 1)
        splat.zPosition = -1
        splat.setScale(0.3)
        effectsLayer.addChild(splat)
        splat.run(.sequence([
            .scale(to: 1.0, duration: 0.12),
            .wait(forDuration: 1.8),
            .fadeOut(withDuration: 1.0),
            .removeFromParent(),
        ]))

        // Chunks of pumpkin.
        for i in 0..<11 {
            let s = (h * CGFloat.random(in: 0.18...0.3)).rounded()
            let chunk = SKSpriteNode(texture: PumpkinArt.shardTexture(kind: pumpkin.kind, size: s, variant: i % 6, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            launch(chunk, from: center, spread: pumpkin.size.width * 0.3,
                   velocity: CGVector(dx: CGFloat.random(in: -190...190), dy: CGFloat.random(in: 160...380)),
                   radius: s * 0.3, damping: 0.2, life: 1.1)
        }

        // Seeds.
        let seedScale = h / 40
        for _ in 0..<9 {
            let seed = SKSpriteNode(texture: PumpkinArt.seedTexture(scale: pixelScale),
                                    size: CGSize(width: 3.2 * seedScale, height: 5 * seedScale))
            launch(seed, from: center, spread: pumpkin.size.width * 0.2,
                   velocity: CGVector(dx: CGFloat.random(in: -150...150), dy: CGFloat.random(in: 120...300)),
                   radius: 1.5, damping: 0.3, life: 1.0)
        }

        // A couple of leaves that flutter out and drift down slowly.
        for i in 0..<2 {
            let kind = LeafKind.fallers.randomElement() ?? .oak
            let s = (h * 0.26).rounded()
            let leaf = SKSpriteNode(texture: LeafArt.texture(kind, size: s, variant: i, scale: pixelScale),
                                    size: CGSize(width: s, height: s))
            launch(leaf, from: center, spread: 4,
                   velocity: CGVector(dx: CGFloat.random(in: -120...120), dy: CGFloat.random(in: 220...320)),
                   radius: s * 0.3, damping: 2.8, life: 2.2)
        }
    }

    private func launch(_ node: SKSpriteNode, from center: CGPoint, spread: CGFloat,
                        velocity: CGVector, radius: CGFloat, damping: CGFloat, life: TimeInterval) {
        node.position = CGPoint(x: center.x + CGFloat.random(in: -spread...spread), y: center.y + CGFloat.random(in: -spread...spread) * 0.5)
        node.zRotation = CGFloat.random(in: 0...(.pi * 2))
        let body = SKPhysicsBody(circleOfRadius: max(0.5, radius))
        body.categoryBitMask = 0
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        body.linearDamping = damping
        body.angularDamping = 0.5
        body.velocity = velocity
        body.angularVelocity = CGFloat.random(in: -9...9)
        node.physicsBody = body
        effectsLayer.addChild(node)
        node.run(.sequence([
            .wait(forDuration: life * Double.random(in: 0.8...1.2)),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
    }

    /// The other pumpkins give a startled little hop.
    private func nudgeNeighbors(of smashed: PumpkinNode) {
        for (slot, pumpkin) in pumpkins where slot != smashed.slot {
            let distance = abs(slot - smashed.slot)
            guard distance <= 2 else { continue }
            let hop = CGFloat(distance == 1 ? 5 : 2.5)
            let up = SKAction.moveBy(x: 0, y: hop, duration: 0.08)
            up.timingMode = .easeOut
            let down = SKAction.move(to: restingPosition(slot: slot), duration: 0.14)
            down.timingMode = .easeIn
            pumpkin.run(.sequence([.wait(forDuration: 0.05 * Double(distance)), up, down]), withKey: "hop")
        }
    }

    // MARK: Falling leaves

    private func startFallingLeaves() {
        removeAction(forKey: "leaves")
        run(.repeatForever(.sequence([
            .wait(forDuration: 5, withRange: 6),
            .run { [weak self] in self?.dropLeaf() },
        ])), withKey: "leaves")
    }

    private func dropLeaf() {
        guard Settings.fallingLeaves, dockRect.width > 0 else { return }
        let falling = effectsLayer.children.filter { $0.name == "falling-leaf" }.count
        guard falling < 5 else { return }

        let kind = LeafKind.fallers.randomElement() ?? .oak
        let s = (pumpkinHeight * CGFloat.random(in: 0.22...0.3)).rounded()
        let leaf = SKSpriteNode(texture: LeafArt.texture(kind, size: s, variant: Int.random(in: 0..<4), scale: pixelScale),
                                size: CGSize(width: s, height: s))
        leaf.name = "falling-leaf"
        let startX = CGFloat.random(in: (dockRect.minX + 10)...(max(dockRect.minX + 11, dockRect.maxX - 10)))
        leaf.position = CGPoint(x: startX, y: size.height - s)
        leaf.alpha = 0
        leaf.zRotation = CGFloat.random(in: 0...(.pi * 2))
        effectsLayer.addChild(leaf)

        let landY = dockRect.maxY + CGFloat.random(in: -3...6)
        let fallTime = Double(max(1, leaf.position.y - landY) / 26)
        let sway = CGFloat.random(in: 12...22)
        let swayRight = SKAction.moveBy(x: sway, y: 0, duration: 1.3)
        let swayLeft = SKAction.moveBy(x: -sway, y: 0, duration: 1.3)
        swayRight.timingMode = .easeInEaseOut
        swayLeft.timingMode = .easeInEaseOut
        leaf.run(.repeatForever(.sequence([swayRight, swayLeft])), withKey: "sway")
        leaf.run(.repeatForever(.rotate(byAngle: CGFloat.random(in: -1.2...1.2), duration: 1.3)), withKey: "spin")

        let fall = SKAction.moveTo(y: landY, duration: fallTime)
        fall.timingMode = .easeOut
        leaf.run(.sequence([
            .group([.fadeIn(withDuration: 0.8), fall]),
            .run { [weak leaf] in
                leaf?.removeAction(forKey: "sway")
                leaf?.removeAction(forKey: "spin")
                leaf?.name = nil
            },
            .wait(forDuration: 3),
            .fadeOut(withDuration: 1.2),
            .removeFromParent(),
        ]))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
