import SpriteKit

/// A pumpkin sitting on the Dock.
final class PumpkinNode: DockSprite {
    let kind: PumpkinKind
    let slot: Int
    let slotHeight: CGFloat
    let variant: Int
    var isSmashing = false
    /// Carved into a glowing jack-o'-lantern (at Halloween).
    var isLantern = false

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
    /// Each slot's kind of pumpkin; a smashed one grows back the same kind.
    private var slotKinds: [PumpkinKind] = []
    var gapX: [CGFloat] = []
    /// The decoration in each gap, and where in the season's gap cycle this harvest starts.
    var gapKinds: [DecorKind] = []
    private var decorStart = 0
    /// Picks each slot's kind of pumpkin; a new one for every fresh harvest.
    private var harvestSeed: UInt64 = 1
    private var pumpkins: [Int: PumpkinNode] = [:]
    private weak var hovered: DockSprite?

    private let vineLayer = SKNode()
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
    /// A new Dock size that arrived while the Dock was magnified.
    private var pendingDockRect: CGRect?

    /// Size unit for the vine: 1 for a typical 60 pt pumpkin.
    var unit: CGFloat { pumpkinHeight / 60 }
    private let sound = SmashSound()
    let meow = MeowSound()

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

    /// How tall pumpkins are. It stays the same whatever size the Dock is: a longer Dock fits more
    /// pumpkins and decorations rather than bigger ones.
    static let itemHeight: CGFloat = 90
    /// Decorations are drawn a bit smaller than the pumpkins.
    static let decorScale: CGFloat = 0.75
    var decorUnit: CGFloat { (pumpkinHeight * Self.decorScale).rounded() }

    /// Lines the harvest up along the top edge of `dockRect` (scene coordinates). `regrow` starts a
    /// fresh harvest; otherwise a change in the Dock's length adds or removes things at the end.
    func configure(dockRect: CGRect, pixelScale: CGFloat, magnifier: DockMagnifier, regrow: Bool) {
        self.magnifier = magnifier
        let fresh = regrow || pixelScale != self.pixelScale || self.dockRect.width == 0
        guard fresh || dockRect != self.dockRect else {
            pendingDockRect = nil
            return
        }
        // The Dock's measured width can swell while it magnifies, so wait until the pointer leaves it
        // (`update` applies it then). Resizing by dragging the Dock's divider happens with the pointer on it.
        if !fresh && magnifyStrength > 0.01 {
            pendingDockRect = dockRect
            return
        }
        pendingDockRect = nil

        self.dockRect = dockRect
        self.pixelScale = pixelScale
        pumpkinHeight = Self.itemHeight
        if fresh {
            harvestSeed = UInt64.random(in: 1...UInt64(Int32.max))
            decorStart = Int.random(in: 0..<Settings.theme.gapCycle.count)
        }
        let oldCount = pumpkinCount
        layoutSlots()
        if fresh {
            rebuild()
        } else {
            rearrange(from: oldCount)
        }
    }

    /// Fits as many pumpkins (with a decoration between each two) as the Dock has room for, keeping
    /// at least the spacing the menu asks for, then spreads the leftover room evenly between them.
    /// Every slot and gap is worked out from its position alone, so a longer Dock keeps everything
    /// already there and adds more at the end.
    private func layoutSlots() {
        let h = pumpkinHeight
        let extras = Settings.cozyExtras
        // Something in the gaps between pumpkins only if some of those extras are switched on.
        let gapsOn = extras && !Self.gapCycle.isEmpty
        let minSpace = h * Settings.fullness.spacing
        // Hay bales in fall, tree stumps at Halloween.
        let perch = Settings.theme.perch
        let bale = CozyArt.size(of: perch, unit: h)
        slotKinds = []; slotScale = []; slotPerch = []; gapKinds = []
        var widths: [CGFloat] = [] // pumpkin, decoration, pumpkin, … from left to right
        var used: CGFloat = 0
        var slot = 0
        while slot < 200 {
            var gapKind: DecorKind?
            var gapWidth: CGFloat = 0
            if gapsOn && slot > 0 {
                let kind = decorKind(gap: slot - 1)
                gapKind = kind
                gapWidth = CozyArt.size(of: kind, unit: decorUnit).width
            }
            // A hay bale (or tree stump) under every fifth pumpkin.
            let onBale = extras && Settings.isEnabled(perch) && slot % 5 == 2
            var rng = SeededRandom(seed: UInt64(slot + 1) &* 7537)
            // Pumpkins vary a little in size, every third one a bit smaller.
            let scale = onBale ? rng.float(0.76...0.82) : slot % 3 == 1 ? rng.float(0.82...0.88) : rng.float(0.92...1.0)
            let kind = pumpkinKind(slot: slot, onBale: onBale)
            let width = max(onBale ? bale.width : 0, PumpkinArt.size(of: kind, height: (h * scale).rounded()).width)
            let items = widths.count + (gapKind == nil ? 1 : 2)
            guard used + gapWidth + width + CGFloat(items + 1) * minSpace <= dockRect.width else { break }
            if let gapKind {
                gapKinds.append(gapKind)
                widths.append(gapWidth)
            }
            widths.append(width)
            slotKinds.append(kind)
            slotScale.append(scale)
            slotPerch.append(onBale ? bale.height * 0.86 : 0)
            used += gapWidth + width
            slot += 1
        }
        pumpkinCount = slot

        let space = (dockRect.width - used) / CGFloat(widths.count + 1)
        var x = dockRect.minX + space
        slotX = []
        gapX = []
        for (i, width) in widths.enumerated() {
            if !gapsOn || i % 2 == 0 {
                slotX.append(x + width / 2)
            } else {
                gapX.append(x + width / 2)
            }
            x += width + space
        }
    }

