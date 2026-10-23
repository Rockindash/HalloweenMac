import SpriteKit

/// Diwali: lit diyas and lamps that send fireworks into the sky, the crackers and sweets and what
/// they do when clicked, strings of marigolds in the corners and the peacock. Nothing here shows words.
extension PumpkinScene {
    /// The colors fireworks burst in.
    static var fireworkColors: [CGColor] {
        [Palette.magenta, Palette.marigold, Palette.teal, Palette.candyPink, Palette.candlelight, Palette.slime,
         Palette.royal.mixed(with: Palette.ghost, 0.35)]
    }

    // MARK: Diyas and lamps

    /// Lights a diya or lamp: a flame on each wick, with a warm glow, flickering gently.
    func lightLamp(_ lamp: PumpkinNode, animated: Bool) {
        guard !lamp.isLit else { return }
        lamp.isLit = true
        let shape = lamp.kind.look.shape
        let body = PumpkinArt.bodySize(of: lamp.kind, height: lamp.slotHeight)
        let flameHeight = (lamp.slotHeight * (shape == .lampStand ? 0.15 : 0.2)).rounded()
        let flameSize = CGSize(width: (flameHeight * 0.6).rounded(), height: flameHeight)
        let spots = DiwaliArt.flameSpots(shape).map { CGPoint(x: $0.x * body.width, y: PumpkinArt.pad + $0.y * body.height) }
        for (i, spot) in spots.enumerated() {
            let flame = SKSpriteNode(texture: SpookyArt.flameTexture(size: flameSize, scale: pixelScale), size: flameSize)
            flame.name = "flame"
            flame.anchorPoint = CGPoint(x: 0.5, y: 0.12)
            flame.position = spot
            flame.zPosition = 0.2
            lamp.addChild(flame)
            if animated {
                flame.alpha = 0
                flame.run(.sequence([.wait(forDuration: 0.3 + Double(i) * 0.12), .fadeIn(withDuration: 0.3)]))
            }
            flicker(flame, delay: Double(i) * 0.07)
        }

        // One glow, around the middle flame.
        let middle = spots[spots.count / 2]
        let diameter = (lamp.size.width * (shape == .lampStand ? 2.2 : 1.4)).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.marigold.mixed(with: Palette.candlelight, 0.3), diameter: diameter,
                                                             scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.name = "candle"
        glow.blendMode = .add
        glow.position = CGPoint(x: middle.x, y: middle.y + flameHeight * 0.35)
        glow.zPosition = 0.1
        glow.alpha = animated ? 0 : 0.45
        lamp.addChild(glow)
        if animated { glow.run(.sequence([.wait(forDuration: 0.3), .fadeAlpha(to: 0.45, duration: 0.5)])) }
        guard !Self.reduceMotion else { return }
        let steps = (0..<8).map { _ -> SKAction in
            let duration = Double.random(in: 0.1...0.24)
            return .group([.fadeAlpha(to: CGFloat.random(in: 0.35...0.52), duration: duration),
                           .scale(to: CGFloat.random(in: 0.95...1.05), duration: duration)])
        }
        glow.run(.sequence([.wait(forDuration: animated ? 0.8 : 0), .repeatForever(.sequence(steps))]), withKey: "flicker")
    }

    /// A candle flame's flicker.
    private func flicker(_ flame: SKNode, delay: TimeInterval) {
        guard !Self.reduceMotion else { return }
        let steps = (0..<6).map { _ -> SKAction in
            let duration = Double.random(in: 0.08...0.18)
            return .group([.scaleX(to: CGFloat.random(in: 0.85...1.1), duration: duration),
                           .scaleY(to: CGFloat.random(in: 0.9...1.15), duration: duration),
                           .rotate(toAngle: CGFloat.random(in: -0.1...0.1), duration: duration)])
        }
        flame.run(.sequence([.wait(forDuration: delay), .repeatForever(.sequence(steps))]), withKey: "flicker")
    }

    /// The flames on something leap up for a moment.
    private func leap(_ node: SKNode) {
        for flame in node.children where flame.name == "flame" {
            flame.run(.sequence([.scaleY(to: 1.7, duration: 0.08), .scaleY(to: 1, duration: 0.35)]), withKey: "leap")
        }
    }

