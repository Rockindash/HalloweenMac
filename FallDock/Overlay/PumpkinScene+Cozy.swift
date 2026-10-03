import SpriteKit

/// The cozy extras: decorations between the pumpkins, lights on the vine and the visiting squirrel.
extension PumpkinScene {
    /// Lights glow brighter in the evening.
    private static var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 7
    }

    // MARK: Decorations

    func addDecorations() {
        let h = pumpkinHeight

        // Hay bales under the pumpkins that sit up high, behind every pumpkin.
        for (slot, perch) in slotPerch.enumerated() where perch > 0 {
            let size = CozyArt.size(of: .hayBale, unit: h)
            let bale = DecorNode(kind: .hayBale, gap: -(slot + 1),
                                 texture: CozyArt.texture(.hayBale, unit: h, variant: slot, scale: pixelScale), size: size)
            bale.anchorPoint = CGPoint(x: 0.5, y: 0)
            bale.restX = slotX[slot]
            bale.restY = dockRect.maxY - 3
            bale.zPosition = 0.5
            pumpkinLayer.addChild(bale)
        }

        // Something cozy in every gap between pumpkins, in front of them.
        let cycle = DecorKind.gapCycle
        let start = Int.random(in: 0..<cycle.count)
        var placed = Set<DecorKind>()
        for (gap, x) in gapX.enumerated() {
            var kind = cycle[(start + gap) % cycle.count]
            // Just one mug and one lantern.
            if kind == .mug || kind == .lantern {
                if placed.contains(kind) { kind = .leafPile }
                placed.insert(kind)
            }
            // Shrink to fit narrow gaps.
            let room = slotX[gap + 1] - slotX[gap] - h * 0.9
            let fit = (room * 1.15 / CozyArt.size(of: kind, unit: h).width).clamped(to: 0.6...1)
            let unit = (h * fit).rounded()
            let size = CozyArt.size(of: kind, unit: unit)
            let decor = DecorNode(kind: kind, gap: gap,
                                  texture: CozyArt.texture(kind, unit: unit, variant: gap, scale: pixelScale), size: size)
            decor.anchorPoint = CGPoint(x: 0.5, y: 0)
            decor.restX = x
            decor.restY = dockRect.maxY - 2
            decor.zPosition = 6 + CGFloat(gap) * 0.01
            pumpkinLayer.addChild(decor)

            switch kind {
            case .mug: startSteam(decor, unit: unit)
            case .lantern: addLanternGlow(decor, unit: unit)
            case .corn: startWobble(decor, amount: 0.012...0.022)
            default: break
            }
        }
    }

    /// Puts decorations back in their gaps after the Dock changes width.
    func moveDecorations() {
        for case let decor as DecorNode in pumpkinLayer.children {
            let x: CGFloat
            if decor.gap >= 0 {
                guard decor.gap < gapX.count else { continue }
                x = gapX[decor.gap]
            } else {
                let slot = -decor.gap - 1
                guard slot < slotX.count else { continue }
                x = slotX[slot]
            }
            decor.run(.group([
                DockSprite.animate(\.restX, to: x, duration: 0.35),
                DockSprite.animate(\.restY, to: dockRect.maxY - (decor.kind == .hayBale ? 3 : 2), duration: 0.35),
            ]), withKey: "move")
        }
    }

    private func startSteam(_ mug: DecorNode, unit h: CGFloat) {
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
        wisp.position = CGPoint(x: -mug.size.width * 0.12 + CGFloat.random(in: -3...3), y: mug.size.height * 0.78)
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
        glow.run(.repeatForever(.sequence(steps)), withKey: "flicker")
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
                    self.puffSteam(from: decor, unit: decor.size.height / 0.52, strong: true)
                }]))
            }
            decor.run(.sequence([.rotate(toAngle: 0.14, duration: 0.1), .rotate(toAngle: -0.08, duration: 0.12), .rotate(toAngle: 0, duration: 0.12)]))
        case .lantern:
            decor.childNode(withName: "glow")?.run(.sequence([.scale(to: 1.7, duration: 0.15), .scale(to: 1, duration: 0.6)]))
            decor.run(DockSprite.hop(height: h * 0.08, duration: 0.25), withKey: "hop")
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

    // MARK: Lights on the vine

    func addLights() {
        guard Settings.showVines, dockRect.width > 40 else { return }
        let h = pumpkinHeight
        let size = CGSize(width: (h * 0.12).rounded(), height: (h * 0.17).rounded())
        let spacing = h * 0.62
        let evening = Self.isEvening
        let low: CGFloat = evening ? 0.45 : 0.2
        let high: CGFloat = evening ? 0.95 : 0.55
        var x = dockRect.minX + spacing * 0.6
        var i = 0
        while x < dockRect.maxX - spacing * 0.4 {
            let color = i % CozyArt.bulbColors.count
            let bulb = BulbNode(texture: CozyArt.bulbTexture(color: color, unit: h, scale: pixelScale), color: .clear, size: size)
            bulb.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            bulb.restX = x
            bulb.restY = vineY(atSceneX: x) - 1
            bulb.zRotation = CGFloat.random(in: -0.35...0.35)

            let diameter = (h * 0.5).rounded()
            let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: CozyArt.bulbColors[color], diameter: diameter, scale: pixelScale),
                                    size: CGSize(width: diameter, height: diameter))
            glow.blendMode = .add
            glow.position = CGPoint(x: 0, y: size.height * 0.5)
            glow.zPosition = -0.1
            glow.alpha = low
            bulb.addChild(glow)
            let up = SKAction.fadeAlpha(to: high, duration: Double.random(in: 0.9...1.8))
            let down = SKAction.fadeAlpha(to: low, duration: Double.random(in: 0.9...1.8))
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            glow.run(.sequence([.wait(forDuration: Double.random(in: 0...2)), .repeatForever(.sequence([up, down]))]), withKey: "twinkle")

            lightsLayer.addChild(bulb)
            x += spacing * CGFloat.random(in: 0.85...1.15)
            i += 1
        }
    }

    // MARK: The squirrel

    func scheduleSquirrel(first: Bool) {
        removeAction(forKey: "squirrel")
        run(.sequence([
            .wait(forDuration: first ? Double.random(in: 10...20) : Double.random(in: 45...90)),
            .run { [weak self] in self?.squirrelVisit() },
        ]), withKey: "squirrel")
    }

    /// A squirrel hops in from one end, stops by the acorns for a nibble, looks around and hops off the other end.
    private func squirrelVisit() {
        guard Settings.cozyExtras, dockRect.width > 300, !pumpkinLayer.children.contains(where: { $0 is SquirrelNode }) else {
            scheduleSquirrel(first: false)
            return
        }
        let h = pumpkinHeight
        let squirrel = makeSquirrel()
        let fromLeft = Bool.random()
        let startX = fromLeft ? dockRect.minX + h * 0.3 : dockRect.maxX - h * 0.3
        let endX = fromLeft ? dockRect.maxX - h * 0.3 : dockRect.minX + h * 0.3
        // Head for the acorns if there are some, otherwise somewhere in the middle third.
        let acorns = pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.kind == .acorns }.map(\.restX)
        let spot = acorns.randomElement() ?? CGFloat.random(in: (dockRect.minX + dockRect.width / 3)...(dockRect.maxX - dockRect.width / 3))
        let stopX = spot + (fromLeft ? -h * 0.32 : h * 0.32)
        let dir: CGFloat = fromLeft ? 1 : -1

        squirrel.restX = startX
        squirrel.facing = dir
        squirrel.alpha = 0
        pumpkinLayer.addChild(squirrel)

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
            nibble,
            lookAround,
            hops(from: stopX, to: endX, hopLength: h * 0.42, height: h * 0.16, duration: 0.2),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleSquirrel(first: false) },
        ]), withKey: "visit")
    }

    private func makeSquirrel() -> SquirrelNode {
        let h = pumpkinHeight
        let size = CozyArt.squirrelSize(unit: h)
        let squirrel = SquirrelNode(texture: CozyArt.squirrelTexture(unit: h, scale: pixelScale), color: .clear, size: size)
        squirrel.anchorPoint = CGPoint(x: 0.5, y: 0)
        squirrel.restY = dockRect.maxY - 2
        squirrel.zPosition = 7

        let tail = SKSpriteNode(texture: CozyArt.squirrelTailTexture(unit: h, scale: pixelScale), size: size)
        tail.anchorPoint = CozyArt.tailBase
        tail.position = CGPoint(x: (CozyArt.tailBase.x - 0.5) * size.width, y: CozyArt.tailBase.y * size.height)
        tail.zPosition = -0.1
        let swish = SKAction.sequence([.rotate(toAngle: 0.14, duration: 0.45), .rotate(toAngle: -0.06, duration: 0.45)])
        swish.timingMode = .easeInEaseOut
        tail.run(.repeatForever(swish))
        squirrel.addChild(tail)
        return squirrel
    }

    /// Hops along the Dock from one x to another.
    private func hops(from x0: CGFloat, to x1: CGFloat, hopLength: CGFloat, height: CGFloat, duration: TimeInterval) -> SKAction {
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
            .run { [weak self] in self?.scheduleSquirrel(first: false) },
        ]), withKey: "visit")
    }
}