    /// The kind of pumpkin in a slot, the same every time for this harvest.
    private func pumpkinKind(slot: Int, onBale: Bool) -> PumpkinKind {
        var rng = SeededRandom(seed: harvestSeed &+ UInt64(slot) &* 2_654_435_761)
        // Tall butternuts would tower over everything on top of a hay bale.
        let kinds: [PumpkinKind]
        switch Settings.theme {
        case .fall: kinds = onBale ? [.roundOrange, .roundMustard, .squatOrange, .squatMustard] : PumpkinKind.fall
        case .halloween: kinds = onBale ? [.roundOrange, .squatOrange] : PumpkinKind.halloween
        }
        return kinds[Int(rng.next() % UInt64(kinds.count))]
    }

    /// The decoration in the next gap (`gapKinds` holds the ones before it): down the cycle, with the
    /// season's special extras (the latte and lantern, the cauldron and cat) at most once every eight gaps.
    private func decorKind(gap: Int) -> DecorKind {
        let cycle = Self.gapCycle
        let specials = Settings.theme.specials
        let kind = cycle[(decorStart + gap) % cycle.count]
        guard specials.contains(kind), gapKinds.suffix(8).contains(kind) else { return kind }
        return cycle.first { !specials.contains($0) } ?? kind
    }

    /// The season's gap cycle without the extras that are switched off.
    private static var gapCycle: [DecorKind] { Settings.theme.gapCycle.filter(Settings.isEnabled) }

    /// The Dock got longer or shorter. Everything keeps its size and slides to its new spot;
    /// pumpkins and decorations grow in or shrink away at the end.
    private func rearrange(from oldCount: Int) {
        for slot in pumpkinCount..<max(pumpkinCount, oldCount) {
            removeAction(forKey: "respawn-\(slot)")
            if let pumpkin = pumpkins.removeValue(forKey: slot) { retire(pumpkin) }
        }
        for (slot, pumpkin) in pumpkins {
            slide(pumpkin, to: CGPoint(x: slotX[slot], y: restingY(slot: slot)))
        }
        for slot in oldCount..<max(oldCount, pumpkinCount) where pumpkins[slot] == nil {
            addPumpkin(slot: slot, grow: true)
        }
        if Settings.cozyExtras { rearrangeDecorations() }
        layoutVine()
    }

    func slide(_ sprite: DockSprite, to point: CGPoint) {
        sprite.run(.group([
            DockSprite.animate(\.restX, to: point.x, duration: 0.35),
            DockSprite.animate(\.restY, to: point.y, duration: 0.35),
        ]), withKey: "move")
    }

    /// Shrinks something away and removes it.
    func retire(_ sprite: DockSprite) {
        guard !sprite.isLeaving else { return }
        sprite.isLeaving = true
        if hovered === sprite { hovered = nil }
        sprite.removeAction(forKey: "move")
        sprite.run(.sequence([DockSprite.animate(\.popScale, to: 0.05, duration: 0.25, curve: .easeIn), .removeFromParent()]),
                   withKey: "leave")
    }

    /// Grows something in from nothing, with a little overshoot.
    func popIn(_ sprite: DockSprite) {
        sprite.popScale = 0.05
        sprite.run(.sequence([
            DockSprite.animate(\.popScale, to: 1.12, duration: 0.35, curve: .easeOut),
            DockSprite.animate(\.popScale, to: 1, duration: 0.18),
        ]), withKey: "grow")
    }

    /// Draws the same harvest again, after the Mac switches between Light and Dark.
    func repaint() {
        guard dockRect.width > 0 else { return }
        rebuild()
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
        if Settings.cozyExtras {
            addDecorations()
            scheduleVisitor(first: true)
        }
        startAmbient()
    }

    private func restingY(slot: Int) -> CGFloat {
        // Sink 3 pt into the Dock so pumpkins look like they're sitting on it.
        // Smaller pumpkins sit a touch lower, as if they're in front.
        dockRect.maxY - 3 - (slotPerch[slot] > 0 ? 0 : (1 - slotScale[slot]) * 5)
    }

