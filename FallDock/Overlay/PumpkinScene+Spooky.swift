import SpriteKit

/// Halloween: jack-o'-lanterns, the spooky extras and what they do when clicked, the ghost,
/// bats and the cobwebs.
extension PumpkinScene {
    // MARK: Jack-o'-lanterns

    /// Carves a face into a pumpkin and lights a candle inside.
    func carve(_ pumpkin: PumpkinNode, animated: Bool) {
        guard !pumpkin.isLantern else { return }
        pumpkin.isLantern = true
        let face = SKSpriteNode(texture: SpookyArt.faceTexture(kind: pumpkin.kind, height: pumpkin.slotHeight,
                                                               face: (pumpkin.slot + pumpkin.variant) % SpookyArt.faceCount,
                                                               scale: pixelScale),
                                size: pumpkin.size)
        face.name = "face"
        face.anchorPoint = pumpkin.anchorPoint
        face.zPosition = 0.1
        pumpkin.addChild(face)

        let diameter = (pumpkin.size.width * 1.5).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.orange.mixed(with: Palette.mustard, 0.5), diameter: diameter,
                                                             scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.name = "candle"
        glow.blendMode = .add
        glow.position = CGPoint(x: 0, y: pumpkin.size.height * 0.42)
        glow.zPosition = 0.2
        glow.alpha = animated ? 0 : 0.42
        pumpkin.addChild(glow)
        if animated {
            face.alpha = 0
            face.run(.fadeIn(withDuration: 0.5))
            glow.run(.fadeAlpha(to: 0.42, duration: 0.6))
        }
        guard !Self.reduceMotion else { return }
        let flicker = (0..<8).map { _ -> SKAction in
            let duration = Double.random(in: 0.08...0.2)
            return .group([.fadeAlpha(to: CGFloat.random(in: 0.3...0.5), duration: duration),
                           .scale(to: CGFloat.random(in: 0.94...1.05), duration: duration)])
        }
        glow.run(.sequence([.wait(forDuration: animated ? 0.6 : 0), .repeatForever(.sequence(flicker))]), withKey: "flicker")
    }