    /// Clicked: the lamp's flames leap up and it sends a firework into the sky. Lamps never smash; they're
    /// counted as lit instead.
    func lightUp(_ lamp: PumpkinNode) {
        guard lamp.isLit, lamp.action(forKey: "light-up") == nil else { return }
        // One firework at a time from each lamp.
        lamp.run(.wait(forDuration: 0.45), withKey: "light-up")
        flare(lamp)
        leap(lamp)
        lamp.run(DockSprite.hop(height: pumpkinHeight * 0.05, duration: 0.2), withKey: "hop")
        if Settings.sound { fireworkSound.play() }
        onLightUp?()
        // Up from the flame (the middle one on the tall lamp).
        let spots = DiwaliArt.flameSpots(lamp.kind.look.shape)
        let spot = spots[spots.count / 2]
        let body = PumpkinArt.bodySize(of: lamp.kind, height: lamp.slotHeight)
        let m = lamp.yScale
        let start = CGPoint(x: lamp.position.x + spot.x * body.width * m,
                            y: lamp.position.y + (PumpkinArt.pad + spot.y * body.height) * m + lamp.slotHeight * 0.1 * m)
        riseAndBurst(from: start, toX: start.x + CGFloat.random(in: -0.3...0.3) * pumpkinHeight)
    }

    // MARK: Fireworks

    /// A shell whooshing up from `start` with a trail of sparks, bursting in the sky above the Dock.
    func riseAndBurst(from start: CGPoint, toX x: CGFloat, small: Bool = false, colors: [CGColor]? = nil) {
        let h = pumpkinHeight
        let radius = h * (small ? CGFloat.random(in: 0.26...0.38) : CGFloat.random(in: 0.4...0.56))
        let top = min(dockRect.maxY + h * CGFloat.random(in: 1.25...1.85), size.height - radius - 6)
        let end = CGPoint(x: x, y: max(top, start.y + h * 0.35))
        let s = (h * 0.07).rounded()
        let shell = SKSpriteNode(texture: DiwaliArt.sparkTexture(color: Palette.candlelight, size: s, scale: pixelScale),
                                 size: CGSize(width: s, height: s))
        shell.position = start
        shell.zPosition = 1
        effectsLayer.addChild(shell)
        let picked = colors ?? Array(Self.fireworkColors.shuffled().prefix(2))
        shell.run(.repeatForever(.sequence([
            .run { [weak self, weak shell] in
                guard let self, let shell else { return }
                self.trailSpark(at: shell.position, size: s * 0.7)
            },
            .wait(forDuration: 0.035),
        ])), withKey: "trail")
        let rise = SKAction.move(to: end, duration: small ? 0.75 : 0.6)
        rise.timingMode = .easeOut
        shell.run(.sequence([
            rise,
            .run { [weak self] in self?.fireworkBurst(at: end, radius: radius, colors: picked) },
            .removeFromParent(),
        ]))
    }

    /// A spark left behind by something rising, fading as it falls.
    private func trailSpark(at point: CGPoint, size s: CGFloat) {
        let spark = SKSpriteNode(texture: DiwaliArt.sparkTexture(color: Palette.marigold, size: s, scale: pixelScale),
                                 size: CGSize(width: s, height: s))
        spark.position = CGPoint(x: point.x + CGFloat.random(in: -1.5...1.5), y: point.y)
        spark.zPosition = 0.9
        effectsLayer.addChild(spark)
        spark.run(.sequence([
            .group([.moveBy(x: 0, y: -pumpkinHeight * 0.08, duration: 0.4), .fadeOut(withDuration: 0.4), .scale(to: 0.3, duration: 0.4)]),
            .removeFromParent(),
        ]))
    }