    /// A vine running along the top of the Dock, behind the pumpkins (purple dirt at Halloween).
    private func layoutVine() {
        vineLayer.removeAllChildren()
        vine = nil
        vineWarpStrength = -1
        let k = unit
        vineOrigin = CGPoint(x: dockRect.minX + 4, y: dockRect.maxY - 2 - VineArt.baseLevel(unit: k))
        guard Settings.showVines, dockRect.width > 40 else {
            layoutCobwebs()
            return
        }
        if Settings.theme == .halloween {
            // Purple graveyard dirt instead of a vine, with things planted in it.
            let height = (pumpkinHeight * 0.3).rounded()
            let dirt = SKSpriteNode(texture: SpookyArt.dirtTexture(width: dockRect.width.rounded(), height: height, seed: Int(harvestSeed % 997),
                                                                   unit: k, scale: pixelScale),
                                    size: CGSize(width: dockRect.width.rounded(), height: height))
            dirt.anchorPoint = .zero
            dirt.position = CGPoint(x: dockRect.minX, y: dockRect.maxY - 6)
            vineLayer.addChild(dirt)
            vine = dirt
            layoutCobwebs()
            return
        }
        let width = (dockRect.width - 8).rounded()
        let height = (pumpkinHeight * 1.25).rounded()
        let vine = SKSpriteNode(texture: VineArt.texture(width: width, height: height, seed: Int(harvestSeed % 997), unit: k, scale: pixelScale),
                                size: CGSize(width: width, height: height))
        vine.anchorPoint = .zero
        vine.position = vineOrigin
        vineLayer.addChild(vine)
        self.vine = vine
        layoutCobwebs()
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

        let onDock = isPointerOnDock
        if onDock, let pointer { pointerX = pointer.x }
        // The Dock eases in and out of magnification, but tracks the pointer instantly.
        magnifyStrength += ((onDock ? 1 : 0) - magnifyStrength) * (1 - exp(-CGFloat(dt) * 14))
        if magnifyStrength < 0.001 { magnifyStrength = 0 }
        if let pending = pendingDockRect, magnifyStrength == 0 {
            configure(dockRect: pending, pixelScale: pixelScale, magnifier: magnifier, regrow: false)
        }

        for case let sprite as DockSprite in pumpkinLayer.children where !sprite.isDetached {
            place(sprite)
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
        let kind = slotKinds[slot]
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
        cast.alpha = Palette.appearance == .dark ? 0.24 : 0.16
        cast.position = CGPoint(x: 3 * unit, y: -1.5 * unit)
        cast.zPosition = -0.6
        pumpkin.addChild(cast)

        pumpkinLayer.addChild(pumpkin)
        pumpkins[slot] = pumpkin
        place(pumpkin)

        if grow { popIn(pumpkin) }
        startWobble(pumpkin)
        // At Halloween, the orange pumpkins are jack-o'-lanterns.
        if Settings.theme == .halloween && kind.isCarvable { carve(pumpkin, animated: grow) }
    }

    /// With Reduce Motion on (System Settings → Accessibility → Display), nothing moves by itself:
    /// no wobbling, falling leaves, steam, flicker or visiting squirrel. Things still react when clicked.
    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func startWobble(_ node: SKNode, amount: ClosedRange<CGFloat> = 0.02...0.04) {
        guard !Self.reduceMotion else { return }
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
            .filter { $0.isInteractive && !$0.isDetached && !$0.isLeaving && $0.frame.insetBy(dx: abs($0.frame.width) * 0.08, dy: 0).contains(point) }
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
            if let pumpkin = sprite as? PumpkinNode { flare(pumpkin) }
            if let decor = sprite as? DecorNode, decor.kind == .blackCat { catNotices(decor) }
        }
    }

    // MARK: Clicking

    override func mouseDown(with event: NSEvent) {
        switch target(at: event.location(in: self)) {
        case let pumpkin as PumpkinNode: smash(pumpkin)
        case let decor as DecorNode: poke(decor)
        case let squirrel as SquirrelNode: squirrelFlee(squirrel)
        case let ghost as GhostNode: ghostFlee(ghost)
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
                // A bat was hiding in the jack-o'-lantern.
                if pumpkin.isLantern {
                    self.releaseBat(from: CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + pumpkin.size.height * magnification * 0.5))
                }
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

        if Settings.theme == .halloween {
            // Jack-o'-lanterns are full of candy.
            candyBurst(count: 3, from: center)
        } else {
            // A couple of leaves that flutter out and drift down slowly.
            flutterLeaves(count: 2, from: center, size: (h * 0.26).rounded())
        }
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

    func launch(_ node: SKSpriteNode, from center: CGPoint, spread: CGFloat,
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
        guard !Self.reduceMotion else { return }
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

    // MARK: Falling leaves (or bats)

    /// The season's drifting things: a leaf falling now and then in fall, a bat fluttering past at Halloween.
    private func startAmbient() {
        removeAction(forKey: "leaves")
        guard !Self.reduceMotion else { return }
        let halloween = Settings.theme == .halloween
        run(.repeatForever(.sequence([
            .wait(forDuration: halloween ? 10 : 5, withRange: halloween ? 8 : 6),
            .run { [weak self] in
                guard let self else { return }
                if halloween {
                    if Settings.bats { self.batAcross() }
                } else {
                    self.dropLeaf()
                }
            },
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
