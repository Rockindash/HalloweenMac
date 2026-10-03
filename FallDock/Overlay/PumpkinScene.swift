import SpriteKit

/// A pumpkin sitting on the Dock.
final class PumpkinNode: DockSprite {
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

    override var isInteractive: Bool { !isSmashing }
}

/// The SpriteKit scene that lives in the see-through window over the Dock.
/// Scene coordinates match the window: (0, 0) is the window's bottom-left corner.
@MainActor
final class PumpkinScene: SKScene {
    /// Called after every smash (used for the counter in the menu).
    var onSmash: (() -> Void)?

    private(set) var dockRect: CGRect = .zero
    var pixelScale: CGFloat = 2
    private(set) var pumpkinCount = 0
    var pumpkinHeight: CGFloat = 40
    var slotX: [CGFloat] = []
    private var slotScale: [CGFloat] = []
    /// How high each slot's pumpkin sits (on a hay bale, or 0 on the Dock).
    var slotPerch: [CGFloat] = []
    var gapX: [CGFloat] = []
    private var pumpkins: [Int: PumpkinNode] = [:]
    private weak var hovered: DockSprite?

    private let vineLayer = SKNode()
    let lightsLayer = SKNode()
    let pumpkinLayer = SKNode()
    let effectsLayer = SKNode()
    private var vine: SKSpriteNode?
    private var vineOrigin: CGPoint = .zero

    // Following the Dock's magnification.
    private var magnifier = DockMagnifier()
    private var pointer: CGPoint?
    private var pointerX: CGFloat = 0
    private var lastPointer: (point: CGPoint, time: TimeInterval)?
    private var magnifyStrength: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private var vineWarpStrength: CGFloat = -1
    private var vineWarpX: CGFloat = 0

