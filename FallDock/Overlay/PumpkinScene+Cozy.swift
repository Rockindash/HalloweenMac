import SpriteKit

/// The cozy extras: decorations between the pumpkins and the visiting squirrel.
extension PumpkinScene {
    /// The lantern glows brighter in the evening.
    private static var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 7
    }

    // MARK: Decorations

    func addDecorations() {
        for (slot, perch) in slotPerch.enumerated() where perch > 0 {
            addBale(slot: slot, grow: false)
        }
        for gap in gapKinds.indices {
            addDecor(gap: gap, grow: false)
        }
    }

    /// A hay bale (or stack of spell books) under a pumpkin that sits up high, behind every pumpkin.
    private func addBale(slot: Int, grow: Bool) {
        let h = pumpkinHeight
        let perch = Settings.theme.perch
        let bale = DecorNode(kind: perch, gap: -(slot + 1),
                             texture: CozyArt.texture(perch, unit: h, variant: slot, scale: pixelScale),
                             size: CozyArt.size(of: perch, unit: h))
        bale.anchorPoint = CGPoint(x: 0.5, y: 0)
        bale.restX = slotX[slot]
        bale.restY = dockRect.maxY - 3
        bale.zPosition = 0.5
        pumpkinLayer.addChild(bale)
        if grow { popIn(bale) }
    }

    /// Something cozy in a gap between pumpkins, in front of them.
    private func addDecor(gap: Int, grow: Bool) {
        let kind = gapKinds[gap]
        let unit = decorUnit
        let decor = DecorNode(kind: kind, gap: gap,
                              texture: CozyArt.texture(kind, unit: unit, variant: gap, scale: pixelScale),
                              size: CozyArt.size(of: kind, unit: unit))
        decor.anchorPoint = CGPoint(x: 0.5, y: 0)
        decor.restX = gapX[gap]
        decor.restY = dockRect.maxY - 2
        decor.zPosition = 6 + CGFloat(gap % 100) * 0.01
        pumpkinLayer.addChild(decor)
        if grow { popIn(decor) }

        switch kind {
        case .mug: startSteam(decor, unit: unit)
        case .lantern: addLanternGlow(decor, unit: unit)
        case .cauldron: brew(decor)
        case .candles: light(decor)
        case .blackCat: dress(decor)
        default: break
        }
    }

    /// After the Dock changes length: decorations still in use slide to their new spots, the rest
    /// shrink away, and new gaps get theirs.
    func rearrangeDecorations() {
        var present = Set<Int>()
        for case let decor as DecorNode in pumpkinLayer.children where !decor.isLeaving {
            if decor.gap >= 0 {
                guard decor.gap < gapKinds.count, gapKinds[decor.gap] == decor.kind else { retire(decor); continue }
                slide(decor, to: CGPoint(x: gapX[decor.gap], y: dockRect.maxY - 2))
            } else {
                let slot = -decor.gap - 1
                guard slot < slotPerch.count, slotPerch[slot] > 0 else { retire(decor); continue }
                slide(decor, to: CGPoint(x: slotX[slot], y: dockRect.maxY - 3))
            }
            present.insert(decor.gap)
        }
        for slot in slotPerch.indices where slotPerch[slot] > 0 && !present.contains(-(slot + 1)) {
            addBale(slot: slot, grow: true)
        }
        for gap in gapKinds.indices where !present.contains(gap) {
            addDecor(gap: gap, grow: true)
        }
    }

    private func startSteam(_ mug: DecorNode, unit h: CGFloat) {
        guard !Self.reduceMotion else { return }
        mug.run(.repeatForever(.sequence([
            .wait(forDuration: 0.7, withRange: 0.5),
            .run { [weak self, weak mug] in
                guard let self, let mug else { return }
                self.puffSteam(from: mug, unit: h)
            },
        ])), withKey: "steam")
    }

    private func puffSteam(from mug: DecorNode, unit h: CGFloat, strong: Bool = false) {
        let size = CGSize(width: (h * 0.16).rounded(), height: (h * 0.36).rounded())
        let wisp = SKSpriteNode(texture: CozyArt.steamTexture(unit: h, variant: Int.random(in: 0..<2), scale: pixelScale), size: size)
        wisp.anchorPoint = CGPoint(x: 0.5, y: 0)
        // Out of the lid's sip hole.
        wisp.position = CGPoint(x: (CozyArt.latteSteam.x - 0.5) * mug.size.width + CGFloat.random(in: -2...2),
                                y: mug.size.height * CozyArt.latteSteam.y)
        wisp.alpha = 0
        wisp.zPosition = -0.2
        wisp.setScale(0.6)
        mug.addChild(wisp)
        let rise = SKAction.moveBy(x: CGFloat.random(in: -4...4), y: h * (strong ? 0.6 : 0.36), duration: strong ? 1.1 : 1.8)
        rise.timingMode = .easeOut
        wisp.run(.sequence([
            .group([
                rise,
                .scale(to: strong ? 1.3 : 1.05, duration: 1.6),
                .sequence([.fadeAlpha(to: strong ? 0.85 : 0.6, duration: 0.4), .fadeOut(withDuration: strong ? 0.8 : 1.3)]),
            ]),
            .removeFromParent(),
        ]))
    }

    private func addLanternGlow(_ lantern: DecorNode, unit h: CGFloat) {
        let diameter = (h * 1.15).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.mustard, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.name = "glow"
        glow.blendMode = .add
        glow.position = CGPoint(x: 0, y: lantern.size.height * CozyArt.lanternFlameLevel)
        glow.zPosition = 0.1
        let bright: CGFloat = Self.isEvening ? 0.85 : 0.55
        glow.alpha = bright
        lantern.addChild(glow)
        // A candle's flicker.
        let steps = (0..<10).map { _ -> SKAction in
            let duration = Double.random(in: 0.08...0.22)
            return .group([
                .fadeAlpha(to: bright * CGFloat.random(in: 0.75...1.05), duration: duration),
                .scale(to: CGFloat.random(in: 0.94...1.04), duration: duration),
            ])
        }
        if !Self.reduceMotion { glow.run(.repeatForever(.sequence(steps)), withKey: "flicker") }
    }

    // MARK: Poking decorations

    func poke(_ decor: DecorNode) {
        let h = pumpkinHeight
        switch decor.kind {
        case .leafPile:
            scatter(decor)
        case .mug:
            for i in 0..<5 {
                decor.run(.sequence([.wait(forDuration: Double(i) * 0.07), .run { [weak self, weak decor] in
                    guard let self, let decor else { return }
                    self.puffSteam(from: decor, unit: decor.size.height / CozyArt.latteHeight, strong: true)
                }]))
            }
            decor.run(.sequence([.rotate(toAngle: 0.14, duration: 0.1), .rotate(toAngle: -0.08, duration: 0.12), .rotate(toAngle: 0, duration: 0.12)]))
        case .lantern:
            decor.childNode(withName: "glow")?.run(.sequence([.scale(to: 1.7, duration: 0.15), .scale(to: 1, duration: 0.6)]))
            decor.run(DockSprite.hop(height: h * 0.08, duration: 0.25), withKey: "hop")
        case .tombstone, .blackCat, .cauldron, .candy, .candles, .books, .skull:
            pokeSpooky(decor)
        default:
            decor.run(DockSprite.hop(height: h * 0.12, duration: 0.3), withKey: "hop")
        }
    }

    /// Kicks the leaf pile into the air; it gathers itself back up a little later.
    private func scatter(_ pile: DecorNode) {
        guard !pile.isScattered else { return }
        pile.isScattered = true
        let top = CGPoint(x: pile.position.x, y: pile.position.y + pile.frame.height * 0.6)
        flutterLeaves(count: 9, from: top, size: (pumpkinHeight * 0.22).rounded(), spread: pile.frame.width * 0.3, upward: 180...320)
        pile.run(.sequence([
            .group([DockSprite.animate(\.popScale, to: 0.25, duration: 0.15, curve: .easeOut), .fadeOut(withDuration: 0.15)]),
            .wait(forDuration: 7),
            .group([.fadeIn(withDuration: 0.3), DockSprite.animate(\.popScale, to: 1.1, duration: 0.3, curve: .easeOut)]),
            DockSprite.animate(\.popScale, to: 1, duration: 0.15),
            .run { [weak pile] in pile?.isScattered = false },
        ]), withKey: "scatter")
    }

    // MARK: The squirrel

    /// Schedules the season's visitor: the squirrel in fall, the ghost at Halloween.
    func scheduleVisitor(first: Bool) {
        removeAction(forKey: "squirrel")
        guard !Self.reduceMotion, Settings.visitor else { return }
        let halloween = Settings.theme == .halloween
        run(.sequence([
            .wait(forDuration: first ? Double.random(in: 10...20) : Double.random(in: 45...90)),
            .run { [weak self] in
                if halloween { self?.ghostVisit() } else { self?.squirrelVisit() }
            },
        ]), withKey: "squirrel")
    }

    /// A squirrel hops in from one end. If there are acorns on the Dock, it stops by them, picks one
    /// up, nibbles, looks around and hops back the way it came holding it. Without acorns it just
    /// hops across to the other end.
    private func squirrelVisit() {
        guard Settings.cozyExtras, Settings.squirrel, dockRect.width > 300, !pumpkinLayer.children.contains(where: { $0 is SquirrelNode }) else {
            scheduleVisitor(first: false)
            return
        }
        let h = pumpkinHeight
        let squirrel = makeSquirrel()
        let fromLeft = Bool.random()
        let startX = fromLeft ? dockRect.minX + h * 0.3 : dockRect.maxX - h * 0.3
        let endX = fromLeft ? dockRect.maxX - h * 0.3 : dockRect.minX + h * 0.3
        let dir: CGFloat = fromLeft ? 1 : -1

        squirrel.restX = startX
        squirrel.facing = dir
        squirrel.alpha = 0
        pumpkinLayer.addChild(squirrel)

        let leave = SKAction.sequence([
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleVisitor(first: false) },
        ])
        let acorns = pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.kind == .acorns }.map(\.restX)
        guard let spot = acorns.randomElement() else {
            squirrel.run(.sequence([
                .fadeIn(withDuration: 0.25),
                hops(from: startX, to: endX, hopLength: h * 0.42, height: h * 0.16, duration: 0.2),
                leave,
            ]), withKey: "visit")
            return
        }

        let stopX = spot - dir * h * 0.32
        let nibble = SKAction.repeat(DockSprite.hop(height: h * 0.025, duration: 0.14), count: 7)
        let lookAround = SKAction.sequence([
            .wait(forDuration: 0.6),
            .run { [weak squirrel] in squirrel?.facing = -dir },
            .wait(forDuration: 0.7),
            .run { [weak squirrel] in squirrel?.facing = dir },
            .wait(forDuration: 0.4),
        ])
        squirrel.run(.sequence([
            .fadeIn(withDuration: 0.25),
            hops(from: startX, to: stopX, hopLength: h * 0.42, height: h * 0.16, duration: 0.2),
            .wait(forDuration: 0.3),
            // Bob down to the acorns and come up holding one.
            DockSprite.hop(height: -h * 0.04, duration: 0.25),
            .run { [weak self, weak squirrel] in
                guard let self, let squirrel else { return }
                self.giveAcorn(to: squirrel)
            },
            .wait(forDuration: 0.3),
            nibble,
            lookAround,
            // Then back the way it came, acorn in hand.
            .run { [weak squirrel] in squirrel?.facing = -dir },
            .wait(forDuration: 0.2),
            hops(from: stopX, to: startX, hopLength: h * 0.42, height: h * 0.16, duration: 0.2),
            leave,
        ]), withKey: "visit")
    }

    /// Puts an acorn in the squirrel's front paws.
    private func giveAcorn(to squirrel: SquirrelNode) {
        let h = pumpkinHeight
        let s = (h * 0.14).rounded()
        let acorn = SKSpriteNode(texture: CozyArt.acornTexture(size: s, scale: pixelScale), size: CGSize(width: s * 0.8, height: s))
        acorn.anchorPoint = CGPoint(x: 0.5, y: 0.3)
        acorn.position = CozyArt.squirrelPaws(unit: h)
        acorn.zPosition = 0.1
        acorn.setScale(0.2)
        squirrel.addChild(acorn)
        acorn.run(.scale(to: 1, duration: 0.15))
    }

    private func makeSquirrel() -> SquirrelNode {
        let h = pumpkinHeight
        let size = CozyArt.squirrelSize(unit: h)
        let squirrel = SquirrelNode(texture: CozyArt.squirrelTexture(unit: h, scale: pixelScale), color: .clear, size: size)
        squirrel.anchorPoint = CGPoint(x: 0.5, y: 0)
        squirrel.restY = dockRect.maxY - 2
        squirrel.zPosition = 7

        let tail = SKSpriteNode(texture: CozyArt.squirrelTailTexture(unit: h, scale: pixelScale), size: size)
        let tailBase = CozyArt.tailBase(unit: h)
        tail.anchorPoint = tailBase
        tail.position = CGPoint(x: (tailBase.x - 0.5) * size.width, y: tailBase.y * size.height)
        tail.zPosition = -0.1
        let swish = SKAction.sequence([.rotate(toAngle: 0.14, duration: 0.45), .rotate(toAngle: -0.06, duration: 0.45)])
        swish.timingMode = .easeInEaseOut
        tail.run(.repeatForever(swish))
        squirrel.addChild(tail)
        return squirrel
    }

    /// Hops along the Dock from one x to another.
    func hops(from x0: CGFloat, to x1: CGFloat, hopLength: CGFloat, height: CGFloat, duration: TimeInterval) -> SKAction {
        let count = max(1, Int((abs(x1 - x0) / hopLength).rounded()))
        let steps = (1...count).map { i -> SKAction in
            let x = x0 + (x1 - x0) * CGFloat(i) / CGFloat(count)
            return .group([
                DockSprite.animate(\.restX, to: x, duration: duration, curve: .linear),
                DockSprite.hop(height: height * CGFloat.random(in: 0.8...1.1), duration: duration),
            ])
        }
        return .sequence(steps)
    }

    /// Startled by the pointer: a jump, then off to the nearest end of the Dock.
    func squirrelFlee(_ squirrel: SquirrelNode) {
        guard !squirrel.isFleeing else { return }
        squirrel.isFleeing = true
        squirrel.removeAction(forKey: "visit")
        let h = pumpkinHeight
        let toLeft = squirrel.restX - dockRect.minX < dockRect.maxX - squirrel.restX
        let exitX = toLeft ? dockRect.minX + h * 0.2 : dockRect.maxX - h * 0.2
        squirrel.facing = toLeft ? -1 : 1
        squirrel.bounce = 0
        squirrel.run(.sequence([
            DockSprite.hop(height: h * 0.35, duration: 0.3),
            hops(from: squirrel.restX, to: exitX, hopLength: h * 0.6, height: h * 0.12, duration: 0.13),
            .fadeOut(withDuration: 0.15),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleVisitor(first: false) },
        ]), withKey: "visit")
    }
}