    /// A firework bursting at `center`: a flash, then a ring of streaking sparks that droop and twinkle out.
    func fireworkBurst(at center: CGPoint, radius: CGFloat, colors: [CGColor]) {
        guard !colors.isEmpty else { return }
        let h = pumpkinHeight
        let flashSize = (radius * 1.8).rounded()
        let flash = SKSpriteNode(texture: CozyArt.glowTexture(color: colors[0].mixed(with: Palette.candlelight, 0.4), diameter: flashSize,
                                                              scale: pixelScale),
                                 size: CGSize(width: flashSize, height: flashSize))
        flash.name = "firework"
        flash.blendMode = .add
        flash.position = center
        flash.zPosition = 0.5
        flash.setScale(0.3)
        effectsLayer.addChild(flash)
        flash.run(.sequence([.scale(to: 1.15, duration: 0.18), .fadeOut(withDuration: 0.5), .removeFromParent()]))

        let count = radius > h * 0.4 ? 18 : 14
        let length = (radius * 0.4).rounded()
        let thickness = max(2, (length * 0.22).rounded())
        let offset = CGFloat.random(in: 0...(.pi * 2))
        let dot = (h * 0.06).rounded()
        for i in 0..<count {
            let angle = offset + CGFloat(i) / CGFloat(count) * .pi * 2
            let color = colors[i % colors.count]
            let streak = SKSpriteNode(texture: DiwaliArt.streakTexture(color: color, length: length, scale: pixelScale),
                                      size: CGSize(width: length, height: thickness))
            streak.name = "firework"
            streak.anchorPoint = CGPoint(x: 1, y: 0.5)
            streak.position = center
            streak.zRotation = angle
            streak.zPosition = 1
            streak.setScale(0.2)
            effectsLayer.addChild(streak)
            let r = radius * CGFloat.random(in: 0.85...1.05)
            let out = SKAction.moveBy(x: cos(angle) * r, y: sin(angle) * r, duration: 0.55)
            out.timingMode = .easeOut
            let droop = SKAction.moveBy(x: 0, y: -radius * 0.35, duration: 0.7)
            droop.timingMode = .easeIn
            streak.run(.sequence([
                .group([out, .scale(to: 1, duration: 0.25)]),
                .group([droop, .fadeOut(withDuration: 0.7), .scaleX(to: 0.3, duration: 0.7)]),
                .removeFromParent(),
            ]))

            // Every other one leaves a spark that twinkles as it falls.
            guard i % 2 == 0 else { continue }
            let spark = SKSpriteNode(texture: DiwaliArt.sparkTexture(color: color.mixed(with: Palette.candlelight, 0.3), size: dot, scale: pixelScale),
                                     size: CGSize(width: dot, height: dot))
            spark.position = CGPoint(x: center.x + cos(angle) * r * 0.62, y: center.y + sin(angle) * r * 0.62)
            spark.zPosition = 1.1
            spark.alpha = 0
            effectsLayer.addChild(spark)
            let twinkle = SKAction.sequence([.fadeAlpha(to: 1, duration: 0.08), .fadeAlpha(to: 0.25, duration: 0.12)])
            spark.run(.sequence([
                .wait(forDuration: 0.35),
                .group([.repeat(twinkle, count: 4), .moveBy(x: 0, y: -radius * 0.5, duration: 0.8)]),
                .removeFromParent(),
            ]))
        }
    }

    /// Waits a while, sends a little firework up, and goes again.
    func scheduleNextFirework() {
        run(.sequence([
            .wait(forDuration: Double.random(in: 5...12)),
            .run { [weak self] in
                if Settings.fireworks { self?.fireworkAcross() }
                self?.scheduleNextFirework()
            },
        ]), withKey: "leaves")
    }

    /// A little firework going up from somewhere along the Dock and bursting in the sky.
    func fireworkAcross() {
        guard dockRect.width > 60 else { return }
        let x = CGFloat.random(in: (dockRect.minX + 30)...(dockRect.maxX - 30))
        riseAndBurst(from: CGPoint(x: x, y: dockRect.maxY + pumpkinHeight * 0.75), toX: x + CGFloat.random(in: -20...20), small: true)
    }

    // MARK: The festive extras