    /// The candle flares up when the pointer comes near, as if the jack-o'-lantern noticed.
    func flare(_ pumpkin: PumpkinNode) {
        guard pumpkin.isLantern, let glow = pumpkin.childNode(withName: "candle") else { return }
        glow.run(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeAlpha(to: 0.8, duration: 0.12)]),
                            .group([.scale(to: 1, duration: 0.5), .fadeAlpha(to: 0.42, duration: 0.5)])]), withKey: "flare")
    }

    // MARK: Words

    /// Bouncy words that pop up, float away and fade.
    func showLabel(_ text: String, at point: CGPoint, color: CGColor = Palette.ghost) {
        let (texture, labelSize) = SpookyArt.labelTexture(text, pointSize: 18, color: color, scale: pixelScale)
        let label = SKSpriteNode(texture: texture, size: labelSize)
        let halfWidth = labelSize.width / 2 + 4
        label.position = CGPoint(x: point.x.clamped(to: halfWidth...max(halfWidth, size.width - halfWidth)),
                                 y: min(point.y, size.height - labelSize.height))
        label.zPosition = 30
        label.zRotation = CGFloat.random(in: -0.1...0.1)
        label.setScale(0.3)
        effectsLayer.addChild(label)
        let pop = SKAction.scale(to: 1.15, duration: 0.14)
        pop.timingMode = .easeOut
        let rise = SKAction.moveBy(x: 0, y: 30, duration: 1.2)
        rise.timingMode = .easeOut
        label.run(.sequence([
            pop,
            .scale(to: 1, duration: 0.1),
            .group([rise, .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.5)])]),
            .removeFromParent(),
        ]))
    }

    // MARK: The spooky extras

    /// The cauldron's brew glows and bubbles away.
    func brew(_ cauldron: DecorNode) {
        let w = cauldron.size.width, ht = cauldron.size.height
        let diameter = (w * 1.1).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.slime, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.name = "glow"
        glow.blendMode = .add
        glow.alpha = 0.35
        glow.position = CGPoint(x: 0, y: ht * SpookyArt.brewLevel)
        glow.zPosition = -0.1
        cauldron.addChild(glow)
        guard !Self.reduceMotion else { return }
        cauldron.run(.repeatForever(.sequence([
            .wait(forDuration: 0.45, withRange: 0.4),
            .run { [weak self, weak cauldron] in
                guard let self, let cauldron else { return }
                self.bubble(from: cauldron, rise: CGFloat.random(in: 0.12...0.28))
            },
        ])), withKey: "bubbles")
    }

    /// One bubble rising off the brew and popping.
    private func bubble(from cauldron: DecorNode, rise: CGFloat) {
        let w = cauldron.size.width, ht = cauldron.size.height
        let s = (pumpkinHeight * CGFloat.random(in: 0.06...0.12)).rounded()
        let bubble = SKSpriteNode(texture: SpookyArt.bubbleTexture(size: s, scale: pixelScale), size: CGSize(width: s, height: s))
        bubble.position = CGPoint(x: CGFloat.random(in: -w * 0.28...w * 0.28), y: ht * SpookyArt.brewLevel)
        bubble.zPosition = 0.2
        bubble.setScale(0.3)
        cauldron.addChild(bubble)
        let up = SKAction.moveBy(x: CGFloat.random(in: -3...3), y: pumpkinHeight * rise, duration: 0.9)
        up.timingMode = .easeOut
        bubble.run(.sequence([
            .group([up, .scale(to: 1, duration: 0.6)]),
            .group([.scale(to: 1.4, duration: 0.08), .fadeOut(withDuration: 0.08)]),
            .removeFromParent(),
        ]))
    }

    /// Flames on the candles' wicks, with a warm glow.
    func light(_ candles: DecorNode) {
        let w = candles.size.width, ht = candles.size.height
        let flameSize = CGSize(width: (pumpkinHeight * 0.075).rounded(), height: (pumpkinHeight * 0.12).rounded())
        for (i, wick) in SpookyArt.candleWicks.enumerated() {
            let flame = SKSpriteNode(texture: SpookyArt.flameTexture(size: flameSize, scale: pixelScale), size: flameSize)
            flame.name = "flame"
            flame.anchorPoint = CGPoint(x: 0.5, y: 0.15)
            flame.position = CGPoint(x: (wick.x - 0.5) * w, y: wick.y * ht)
            flame.zPosition = 0.2
            candles.addChild(flame)
            let diameter = (pumpkinHeight * 0.5).rounded()
            let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.mustard, diameter: diameter, scale: pixelScale),
                                    size: CGSize(width: diameter, height: diameter))
            glow.name = "flame"
            glow.blendMode = .add
            glow.alpha = 0.5
            glow.position = CGPoint(x: flame.position.x, y: flame.position.y + flameSize.height * 0.4)
            glow.zPosition = 0.1
            candles.addChild(glow)
            guard !Self.reduceMotion else { continue }
            let flicker = (0..<6).map { _ -> SKAction in
                let duration = Double.random(in: 0.08...0.18)
                return .group([.scaleX(to: CGFloat.random(in: 0.85...1.1), duration: duration),
                               .scaleY(to: CGFloat.random(in: 0.9...1.15), duration: duration),
                               .rotate(toAngle: CGFloat.random(in: -0.12...0.12), duration: duration)])
            }
            flame.run(.sequence([.wait(forDuration: Double(i) * 0.1), .repeatForever(.sequence(flicker))]), withKey: "flicker")
        }
    }

    /// The black cat's swishing tail and blinking eyes.
    func dress(_ cat: DecorNode) {
        let tail = SKSpriteNode(texture: SpookyArt.catTailTexture(size: cat.size, scale: pixelScale), size: cat.size)
        tail.anchorPoint = SpookyArt.catTailBase
        tail.position = CGPoint(x: (SpookyArt.catTailBase.x - 0.5) * cat.size.width, y: SpookyArt.catTailBase.y * cat.size.height)
        tail.zPosition = -0.1
        cat.addChild(tail)
        let eyes = SpookyArt.catEyes(catSize: cat.size)
        let eyeSprite = SKSpriteNode(texture: SpookyArt.catEyesTexture(size: eyes.size, scale: pixelScale), size: eyes.size)
        eyeSprite.name = "eyes"
        eyeSprite.position = eyes.center
        eyeSprite.zPosition = 0.1
        cat.addChild(eyeSprite)
        guard !Self.reduceMotion else { return }
        let swish = SKAction.sequence([.rotate(toAngle: 0.16, duration: 0.9), .rotate(toAngle: -0.08, duration: 0.9)])
        swish.timingMode = .easeInEaseOut
        tail.run(.repeatForever(swish))
        eyeSprite.run(.repeatForever(.sequence([
            .wait(forDuration: 3, withRange: 3),
            .scaleY(to: 0.1, duration: 0.06),
            .scaleY(to: 1, duration: 0.08),
        ])), withKey: "blink")
    }

    /// The cat's eyes go wide when the pointer comes near.
    func catNotices(_ cat: DecorNode) {
        cat.childNode(withName: "eyes")?.run(.sequence([.scale(to: 1.3, duration: 0.1), .wait(forDuration: 0.5), .scale(to: 1, duration: 0.2)]),
                                             withKey: "notice")
    }

    /// What each spooky extra does when clicked.
    func pokeSpooky(_ decor: DecorNode) {
        let h = pumpkinHeight
        let top = CGPoint(x: decor.position.x, y: decor.position.y + decor.frame.height + 4)
        switch decor.kind {
        case .tombstone:
            ghostRises(behind: decor)
            decor.run(DockSprite.hop(height: h * 0.05, duration: 0.2), withKey: "hop")
        case .blackCat:
            // An arched back and a meow.
            decor.run(.sequence([
                DockSprite.animate(\.popScale, to: 0.88, duration: 0.08),
                DockSprite.animate(\.popScale, to: 1.12, duration: 0.12, curve: .easeOut),
                DockSprite.animate(\.popScale, to: 1, duration: 0.2),
            ]), withKey: "arch")
            catNotices(decor)
            showLabel("Meow!", at: top, color: Palette.slime)
        case .cauldron:
            for _ in 0..<10 {
                let s = (h * CGFloat.random(in: 0.08...0.14)).rounded()
                let bubble = SKSpriteNode(texture: SpookyArt.bubbleTexture(size: s, scale: pixelScale), size: CGSize(width: s, height: s))
                launch(bubble, from: CGPoint(x: decor.position.x, y: decor.position.y + decor.frame.height * SpookyArt.brewLevel), spread: decor.frame.width * 0.2,
                       velocity: CGVector(dx: CGFloat.random(in: -110...110), dy: CGFloat.random(in: 180...320)), radius: s * 0.3, damping: 1.2, life: 1)
            }
            decor.childNode(withName: "glow")?.run(.sequence([.group([.scale(to: 1.6, duration: 0.12), .fadeAlpha(to: 0.8, duration: 0.12)]),
                                                             .group([.scale(to: 1, duration: 0.6), .fadeAlpha(to: 0.35, duration: 0.6)])]))
            decor.run(DockSprite.hop(height: h * 0.06, duration: 0.22), withKey: "hop")
            showLabel("Bubble, bubble!", at: top, color: Palette.slime)
        case .candyCorn:
            candyBurst(count: 6, from: CGPoint(x: decor.position.x, y: decor.position.y + decor.frame.height * 0.6))
            decor.run(DockSprite.hop(height: h * 0.1, duration: 0.25), withKey: "hop")
        case .candles:
            blowOut(decor)
        case .coffin:
            // The lid jolts, and a bat escapes.
            decor.run(.sequence([.rotate(toAngle: 0.04, duration: 0.06), .rotate(toAngle: -0.03, duration: 0.08), .rotate(toAngle: 0, duration: 0.08)]))
            releaseBat(from: CGPoint(x: decor.position.x, y: decor.position.y + decor.frame.height * 0.8))
        default:
            break
        }
    }

    /// A little ghost rises from behind a tombstone, says boo and drifts off.
    private func ghostRises(behind stone: DecorNode) {
        guard stone.childNode(withName: "risen") == nil else { return }
        let h = pumpkinHeight * 0.75
        let size = SpookyArt.ghostSize(unit: h)
        let ghost = SKSpriteNode(texture: SpookyArt.ghostTexture(unit: h, scale: pixelScale), size: size)
        ghost.name = "risen"
        ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
        ghost.position = CGPoint(x: 0, y: stone.size.height * 0.2)
        ghost.zPosition = -0.2
        ghost.alpha = 0
        ghost.setScale(0.6)
        stone.addChild(ghost)
        let rise = SKAction.moveBy(x: 0, y: stone.size.height * 0.85, duration: 0.5)
        rise.timingMode = .easeOut
        ghost.run(.sequence([
            .group([rise, .fadeAlpha(to: 0.92, duration: 0.3), .scale(to: 1, duration: 0.5)]),
            .run { [weak self, weak ghost, weak stone] in
                guard let self, let ghost, let stone else { return }
                let top = stone.convert(CGPoint(x: 0, y: ghost.position.y + size.height), to: self)
                self.showLabel("Boo!", at: top)
            },
            .sequence([.rotate(toAngle: 0.15, duration: 0.15), .rotate(toAngle: -0.15, duration: 0.3), .rotate(toAngle: 0, duration: 0.15)]),
            .wait(forDuration: 0.4),
            .group([.moveBy(x: CGFloat.random(in: -20...20), y: pumpkinHeight * 0.8, duration: 1), .fadeOut(withDuration: 1)]),
            .removeFromParent(),
        ]))
    }

    /// Blows the candles out with a wisp of smoke; they light again a moment later.
    private func blowOut(_ candles: DecorNode) {
        guard candles.action(forKey: "relight") == nil else { return }
        let flames = candles.children.filter { $0.name == "flame" }
        for flame in flames {
            flame.run(.fadeOut(withDuration: 0.15), withKey: "out")
            let size = CGSize(width: (pumpkinHeight * 0.12).rounded(), height: (pumpkinHeight * 0.27).rounded())
            let smoke = SKSpriteNode(texture: CozyArt.steamTexture(unit: pumpkinHeight * 0.75, variant: Int.random(in: 0..<2), scale: pixelScale),
                                     size: size)
            smoke.anchorPoint = CGPoint(x: 0.5, y: 0)
            smoke.color = NSColor(cgColor: Palette.stone) ?? .gray
            smoke.colorBlendFactor = 0.6
            smoke.position = flame.position
            smoke.zPosition = 0.3
            smoke.alpha = 0
            candles.addChild(smoke)
            smoke.run(.sequence([
                .group([.moveBy(x: 0, y: pumpkinHeight * 0.3, duration: 1.2), .sequence([.fadeAlpha(to: 0.7, duration: 0.2), .fadeOut(withDuration: 1)])]),
                .removeFromParent(),
            ]))
        }
        candles.run(.sequence([
            .wait(forDuration: 2.5),
            .run {
                for (i, flame) in flames.enumerated() {
                    // The glows are fainter than the flames themselves.
                    let alpha: CGFloat = (flame as? SKSpriteNode)?.blendMode == .add ? 0.5 : 1
                    flame.run(.sequence([.wait(forDuration: Double(i / 2) * 0.15), .fadeAlpha(to: alpha, duration: 0.2)]), withKey: "out")
                }
            },
        ]), withKey: "relight")
    }

    /// Candy corn flying out.
    func candyBurst(count: Int, from center: CGPoint) {
        for _ in 0..<count {
            let s = (pumpkinHeight * CGFloat.random(in: 0.14...0.2)).rounded()
            let candy = SKSpriteNode(texture: SpookyArt.candyCornTexture(size: s, scale: pixelScale), size: CGSize(width: s, height: s))
            launch(candy, from: center, spread: 6,
                   velocity: CGVector(dx: CGFloat.random(in: -140...140), dy: CGFloat.random(in: 200...340)),
                   radius: s * 0.3, damping: 0.4, life: 1.3)
        }
    }

    // MARK: Bats

    private func makeBat() -> SKSpriteNode {
        let h = pumpkinHeight
        let frames = [SpookyArt.batTexture(frame: 0, unit: h, scale: pixelScale), SpookyArt.batTexture(frame: 1, unit: h, scale: pixelScale)]
        let bat = SKSpriteNode(texture: frames[0], size: SpookyArt.batSize(unit: h))
        bat.zPosition = 25
        bat.run(.repeatForever(.animate(with: frames, timePerFrame: 0.09)))
        return bat
    }

    /// A bat that flutters up out of something and away.
    func releaseBat(from point: CGPoint) {
        let bat = makeBat()
        bat.position = point
        bat.setScale(0.5)
        let side: CGFloat = Bool.random() ? 1 : -1
        let path = CGMutablePath()
        path.move(to: point)
        path.addCurve(to: CGPoint(x: point.x + side * 90, y: point.y + 110),
                      control1: CGPoint(x: point.x - side * 40, y: point.y + 60),
                      control2: CGPoint(x: point.x + side * 20, y: point.y + 130))
        path.addCurve(to: CGPoint(x: point.x + side * 260, y: size.height + 60),
                      control1: CGPoint(x: point.x + side * 160, y: point.y + 90),
                      control2: CGPoint(x: point.x + side * 180, y: size.height - 40))
        effectsLayer.addChild(bat)
        bat.run(.sequence([
            .group([.follow(path, asOffset: false, orientToPath: false, duration: 2.4), .scale(to: 1, duration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    /// A bat fluttering along above the Dock, from one side to the other.
    func batAcross() {
        guard dockRect.width > 0 else { return }
        let bat = makeBat()
        let leftToRight = Bool.random()
        let y = dockRect.maxY + pumpkinHeight * CGFloat.random(in: 1.3...2.2)
        let start = CGPoint(x: leftToRight ? dockRect.minX - 40 : dockRect.maxX + 40, y: y)
        let end = CGPoint(x: leftToRight ? dockRect.maxX + 40 : dockRect.minX - 40, y: y + CGFloat.random(in: -20...40))
        let third = (end.x - start.x) / 3
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: CGPoint(x: start.x + third * 1.5, y: y + 25), control1: CGPoint(x: start.x + third * 0.5, y: y - 35),
                      control2: CGPoint(x: start.x + third, y: y + 50))
        path.addCurve(to: end, control1: CGPoint(x: start.x + third * 2, y: y - 20), control2: CGPoint(x: start.x + third * 2.5, y: end.y + 40))
        bat.position = start
        bat.alpha = 0
        effectsLayer.addChild(bat)
        bat.run(.sequence([
            .group([.follow(path, asOffset: false, orientToPath: false, duration: Double(abs(end.x - start.x) / 160)),
                    .sequence([.fadeIn(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }

    // MARK: The ghost

    /// The ghost floats in from one end. If there are tombstones, it stops above one to say boo,
    /// then floats on and out the other end. Without tombstones it just drifts across.
    func ghostVisit() {
        guard Settings.cozyExtras, Settings.ghost, dockRect.width > 300,
              !pumpkinLayer.children.contains(where: { $0 is GhostNode }) else {
            scheduleVisitor(first: false)
            return
        }
        let h = pumpkinHeight
        let ghost = GhostNode(texture: SpookyArt.ghostTexture(unit: h, scale: pixelScale), color: .clear, size: SpookyArt.ghostSize(unit: h))
        ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
        ghost.restY = dockRect.maxY + h * 0.3
        ghost.zPosition = 8
        ghost.alpha = 0
        let fromLeft = Bool.random()
        let startX = fromLeft ? dockRect.minX + h * 0.3 : dockRect.maxX - h * 0.3
        let endX = fromLeft ? dockRect.maxX - h * 0.3 : dockRect.minX + h * 0.3
        ghost.restX = startX
        ghost.facing = fromLeft ? 1 : -1
        pumpkinLayer.addChild(ghost)

        // A gentle bob the whole time.
        let bob = SKAction.sequence([DockSprite.animate(\.bounce, to: h * 0.08, duration: 0.9),
                                     DockSprite.animate(\.bounce, to: -h * 0.03, duration: 0.9)])
        ghost.run(.repeatForever(bob), withKey: "bob")

        func drift(from x0: CGFloat, to x1: CGFloat) -> SKAction {
            DockSprite.animate(\.restX, to: x1, duration: Double(abs(x1 - x0) / 70), curve: .easeInEaseOut)
        }
        let leave = SKAction.sequence([
            .fadeOut(withDuration: 0.6),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleVisitor(first: false) },
        ])
        let tombstones = pumpkinLayer.children.compactMap { $0 as? DecorNode }.filter { $0.kind == .tombstone }.map(\.restX)
        guard let spot = tombstones.randomElement() else {
            ghost.run(.sequence([.fadeAlpha(to: 0.92, duration: 0.6), drift(from: startX, to: endX), leave]), withKey: "visit")
            return
        }
        ghost.run(.sequence([
            .fadeAlpha(to: 0.92, duration: 0.6),
            drift(from: startX, to: spot),
            .wait(forDuration: 0.3),
            .run { [weak self, weak ghost] in
                guard let self, let ghost else { return }
                self.showLabel("Boo!", at: CGPoint(x: ghost.position.x, y: ghost.position.y + ghost.frame.height + 4))
            },
            DockSprite.animate(\.popScale, to: 1.2, duration: 0.15, curve: .easeOut),
            DockSprite.animate(\.popScale, to: 1, duration: 0.25),
            .wait(forDuration: 1),
            drift(from: spot, to: endX),
            leave,
        ]), withKey: "visit")
    }

    /// Spooked by the pointer: the ghost says eek, zooms up and vanishes.
    func ghostFlee(_ ghost: GhostNode) {
        guard !ghost.isFleeing else { return }
        ghost.isFleeing = true
        ghost.removeAction(forKey: "visit")
        ghost.removeAction(forKey: "bob")
        showLabel("Eek!", at: CGPoint(x: ghost.position.x, y: ghost.position.y + ghost.frame.height + 4))
        ghost.run(.sequence([
            .group([DockSprite.animate(\.bounce, to: pumpkinHeight * 1.6, duration: 0.6, curve: .easeIn), .fadeOut(withDuration: 0.6)]),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleVisitor(first: false) },
        ]), withKey: "visit")
    }

    // MARK: Cobwebs

    /// Cobwebs tucked into both ends of the Dock at Halloween (with the vine), and a spider
    /// dangling from the left one.
    func layoutCobwebs() {
        for case let web as WebNode in pumpkinLayer.children { web.removeFromParent() }
        guard Settings.theme == .halloween, Settings.showVines, dockRect.width > 200 else { return }
        let s = (pumpkinHeight * 0.8).rounded()
        for left in [true, false] {
            let web = WebNode(texture: SpookyArt.cobwebTexture(size: CGSize(width: s, height: s), scale: pixelScale),
                              color: .clear, size: CGSize(width: s, height: s))
            web.anchorPoint = .zero
            web.restX = left ? dockRect.minX + 2 : dockRect.maxX - 2
            web.restY = dockRect.maxY - 3
            web.facing = left ? 1 : -1
            web.zPosition = 0.3
            pumpkinLayer.addChild(web)
            if left { hangSpider(from: web, size: s) }
        }
    }

    private func hangSpider(from web: WebNode, size s: CGFloat) {
        let anchor = CGPoint(x: s * 0.62, y: s * 0.7)
        let thread = SKSpriteNode(color: NSColor(cgColor: SpookyArt.webColor) ?? .white, size: CGSize(width: 1, height: s * 0.3))
        thread.anchorPoint = CGPoint(x: 0.5, y: 1)
        thread.position = anchor
        thread.zPosition = 0.1
        web.addChild(thread)
        let spiderSize = (pumpkinHeight * 0.16).rounded()
        let spider = SKSpriteNode(texture: SpookyArt.spiderTexture(size: spiderSize, scale: pixelScale), size: CGSize(width: spiderSize, height: spiderSize))
        spider.anchorPoint = CGPoint(x: 0.5, y: 0.65)
        spider.position = CGPoint(x: anchor.x, y: anchor.y - s * 0.3)
        spider.zPosition = 0.2
        web.addChild(spider)
        guard !Self.reduceMotion else { return }
        // Slowly lowering and climbing back up.
        thread.run(.repeatForever(.sequence([.resize(toHeight: s * 0.5, duration: 2.4), .wait(forDuration: 1), .resize(toHeight: s * 0.18, duration: 2.4), .wait(forDuration: 1.5)])))
        spider.run(.repeatForever(.sequence([.moveTo(y: anchor.y - s * 0.5, duration: 2.4), .wait(forDuration: 1),
                                             .moveTo(y: anchor.y - s * 0.18, duration: 2.4), .wait(forDuration: 1.5)])))
    }
}