    /// Size unit for the vine: 1 for a typical 60 pt pumpkin.
    var unit: CGFloat { pumpkinHeight / 60 }
    private let sound = SmashSound()

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        // Points-per-meter in SpriteKit is 150, so this is a gentle ~900 pt/s² fall.
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        vineLayer.zPosition = 1
        lightsLayer.zPosition = 1.5
        pumpkinLayer.zPosition = 2
        effectsLayer.zPosition = 20 // above every pumpkin (each has its own small zPosition)
        addChild(vineLayer)
        addChild(lightsLayer)
        addChild(pumpkinLayer)
        addChild(effectsLayer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: Layout

    /// Places (or moves) the pumpkins along the top edge of `dockRect` (scene coordinates).
    func configure(dockRect: CGRect, pixelScale: CGFloat, count: Int, magnifier: DockMagnifier) {
        self.magnifier = magnifier
        let height = (dockRect.height * 1.15).clamped(to: 40...110).rounded()
        let needsRebuild = count != pumpkinCount || height != pumpkinHeight || pixelScale != self.pixelScale
        guard needsRebuild || dockRect != self.dockRect else { return }

        self.dockRect = dockRect
        self.pixelScale = pixelScale
        self.pumpkinHeight = height
        self.pumpkinCount = count
        layoutSlots()

        if needsRebuild {
            rebuild()
        } else {
            // The Dock just got wider or narrower: slide everything into place.
            for (slot, pumpkin) in pumpkins {
                pumpkin.run(.group([
                    DockSprite.animate(\.restX, to: slotX[slot], duration: 0.35),
                    DockSprite.animate(\.restY, to: restingY(slot: slot), duration: 0.35),
                ]), withKey: "move")
            }
            moveDecorations()
            layoutVine()
        }
    }

    /// Where each pumpkin and each decoration between them goes. Pumpkins and gaps share the Dock's
    /// width by weight, so everything spreads evenly however many pumpkins there are.
    private func layoutSlots() {
        let count = pumpkinCount
        guard count > 0 else {
            slotX = []; slotScale = []; slotPerch = []; gapX = []
            return
        }
        let extras = Settings.cozyExtras
        // Hay bales under a quarter and three quarters of the way along.
        let baleSlots: Set<Int> = extras && count >= 5 ? [count / 4, count - 1 - count / 4] : []
        // Mix big and small pumpkins so they look like a real harvest pile.
        slotScale = (0..<count).map { i in
            var rng = SeededRandom(seed: UInt64(i + 1) &* 7537)
            if baleSlots.contains(i) { return rng.float(0.72...0.82) }
            return i % 3 == 1 ? rng.float(0.66...0.8) : rng.float(0.84...1.08)
        }
        slotPerch = (0..<count).map { baleSlots.contains($0) ? CozyArt.size(of: .hayBale, unit: pumpkinHeight).height * 0.86 : 0 }

        let gapWeight: CGFloat = extras ? 0.62 : 0
        let margin: CGFloat = 0.3
        let weights = (0..<count).map { baleSlots.contains($0) ? 1.25 : CGFloat(1) }
        let total = weights.reduce(0, +) + gapWeight * CGFloat(count - 1) + margin * 2
        let unitWidth = dockRect.width / total
        var cursor = margin
        slotX = []
        gapX = []
        for i in 0..<count {
            var rng = SeededRandom(seed: UInt64(i + 1) &* 977)
            slotX.append(dockRect.minX + (cursor + weights[i] / 2 + rng.float(-0.08...0.08)) * unitWidth)
            cursor += weights[i]
            if i < count - 1 {
                gapX.append(dockRect.minX + (cursor + gapWeight / 2) * unitWidth)
                cursor += gapWeight
            }
        }
    }

    private func rebuild() {
        removeAllActions()
        pumpkinLayer.removeAllChildren()
        lightsLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        pumpkins.removeAll()
        hovered = nil
        layoutVine()
        for slot in 0..<pumpkinCount {
            addPumpkin(slot: slot, grow: false)
        }
        if Settings.cozyExtras {
            addDecorations()
            addLights()
            scheduleSquirrel(first: true)
        }
        startFallingLeaves()
    }

    private func restingY(slot: Int) -> CGFloat {
        // Sink 3 pt into the Dock so pumpkins look like they're sitting on it.
        // Smaller pumpkins sit a touch lower, as if they're in front.
        dockRect.maxY - 3 - (slotPerch[slot] > 0 ? 0 : (1 - slotScale[slot]) * 5)
    }

    /// A vine running along the top of the Dock, behind the pumpkins.
    private func layoutVine() {
        vineLayer.removeAllChildren()
        vine = nil
        vineWarpStrength = -1
        let k = unit
        vineOrigin = CGPoint(x: dockRect.minX + 4, y: dockRect.maxY - 2 - VineArt.baseLevel(unit: k))
        guard Settings.showVines, dockRect.width > 40 else { return }
        let width = (dockRect.width - 8).rounded()
        let height = (pumpkinHeight * 1.25).rounded()
        let vine = SKSpriteNode(texture: VineArt.texture(width: width, height: height, seed: pumpkinCount, unit: k, scale: pixelScale),
                                size: CGSize(width: width, height: height))
        vine.anchorPoint = .zero
        vine.position = vineOrigin
        vineLayer.addChild(vine)
        self.vine = vine
    }

    /// Height of the middle of the vine at scene x.
    func vineY(atSceneX x: CGFloat) -> CGFloat {
        vineOrigin.y + VineArt.centerY(x: x - vineOrigin.x, unit: unit)
    }

    // MARK: Following the Dock's magnification

    /// The pointer moved (scene coordinates). While it's over the Dock, things near it grow with the icons.
    func pointerMoved(to point: CGPoint) {
        pointer = point
        brushPast(point)
    }

    /// Whether the pointer is over the Dock's icons, where the Dock (not us) gets the clicks.
    private var isPointerOnDock: Bool {
        guard let pointer, magnifier.enabled, dockRect.width > 0 else { return false }
        let top = dockRect.maxY + magnifier.lift(at: 0, strength: magnifyStrength)
        return pointer.x >= dockRect.minX && pointer.x <= dockRect.maxX && pointer.y >= dockRect.minY && pointer.y <= top
    }

    override func update(_ currentTime: TimeInterval) {
        // The clock can jump (after the view was paused), so keep each step small and positive.
        let dt = lastUpdate == 0 ? 1.0 / 30 : (currentTime - lastUpdate).clamped(to: 0...0.1)
        lastUpdate = currentTime

        var onDock = isPointerOnDock
        if onDock, let pointer { pointerX = pointer.x }
        #if DEBUG
        // `open "Fall Dock.app" --args -fakeDockPointer 0.4` magnifies as if the pointer sat 40% along the Dock.
        let fake = UserDefaults.standard.double(forKey: "fakeDockPointer")
        if fake > 0 { onDock = magnifier.enabled; pointerX = dockRect.minX + dockRect.width * fake }
        #endif
        // The Dock eases in and out of magnification, but tracks the pointer instantly.
        magnifyStrength += ((onDock ? 1 : 0) - magnifyStrength) * (1 - exp(-CGFloat(dt) * 14))
        if magnifyStrength < 0.001 { magnifyStrength = 0 }

        for layer in [lightsLayer, pumpkinLayer] {
            for case let sprite as DockSprite in layer.children where !sprite.isDetached {
                place(sprite)
            }
        }
        warpVine()
    }

    private func place(_ sprite: DockSprite) {
        let d = sprite.restX - pointerX
        let s = magnifier.scale(at: d, strength: magnifyStrength)
        sprite.position = CGPoint(x: sprite.restX + magnifier.shift(at: d, strength: magnifyStrength),
                                  y: sprite.restY + magnifier.lift(at: d, strength: magnifyStrength) + sprite.perch * s + sprite.bounce)
        let size = sprite.popScale * sprite.hoverScale * s
        sprite.xScale = size * sprite.facing
        sprite.yScale = size
    }

    /// Bends the vine up and apart over the magnified icons, so it stays on top of them.
    private func warpVine() {
        guard let vine else { return }
        let strength = magnifyStrength
        guard abs(strength - vineWarpStrength) > 0.002 || (strength > 0 && abs(pointerX - vineWarpX) > 0.5) else { return }
        vineWarpStrength = strength
        vineWarpX = pointerX
        if strength == 0 {
            vine.warpGeometry = nil
            return
        }
        let columns = 160
        let w = vine.size.width, h = vine.size.height
        var source: [SIMD2<Float>] = []
        var destination: [SIMD2<Float>] = []
        for row in 0...1 {
            for column in 0...columns {
                let u = CGFloat(column) / CGFloat(columns)
                let d = vine.position.x + u * w - pointerX
                let x = u + magnifier.shift(at: d, strength: strength) / w
                let y = CGFloat(row) + magnifier.lift(at: d, strength: strength) / h
                source.append(SIMD2(Float(u), Float(row)))
                destination.append(SIMD2(Float(x), Float(y)))
            }
        }
        vine.warpGeometry = SKWarpGeometryGrid(columns: columns, rows: 1, sourcePositions: source, destinationPositions: destination)
    }

    // MARK: Pumpkins

    private func addPumpkin(slot: Int, grow: Bool) {
        // Tall butternuts would tower over everything on top of a hay bale.
        let kinds = slotPerch[slot] > 0 ? PumpkinKind.allCases.filter { $0.isRound && $0 != .littleGreen } : PumpkinKind.allCases
        let kind = kinds.randomElement() ?? .roundOrange
        let variant = Int.random(in: 0..<6)
        let height = (pumpkinHeight * slotScale[slot]).rounded()
        let size = PumpkinArt.size(of: kind, height: height)
        let texture = PumpkinArt.texture(kind: kind, height: height, variant: variant, scale: pixelScale)
        let pumpkin = PumpkinNode(kind: kind, slot: slot, slotHeight: height, variant: variant, texture: texture, size: size)
        pumpkin.anchorPoint = CGPoint(x: 0.5, y: 0)
        pumpkin.restX = slotX[slot]
        pumpkin.restY = restingY(slot: slot)
        pumpkin.perch = slotPerch[slot]
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
        place(pumpkin)

        if grow {
            pumpkin.popScale = 0.05
            pumpkin.run(.sequence([
                DockSprite.animate(\.popScale, to: 1.12, duration: 0.35, curve: .easeOut),
                DockSprite.animate(\.popScale, to: 1, duration: 0.18),
            ]), withKey: "grow")
        }
        startWobble(pumpkin)
    }

    func startWobble(_ node: SKNode, amount: ClosedRange<CGFloat> = 0.02...0.04) {
        let angle = CGFloat.random(in: amount)
        let duration = Double.random(in: 1.6...2.6)
        let left = SKAction.rotate(toAngle: angle, duration: duration)
        let right = SKAction.rotate(toAngle: -angle, duration: duration)
        left.timingMode = .easeInEaseOut
        right.timingMode = .easeInEaseOut
        node.run(.sequence([
            .wait(forDuration: Double.random(in: 0...1.5)),
            .repeatForever(.sequence([left, right])),
        ]), withKey: "wobble")
    }

    /// The thing under `point` (scene coordinates) that reacts to a click, if any.
    func target(at point: CGPoint) -> DockSprite? {
        // Over the Dock's own icons the Dock gets the pointer, so it can magnify.
        guard !isPointerOnDock else { return nil }
        return pumpkinLayer.children
            .compactMap { $0 as? DockSprite }
            .filter { $0.isInteractive && !$0.isDetached && $0.frame.insetBy(dx: abs($0.frame.width) * 0.08, dy: 0).contains(point) }
            .max { $0.zPosition < $1.zPosition }
    }

    func setHovered(_ sprite: DockSprite?) {
        guard sprite !== hovered else { return }
        if let old = hovered, !old.isDetached {
            old.run(DockSprite.animate(\.hoverScale, to: 1, duration: 0.12), withKey: "hover")
        }
        hovered = sprite
        if let squirrel = sprite as? SquirrelNode {
            squirrelFlee(squirrel)
        } else if let sprite {
            sprite.run(DockSprite.animate(\.hoverScale, to: 1.08, duration: 0.12, curve: .easeOut), withKey: "hover")
        }
    }

    // MARK: Clicking

    override func mouseDown(with event: NSEvent) {
        switch target(at: event.location(in: self)) {
        case let pumpkin as PumpkinNode: smash(pumpkin)
        case let decor as DecorNode: poke(decor)
        case let squirrel as SquirrelNode: squirrelFlee(squirrel)
        default: break
        }
    }

    func smash(_ pumpkin: PumpkinNode) {
        guard !pumpkin.isSmashing else { return }
        pumpkin.isSmashing = true
        pumpkin.isDetached = true
        pumpkins[pumpkin.slot] = nil
        if hovered === pumpkin { hovered = nil }
        pumpkin.removeAllActions()

        // Squash down, then burst.
        let magnification = pumpkin.yScale
        let squash = SKAction.group([.scaleX(to: pumpkin.xScale * 1.2, duration: 0.07), .scaleY(to: pumpkin.yScale * 0.7, duration: 0.07)])
        squash.timingMode = .easeOut
        pumpkin.run(.sequence([
            squash,
            .run { [weak self, weak pumpkin] in
                guard let self, let pumpkin else { return }
                self.burst(pumpkin, scale: magnification)
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

    private func burst(_ pumpkin: PumpkinNode, scale m: CGFloat) {
        let width = pumpkin.size.width * m
        let h = pumpkin.size.height * m
        let center = CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + h * 0.35)

        // Splat left behind where it sat.
        let splatWidth = (width * 1.15).rounded()
        let splat = SKSpriteNode(texture: PumpkinArt.splatTexture(kind: pumpkin.kind, width: splatWidth, scale: pixelScale),
                                 size: CGSize(width: splatWidth, height: splatWidth * 0.32))
        splat.anchorPoint = CGPoint(x: 0.5, y: 0.35)
        splat.position = CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + 2)
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
            launch(chunk, from: center, spread: width * 0.3,
                   velocity: CGVector(dx: CGFloat.random(in: -190...190), dy: CGFloat.random(in: 160...380)),
                   radius: s * 0.3, damping: 0.2, life: 1.1)
        }

        // Seeds.
        let seedScale = h / 40
        for _ in 0..<9 {
            let seed = SKSpriteNode(texture: PumpkinArt.seedTexture(scale: pixelScale),
                                    size: CGSize(width: 3.2 * seedScale, height: 5 * seedScale))
            launch(seed, from: center, spread: width * 0.2,
                   velocity: CGVector(dx: CGFloat.random(in: -150...150), dy: CGFloat.random(in: 120...300)),
                   radius: 1.5, damping: 0.3, life: 1.0)
        }

        // A couple of leaves that flutter out and drift down slowly.
        flutterLeaves(count: 2, from: center, size: (h * 0.26).rounded())
    }

    /// Leaves that pop up from `center` and drift down slowly.
    func flutterLeaves(count: Int, from center: CGPoint, size s: CGFloat, spread: CGFloat = 4, upward: ClosedRange<CGFloat> = 220...320) {
        for i in 0..<count {
            let kind = LeafKind.fallers.randomElement() ?? .oak
            let leaf = SKSpriteNode(texture: LeafArt.texture(kind, size: s, variant: i, scale: pixelScale),
                                    size: CGSize(width: s, height: s))
            launch(leaf, from: center, spread: spread,
                   velocity: CGVector(dx: CGFloat.random(in: -120...120), dy: CGFloat.random(in: upward)),
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
            pumpkin.run(.sequence([.wait(forDuration: 0.05 * Double(distance)), DockSprite.hop(height: hop, duration: 0.22)]),
                        withKey: "hop")
        }
    }

    // MARK: Brushing past

    /// Sweeping the pointer quickly across the pumpkins rocks them, like brushing past in a field.
    private func brushPast(_ point: CGPoint) {
        let now = CACurrentMediaTime()
        defer { lastPointer = (point, now) }
        guard let last = lastPointer, now - last.time > 0.001, now - last.time < 0.25 else { return }
        let vx = (point.x - last.point.x) / CGFloat(now - last.time)
        guard abs(vx) > 700, point.y > dockRect.maxY, point.y < dockRect.maxY + pumpkinHeight * 2.2 else { return }
        for case let sprite as DockSprite in pumpkinLayer.children where !sprite.isDetached && sprite.action(forKey: "rock") == nil {
            let frame = sprite.frame
            guard point.x > frame.minX - 4, point.x < frame.maxX + 4, point.y < frame.maxY + 6 else { continue }
            let lean = -(vx > 0 ? 1 : -1) * CGFloat.random(in: 0.12...0.18)
            let rock = SKAction.sequence([
                .rotate(toAngle: lean, duration: 0.09),
                .rotate(toAngle: -lean * 0.55, duration: 0.16),
                .rotate(toAngle: lean * 0.25, duration: 0.16),
                .rotate(toAngle: 0, duration: 0.2),
            ])
            rock.timingMode = .easeInEaseOut
            let wobble = sprite.action(forKey: "wobble")
            sprite.removeAction(forKey: "wobble")
            sprite.run(.sequence([rock, .run { [weak self, weak sprite] in
                guard let self, let sprite, wobble != nil else { return }
                self.startWobble(sprite)
            }]), withKey: "rock")
            if let decor = sprite as? DecorNode, decor.kind == .leafPile, !decor.isScattered {
                flutterLeaves(count: 1, from: CGPoint(x: frame.midX, y: frame.maxY - 4), size: (pumpkinHeight * 0.22).rounded(),
                              upward: 60...140)
            }
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