    /// The extras' moving parts: the rocket in its bottle, the chakri's wheel, the kandil hanging from its
    /// stand, and the little flames on the rangoli and in the flower bowl.
    func dressDiwali(_ decor: DecorNode) {
        let unit = decorUnit
        let w = decor.size.width, ht = decor.size.height
        switch decor.kind {
        case .rocket:
            let size = DiwaliArt.rocketSize(unit: unit)
            let rocket = SKSpriteNode(texture: DiwaliArt.rocketTexture(unit: unit, scale: pixelScale), size: size)
            rocket.name = "rocket"
            rocket.anchorPoint = CGPoint(x: 0.5, y: 0)
            rocket.position = CGPoint(x: 0, y: (ht * DiwaliArt.rocketFoot).rounded())
            rocket.zPosition = -0.1
            decor.addChild(rocket)
        case .chakri:
            let d = (unit * DiwaliArt.chakriWheel).rounded()
            let wheel = SKSpriteNode(texture: DiwaliArt.chakriTexture(size: d, scale: pixelScale), size: CGSize(width: d, height: d))
            wheel.name = "wheel"
            wheel.position = CGPoint(x: 0, y: ht * DiwaliArt.chakriHub)
            wheel.zPosition = 0.1
            decor.addChild(wheel)
        case .kandil:
            let size = DiwaliArt.kandilSize(unit: unit)
            let kandil = SKSpriteNode(texture: DiwaliArt.kandilTexture(unit: unit, scale: pixelScale), size: size)
            kandil.name = "kandil"
            kandil.anchorPoint = CGPoint(x: 0.5, y: 1)
            kandil.position = CGPoint(x: (DiwaliArt.kandilHook.x - 0.5) * w, y: DiwaliArt.kandilHook.y * ht)
            kandil.zPosition = 0.1
            decor.addChild(kandil)
            // Its window glows.
            let diameter = (unit * 0.9).rounded()
            let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.marigold, diameter: diameter, scale: pixelScale),
                                    size: CGSize(width: diameter, height: diameter))
            glow.name = "glow"
            glow.blendMode = .add
            glow.position = CGPoint(x: 0, y: -size.height * 0.4)
            glow.zPosition = 0.1
            glow.alpha = 0.55
            kandil.addChild(glow)
            guard !Self.reduceMotion else { break }
            let steps = (0..<8).map { _ -> SKAction in
                .fadeAlpha(to: CGFloat.random(in: 0.42...0.62), duration: Double.random(in: 0.12...0.26))
            }
            glow.run(.repeatForever(.sequence(steps)), withKey: "flicker")
            sway(kandil)
        case .rangoli:
            for (i, spot) in DiwaliArt.rangoliFlames(size: decor.size).enumerated() {
                addFlame(to: decor, at: spot, height: (unit * 0.09).rounded(), delay: Double(i) * 0.1)
            }
        case .flowerBowl:
            addFlame(to: decor, at: DiwaliArt.bowlFlame(size: decor.size), height: (unit * 0.09).rounded(), delay: 0)
        default:
            break
        }
    }

    /// The kandil swaying gently on its hook.
    private func sway(_ kandil: SKNode) {
        guard !Self.reduceMotion else { return }
        let sway = SKAction.sequence([.rotate(toAngle: 0.05, duration: 1.5), .rotate(toAngle: -0.05, duration: 1.5)])
        sway.timingMode = .easeInEaseOut
        kandil.run(.repeatForever(sway), withKey: "sway")
    }

    /// A little flame, with a glow, at `spot` (from the middle of `decor`'s bottom edge).
    private func addFlame(to decor: DecorNode, at spot: CGPoint, height: CGFloat, delay: TimeInterval) {
        let size = CGSize(width: (height * 0.6).rounded(), height: height)
        let flame = SKSpriteNode(texture: SpookyArt.flameTexture(size: size, scale: pixelScale), size: size)
        flame.name = "flame"
        flame.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        flame.position = spot
        flame.zPosition = 0.2
        decor.addChild(flame)
        let diameter = (height * 3.2).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.marigold, diameter: diameter, scale: pixelScale),
                                size: CGSize(width: diameter, height: diameter))
        glow.blendMode = .add
        glow.alpha = 0.45
        glow.position = CGPoint(x: spot.x, y: spot.y + height * 0.35)
        glow.zPosition = 0.1
        decor.addChild(glow)
        flicker(flame, delay: delay)
    }

    /// What each festive extra does when clicked.
    func pokeDiwali(_ decor: DecorNode) {
        let h = pumpkinHeight
        let frame = decor.frame
        switch decor.kind {
        case .anar:
            fountain(decor)
        case .rocket:
            launchRocket(decor)
        case .chakri:
            spin(decor)
        case .kandil:
            // It swings on its hook and its window glows brighter.
            guard let kandil = decor.childNode(withName: "kandil") else { break }
            let swing = SKAction.sequence([.rotate(toAngle: 0.3, duration: 0.18), .rotate(toAngle: -0.22, duration: 0.3),
                                           .rotate(toAngle: 0.13, duration: 0.3), .rotate(toAngle: -0.06, duration: 0.3),
                                           .rotate(toAngle: 0, duration: 0.25)])
            swing.timingMode = .easeInEaseOut
            kandil.run(.sequence([swing, .run { [weak self, weak kandil] in
                guard let self, let kandil else { return }
                self.sway(kandil)
            }]), withKey: "sway")
            kandil.childNode(withName: "glow")?.run(.sequence([.group([.scale(to: 1.6, duration: 0.15), .fadeAlpha(to: 0.95, duration: 0.15)]),
                                                              .group([.scale(to: 1, duration: 0.7), .fadeAlpha(to: 0.55, duration: 0.7)])]),
                                                    withKey: "flare")
        case .laddoos:
            sweetsBurst(count: 3, variants: [0], from: CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.6))
            decor.run(DockSprite.hop(height: h * 0.1, duration: 0.25), withKey: "hop")
        case .mithai:
            sweetsBurst(count: 4, variants: [1, 2, 3], from: CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.55))
            decor.run(DockSprite.hop(height: h * 0.08, duration: 0.25), withKey: "hop")
        case .rangoli:
            sparkle(decor)
        case .giftBoxes:
            unwrap(decor)
        case .flowerBowl:
            slosh(decor)
        default:
            decor.run(DockSprite.hop(height: h * 0.12, duration: 0.3), withKey: "hop")
        }
    }

    /// Sweets flying out: laddoos (0), jalebis (1), kaju katli (2) and gulab jamuns (3).
    func sweetsBurst(count: Int, variants: [Int], from center: CGPoint) {
        for i in 0..<count {
            let s = (pumpkinHeight * CGFloat.random(in: 0.13...0.18)).rounded()
            let sweet = SKSpriteNode(texture: DiwaliArt.sweetTexture(variant: variants[i % variants.count], size: s, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            launch(sweet, from: center, spread: 6,
                   velocity: CGVector(dx: CGFloat.random(in: -140...140), dy: CGFloat.random(in: 200...340)),
                   radius: s * 0.3, damping: 0.4, life: 1.3)
        }
    }

    /// Sparks flying from `point`, in any of `colors`.
    private func sparks(count: Int, from point: CGPoint, spread: CGFloat, colors: [CGColor],
                        velocity: () -> CGVector, damping: CGFloat, life: TimeInterval) {
        let s = (pumpkinHeight * 0.055).rounded()
        for i in 0..<count {
            let spark = SKSpriteNode(texture: DiwaliArt.sparkTexture(color: colors[i % colors.count], size: s, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            spark.name = "spark"
            launch(spark, from: point, spread: spread, velocity: velocity(), radius: 1, damping: damping, life: life)
        }
    }

    /// The anar fizzes and throws up a fountain of golden sparks.
    private func fountain(_ anar: DecorNode) {
        guard anar.action(forKey: "fountain") == nil else { return }
        let h = pumpkinHeight
        if Settings.sound { fireworkSound.fizz() }
        let colors = [Palette.candlelight, Palette.marigold, Palette.ghost, Palette.orange]
        anar.run(.repeat(.sequence([
            .run { [weak self, weak anar] in
                guard let self, let anar else { return }
                let frame = anar.frame
                let top = CGPoint(x: frame.minX + frame.width * DiwaliArt.anarTop.x, y: frame.minY + frame.height * DiwaliArt.anarTop.y)
                self.sparks(count: 2, from: top, spread: 1, colors: colors.shuffled(),
                            velocity: { CGVector(dx: CGFloat.random(in: -70...70), dy: CGFloat.random(in: 300...420)) },
                            damping: 0.5, life: 0.6)
            },
            .wait(forDuration: 0.035),
        ]), count: 45), withKey: "fountain")
        anar.run(.repeat(DockSprite.hop(height: h * 0.012, duration: 0.08), count: 10), withKey: "hop")
    }

    /// The rocket shoots up out of its bottle and bursts; another one is in the bottle a moment later.
    private func launchRocket(_ bottle: DecorNode) {
        guard let rocket = bottle.childNode(withName: "rocket") as? SKSpriteNode, bottle.action(forKey: "reload") == nil else { return }
        let h = pumpkinHeight
        let m = bottle.yScale
        let start = CGPoint(x: bottle.position.x, y: bottle.position.y + rocket.position.y * m)
        let flying = SKSpriteNode(texture: rocket.texture, size: CGSize(width: rocket.size.width * m, height: rocket.size.height * m))
        flying.name = "rocket"
        flying.anchorPoint = CGPoint(x: 0.5, y: 0)
        flying.position = start
        flying.zPosition = 0.8
        effectsLayer.addChild(flying)
        rocket.alpha = 0
        if Settings.sound { fireworkSound.play() }

        let radius = h * CGFloat.random(in: 0.45...0.58)
        let top = min(dockRect.maxY + h * CGFloat.random(in: 1.3...1.8), size.height - radius - 6) - flying.size.height
        let drift = CGFloat.random(in: -0.35...0.35) * h
        let end = CGPoint(x: start.x + drift, y: max(top, start.y + h * 0.5))
        flying.zRotation = -atan2(drift, end.y - start.y)
        flying.run(.repeatForever(.sequence([
            .run { [weak self, weak flying] in
                guard let self, let flying else { return }
                self.trailSpark(at: flying.position, size: (h * 0.05).rounded())
            },
            .wait(forDuration: 0.03),
        ])), withKey: "trail")
        let rise = SKAction.move(to: end, duration: 0.7)
        rise.timingMode = .easeOut
        let tip = CGPoint(x: end.x + drift / max(1, end.y - start.y) * flying.size.height, y: end.y + flying.size.height)
        flying.run(.sequence([
            rise,
            .run { [weak self] in
                self?.fireworkBurst(at: tip, radius: radius, colors: Array(PumpkinScene.fireworkColors.shuffled().prefix(3)))
            },
            .removeFromParent(),
        ]))
        bottle.run(DockSprite.hop(height: h * 0.05, duration: 0.2), withKey: "hop")
        bottle.run(.sequence([
            .wait(forDuration: 2.5),
            .run { [weak rocket] in
                guard let rocket else { return }
                rocket.setScale(0.2)
                rocket.alpha = 1
                rocket.run(.scale(to: 1, duration: 0.25))
            },
        ]), withKey: "reload")
    }

    /// The chakri whirls round, throwing off sparks, with a glow behind it.
    private func spin(_ chakri: DecorNode) {
        guard let wheel = chakri.childNode(withName: "wheel"), chakri.action(forKey: "spin") == nil else { return }
        if Settings.sound { fireworkSound.fizz() }
        let whirl = SKAction.rotate(byAngle: -.pi * 2 * 7, duration: 2)
        whirl.timingMode = .easeOut
        wheel.run(whirl, withKey: "whirl")
        let d = (decorUnit * DiwaliArt.chakriWheel).rounded()
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.candlelight, diameter: d * 2, scale: pixelScale),
                                size: CGSize(width: d * 2, height: d * 2))
        glow.blendMode = .add
        glow.position = wheel.position
        glow.zPosition = 0.05
        glow.alpha = 0
        chakri.addChild(glow)
        glow.run(.sequence([.fadeAlpha(to: 0.7, duration: 0.2), .wait(forDuration: 1.3), .fadeOut(withDuration: 0.5), .removeFromParent()]))
        let colors = [Palette.candlelight, Palette.marigold, Palette.ghost, Palette.slime]
        chakri.run(.repeat(.sequence([
            .run { [weak self, weak chakri, weak wheel] in
                guard let self, let chakri, let wheel else { return }
                let m = chakri.yScale
                let center = CGPoint(x: chakri.position.x, y: chakri.position.y + wheel.position.y * m)
                let r = d / 2 * m
                for i in 0..<2 {
                    // Turning clockwise, so the sparks fly off clockwise along the rim.
                    let a = CGFloat.random(in: 0...(.pi * 2))
                    let speed = CGFloat.random(in: 160...260)
                    self.sparks(count: 1, from: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r), spread: 0,
                                colors: [colors[(i + Int.random(in: 0..<4)) % colors.count]],
                                velocity: { CGVector(dx: sin(a) * speed, dy: -cos(a) * speed + 60) }, damping: 1.2, life: 0.45)
                }
            },
            .wait(forDuration: 0.03),
        ]), count: 55), withKey: "spin")
    }

    /// Sparkles twinkle up all over the rangoli and its little flames leap.
    private func sparkle(_ rangoli: DecorNode) {
        guard rangoli.action(forKey: "sparkle") == nil else { return }
        rangoli.run(.wait(forDuration: 0.9), withKey: "sparkle")
        leap(rangoli)
        let w = rangoli.size.width, ht = rangoli.size.height
        let s = (pumpkinHeight * 0.07).rounded()
        let colors = [Palette.ghost, Palette.candlelight, Palette.magenta, Palette.teal, Palette.marigold]
        for i in 0..<14 {
            let a = CGFloat.random(in: 0...(.pi * 2)), d = CGFloat.random(in: 0.1...0.95)
            let spark = SKSpriteNode(texture: DiwaliArt.sparkTexture(color: colors[i % colors.count], size: s, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            spark.name = "spark"
            spark.position = CGPoint(x: cos(a) * d * w * 0.45, y: ht * 0.42 + sin(a) * d * ht * 0.34)
            spark.zPosition = 0.3
            spark.setScale(0)
            rangoli.addChild(spark)
            spark.run(.sequence([
                .wait(forDuration: Double(i) * 0.04),
                .scale(to: 1, duration: 0.14),
                .scale(to: 0.4, duration: 0.14),
                .scale(to: 1, duration: 0.14),
                .group([.scale(to: 0, duration: 0.3), .moveBy(x: 0, y: pumpkinHeight * 0.12, duration: 0.3)]),
                .removeFromParent(),
            ]))
        }
    }

    /// Petals burst out of the gift boxes as they squish, and the diya on top hops.
    private func unwrap(_ boxes: DecorNode) {
        let h = pumpkinHeight
        let frame = boxes.frame
        let top = CGPoint(x: frame.midX, y: frame.maxY - frame.height * 0.1)
        let colors = [Palette.marigold, Palette.magenta, Palette.ghost, Palette.teal, Palette.orange]
        for i in 0..<12 {
            let s = (h * CGFloat.random(in: 0.08...0.12)).rounded()
            let petal = SKSpriteNode(texture: DiwaliArt.petalTexture(color: colors[i % colors.count], size: s, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            launch(petal, from: top, spread: frame.width * 0.3,
                   velocity: CGVector(dx: CGFloat.random(in: -130...130), dy: CGFloat.random(in: 180...300)), radius: s * 0.3, damping: 2.4, life: 1.6)
        }
        boxes.run(.sequence([
            DockSprite.animate(\.popScale, to: 0.9, duration: 0.07),
            DockSprite.animate(\.popScale, to: 1.06, duration: 0.12, curve: .easeOut),
            DockSprite.animate(\.popScale, to: 1, duration: 0.15),
        ]), withKey: "squish")
        // The boxes under slot n have gap -(n + 1).
        let slot = -boxes.gap - 1
        if let lamp = pumpkinLayer.children.first(where: { ($0 as? PumpkinNode)?.slot == slot }) as? PumpkinNode {
            lamp.run(.sequence([.wait(forDuration: 0.05), DockSprite.hop(height: h * 0.25, duration: 0.4)]), withKey: "hop")
            leap(lamp)
        }
    }

    /// The water in the flower bowl sloshes, a few petals bob up, and the floating diya's flame leaps.
    private func slosh(_ bowl: DecorNode) {
        let h = pumpkinHeight
        let frame = bowl.frame
        let colors = [Palette.marigold, Palette.magenta.mixed(with: Palette.candyPink, 0.5), Palette.orange]
        for i in 0..<6 {
            let s = (h * CGFloat.random(in: 0.07...0.1)).rounded()
            let petal = SKSpriteNode(texture: DiwaliArt.petalTexture(color: colors[i % colors.count], size: s, scale: pixelScale),
                                     size: CGSize(width: s, height: s))
            launch(petal, from: CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.65), spread: frame.width * 0.3,
                   velocity: CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: 120...200)), radius: s * 0.3, damping: 1.8, life: 1)
        }
        leap(bowl)
        bowl.run(.sequence([.rotate(toAngle: 0.06, duration: 0.1), .rotate(toAngle: -0.05, duration: 0.16),
                            .rotate(toAngle: 0.025, duration: 0.14), .rotate(toAngle: 0, duration: 0.12)]), withKey: "slosh")
    }

    // MARK: Marigold strings

    /// The corners of the Dock: cobwebs at Halloween, strings of marigolds at Diwali (with the vine).
    func layoutCorners() {
        layoutCobwebs()
        layoutStrands()
    }

    /// Strings of marigolds hanging in both top corners of the Dock at Diwali, swaying a little.
    func layoutStrands() {
        for case let strand as StrandNode in pumpkinLayer.children { strand.removeFromParent() }
        guard Settings.theme == .diwali, Settings.showVines, dockRect.width > 200 else { return }
        // Each hangs from the Dock's top corner over the end of the Dock, the longest string at the outside.
        let height = dockRect.height.rounded()
        let size = CGSize(width: (height * 0.55).rounded(), height: height)
        for left in [true, false] {
            let strand = StrandNode(texture: DiwaliArt.strandTexture(size: size, scale: pixelScale), color: .clear, size: size)
            strand.anchorPoint = CGPoint(x: 0, y: 1)
            strand.restX = left ? dockRect.minX : dockRect.maxX
            strand.restY = dockRect.maxY
            strand.facing = left ? 1 : -1
            strand.zPosition = 0.3
            pumpkinLayer.addChild(strand)
            guard !Self.reduceMotion else { continue }
            let sway = SKAction.sequence([.rotate(toAngle: 0.035, duration: 1.8), .rotate(toAngle: -0.035, duration: 1.8)])
            sway.timingMode = .easeInEaseOut
            strand.run(.sequence([.wait(forDuration: left ? 0 : 0.9), .repeatForever(sway)]), withKey: "sway")
        }
    }

    // MARK: The peacock

    private func makePeacock() -> PeacockNode {
        let unit = (pumpkinHeight * 0.8).rounded()
        let size = DiwaliArt.peacockSize(unit: unit)
        let peacock = PeacockNode(texture: DiwaliArt.peacockTexture(unit: unit, scale: pixelScale), color: .clear, size: size)
        peacock.anchorPoint = CGPoint(x: 0.5, y: 0)
        peacock.restY = dockRect.maxY - 2
        peacock.zPosition = 7
        let train = SKSpriteNode(texture: DiwaliArt.trainTexture(unit: unit, scale: pixelScale), size: size)
        train.name = "train"
        train.anchorPoint = CGPoint(x: 0.5, y: 0)
        train.zPosition = -0.1
        peacock.addChild(train)
        let fan = SKSpriteNode(texture: DiwaliArt.fanTexture(unit: unit, scale: pixelScale), size: DiwaliArt.fanSize(unit: unit))
        fan.name = "fan"
        fan.anchorPoint = CGPoint(x: 0.5, y: DiwaliArt.fanPivot)
        fan.position = CGPoint(x: (DiwaliArt.peacockRump.x - 0.5) * size.width, y: DiwaliArt.peacockRump.y * size.height)
        fan.zPosition = -0.2
        fan.setScale(0.1)
        fan.alpha = 0
        peacock.addChild(fan)
        return peacock
    }

    /// The peacock struts in from one end of the Dock, stops partway to fan out its tail, then walks on
    /// and off the other end.
    func peacockVisit() {
        guard Settings.cozyExtras, Settings.peacock, dockRect.width > 300,
              !pumpkinLayer.children.contains(where: { $0 is PeacockNode }) else {
            scheduleVisitor(first: false)
            return
        }
        let h = pumpkinHeight
        let peacock = makePeacock()
        let fromLeft = Bool.random()
        let startX = fromLeft ? dockRect.minX + h * 0.4 : dockRect.maxX - h * 0.4
        let endX = fromLeft ? dockRect.maxX - h * 0.4 : dockRect.minX + h * 0.4
        let stopX = startX + (endX - startX) * CGFloat.random(in: 0.35...0.65)
        peacock.restX = startX
        peacock.facing = fromLeft ? 1 : -1
        peacock.alpha = 0
        pumpkinLayer.addChild(peacock)
        peacock.run(.sequence([
            .fadeIn(withDuration: 0.3),
            strut(from: startX, to: stopX),
            .wait(forDuration: 0.3),
            .run { [weak self, weak peacock] in
                guard let self, let peacock else { return }
                self.fanOut(peacock)
            },
            .wait(forDuration: 3.2),
            .run { [weak self, weak peacock] in
                guard let self, let peacock else { return }
                self.foldUp(peacock)
            },
            .wait(forDuration: 0.5),
            strut(from: stopX, to: endX),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
            .run { [weak self] in self?.scheduleVisitor(first: false) },
        ]), withKey: "visit")
    }

    /// A stately walk: small steps with a little bob.
    private func strut(from x0: CGFloat, to x1: CGFloat) -> SKAction {
        hops(from: x0, to: x1, hopLength: pumpkinHeight * 0.18, height: pumpkinHeight * 0.025, duration: 0.26)
    }

    /// The peacock fans out its tail, with a shimmering rattle of its feathers.
    private func fanOut(_ peacock: PeacockNode) {
        guard !peacock.isDisplaying, let fan = peacock.childNode(withName: "fan") else { return }
        peacock.isDisplaying = true
        peacock.childNode(withName: "train")?.run(.fadeOut(withDuration: 0.2), withKey: "fade")
        let rattle = SKAction.sequence([.rotate(toAngle: 0.03, duration: 0.05), .rotate(toAngle: -0.03, duration: 0.05)])
        fan.run(.sequence([
            .group([.fadeIn(withDuration: 0.15), .scale(to: 1.06, duration: 0.35)]),
            .scale(to: 1, duration: 0.15),
            .repeat(rattle, count: 6),
            .rotate(toAngle: 0, duration: 0.05),
        ]), withKey: "fan")
        peacock.run(DockSprite.hop(height: pumpkinHeight * 0.04, duration: 0.25), withKey: "hop")
    }

    /// The tail folds back down into a train.
    private func foldUp(_ peacock: PeacockNode) {
        guard peacock.isDisplaying, let fan = peacock.childNode(withName: "fan") else { return }
        peacock.isDisplaying = false
        fan.run(.group([.scale(to: 0.1, duration: 0.3), .fadeOut(withDuration: 0.3), .rotate(toAngle: 0, duration: 0.1)]), withKey: "fan")
        peacock.childNode(withName: "train")?.run(.sequence([.wait(forDuration: 0.15), .fadeIn(withDuration: 0.2)]), withKey: "fade")
    }

    /// The pointer came near: the peacock shows off for a moment.
    func peacockDisplays(_ peacock: PeacockNode) {
        guard !peacock.isFleeing, !peacock.isDisplaying else { return }
        fanOut(peacock)
        peacock.run(.sequence([.wait(forDuration: 2), .run { [weak self, weak peacock] in
            guard let self, let peacock, !peacock.isFleeing else { return }
            self.foldUp(peacock)
        }]), withKey: "display")
    }

    /// Clicked: the peacock fans out its tail in a proud display, then hurries off to the nearer end.
    func peacockFlee(_ peacock: PeacockNode) {
        guard !peacock.isFleeing else { return }
        peacock.isFleeing = true
        peacock.removeAction(forKey: "visit")
        peacock.removeAction(forKey: "display")
        fanOut(peacock)
        let h = pumpkinHeight
        let toLeft = peacock.restX - dockRect.minX < dockRect.maxX - peacock.restX
        let exitX = toLeft ? dockRect.minX + h * 0.3 : dockRect.maxX - h * 0.3
        peacock.run(.sequence([
            .wait(forDuration: 1.1),
            .run { [weak self, weak peacock] in
                guard let self, let peacock else { return }
                self.foldUp(peacock)
                peacock.facing = toLeft ? -1 : 1
            },
            .wait(forDuration: 0.3),
            .run { [weak self, weak peacock] in
                guard let self, let peacock else { return }
                peacock.run(.sequence([
                    self.hops(from: peacock.restX, to: exitX, hopLength: h * 0.3, height: h * 0.05, duration: 0.14),
                    .fadeOut(withDuration: 0.2),
                    .removeFromParent(),
                    .run { [weak self] in self?.scheduleVisitor(first: false) },
                ]), withKey: "visit")
            },
        ]), withKey: "visit")
    }
}
