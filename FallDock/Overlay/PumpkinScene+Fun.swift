import SpriteKit

/// A pumpkin under the pointer while the mouse button is down.
final class Grab {
    weak var pumpkin: PumpkinNode?
    let start: CGPoint
    var isDragging = false
    /// From the pointer to the pumpkin's anchor, so it doesn't jump to the pointer when picked up.
    var offset = CGVector.zero
    /// Recent pointer positions, to work out how fast it's thrown.
    var samples: [(point: CGPoint, time: TimeInterval)] = []

    init(pumpkin: PumpkinNode, start: CGPoint) {
        self.pumpkin = pumpkin
        self.start = start
    }
}

/// The playful bits: tossing pumpkins, combos, golden pumpkins, jack-o'-lanterns, bats,
/// gusts of wind and treats for the squirrel.
extension PumpkinScene {
    var isHolding: Bool { grab != nil }

    func startFunTimers() {
        scheduleGust()
        // Check now and then whether it's time to light (or put out) the jack-o'-lanterns,
        // and send a bat across on Halloween evenings.
        run(.repeatForever(.sequence([
            .wait(forDuration: 60),
            .run { [weak self] in
                guard let self else { return }
                self.updateLanterns(animated: true)
                if Self.isHalloween && Self.isEvening && Int.random(in: 0..<2) == 0 { self.batAcross() }
            },
        ])), withKey: "fun-clock")
    }

    // MARK: Picking up and tossing pumpkins

    func dragGrab(to point: CGPoint) {
        guard let grab, let pumpkin = grab.pumpkin, !pumpkin.isSmashing else {
            grab = nil
            return
        }
        if !grab.isDragging {
            guard hypot(point.x - grab.start.x, point.y - grab.start.y) > 5 else { return }
            grab.isDragging = true
            grab.offset = CGVector(dx: pumpkin.position.x - grab.start.x, dy: pumpkin.position.y - grab.start.y)
            liftUp(pumpkin)
        }
        let now = CACurrentMediaTime()
        grab.samples.append((point, now))
        grab.samples.removeAll { now - $0.time > 0.1 }
        pumpkin.position = CGPoint(x: point.x + grab.offset.dx, y: max(dockRect.maxY - 3, point.y + grab.offset.dy))
        // Lean into the drag.
        let lean = (-throwVelocity(grab).dx * 0.0003).clamped(to: -0.5...0.5)
        pumpkin.zRotation += (lean - pumpkin.zRotation) * 0.35
    }

    func releaseGrab() {
        guard let grab else { return }
        self.grab = nil
        guard let pumpkin = grab.pumpkin, !pumpkin.isSmashing else { return }
        guard grab.isDragging else {
            smash(pumpkin)
            return
        }
        var velocity = throwVelocity(grab)
        let speed = hypot(velocity.dx, velocity.dy)
        if speed > 2400 {
            velocity = CGVector(dx: velocity.dx * 2400 / speed, dy: velocity.dy * 2400 / speed)
        }
        if speed > 900 { sounds.play(.whoosh, volume: 0.35) }
        pumpkin.isHeld = false
        pumpkin.isFlying = true
        pumpkin.velocity = velocity
        pumpkin.run(.scale(to: abs(pumpkin.yScale) / 1.12, duration: 0.15))
    }

    private func throwVelocity(_ grab: Grab) -> CGVector {
        guard let first = grab.samples.first, let last = grab.samples.last, last.time - first.time > 0.008 else { return .zero }
        let dt = CGFloat(last.time - first.time)
        return CGVector(dx: (last.point.x - first.point.x) / dt, dy: (last.point.y - first.point.y) / dt)
    }

    /// Picks a pumpkin up off the Dock: it stops wobbling, comes to the front and grows a little.
    private func liftUp(_ pumpkin: PumpkinNode) {
        pumpkin.isHeld = true
        pumpkin.isDetached = true
        for key in ["wobble", "hover", "hop", "rock", "grow", "move", "home"] { pumpkin.removeAction(forKey: key) }
        if hovered === pumpkin { setHovered(nil) }
        pumpkin.zPosition = 15
        pumpkin.run(.scale(to: abs(pumpkin.yScale) * 1.12, duration: 0.1))
        sounds.play(.pop, volume: 0.6)
    }

    /// Moves tossed pumpkins along: gravity, bounces off the Dock and the window's edges, knocking
    /// into other pumpkins, splatting if they land hard, and falling off past the ends of the Dock.
    func updateFlights(dt: CGFloat) {
        // If the button came up somewhere we didn't hear about, let go.
        if let grab, grab.isDragging, NSEvent.pressedMouseButtons & 1 == 0 { releaseGrab() }
        guard dt > 0 else { return }
        let floor = dockRect.maxY - 3
        for case let pumpkin as PumpkinNode in pumpkinLayer.children where pumpkin.isFlying && !pumpkin.isSmashing {
            var v = pumpkin.velocity
            var p = pumpkin.position
            v.dy -= 2200 * dt
            p.x += v.dx * dt
            p.y += v.dy * dt
            pumpkin.zRotation -= v.dx * 0.004 * dt
            let half = pumpkin.size.width * abs(pumpkin.xScale) / 2
            let height = pumpkin.size.height * abs(pumpkin.yScale)

            // The window's sides and top.
            if p.x < half || p.x > size.width - half {
                p.x = p.x.clamped(to: half...(size.width - half))
                v.dx = -v.dx * 0.5
                sounds.play(.bounce, volume: 0.5)
            }
            if p.y + height > size.height {
                p.y = size.height - height
                v.dy = -abs(v.dy) * 0.3
            }

            // Knock into another pumpkin hard enough and it splats.
            let speed = hypot(v.dx, v.dy)
            if speed > 450 {
                let flyer = CGRect(x: p.x - half * 0.8, y: p.y, width: half * 1.6, height: height * 0.8)
                if let other = pumpkins.values.first(where: { other in
                    other !== pumpkin && !other.isDetached && !other.isSmashing
                        && other.frame.insetBy(dx: other.frame.width * 0.2, dy: other.frame.height * 0.2).intersects(flyer)
                }) {
                    smash(other)
                    v.dx *= -0.35
                    v.dy = abs(v.dy) * 0.35 + 140
                }
            }

            // The Dock is the floor. Past its ends there's nothing to land on.
            let overDock = p.x > dockRect.minX && p.x < dockRect.maxX
            if overDock && p.y <= floor && v.dy < 0 {
                p.y = floor
                pumpkin.position = p
                if -v.dy > 820 || speed > 1500 {
                    smash(pumpkin)
                    continue
                }
                if -v.dy < 170 {
                    land(pumpkin)
                    continue
                }
                sounds.play(.bounce, volume: Float(min(1, -v.dy / 700)))
                v.dy = -v.dy * 0.42
                v.dx *= 0.72
            } else if !overDock && p.y < -height {
                lose(pumpkin)
                continue
            }
            pumpkin.position = p
            pumpkin.velocity = v
        }
    }

    /// A tossed pumpkin has come to rest: it rights itself and hops back to its spot.
    private func land(_ pumpkin: PumpkinNode) {
        pumpkin.isFlying = false
        pumpkin.velocity = .zero
        sounds.play(.bounce, volume: 0.3)
        let slot = pumpkin.slot
        guard slot < pumpkinCount, pumpkins[slot] === pumpkin else {
            retire(pumpkin)
            return
        }
        // Take over placing it again, starting from where it landed.
        pumpkin.restX = pumpkin.position.x
        pumpkin.restY = dockRect.maxY - 3
        pumpkin.perch = 0
        pumpkin.bounce = 0
        pumpkin.popScale = 1
        pumpkin.hoverScale = 1
        pumpkin.isDetached = false
        let h = pumpkinHeight
        let homeY = restingY(slot: slot)
        pumpkin.run(.rotate(toAngle: 0, duration: 0.25))
        pumpkin.run(.sequence([
            .wait(forDuration: 0.3),
            hops(from: pumpkin.restX, to: slotX[slot], hopLength: h * 0.5, height: h * 0.18, duration: 0.24),
            .group([
                DockSprite.animate(\.restY, to: homeY, duration: 0.3),
                DockSprite.animate(\.perch, to: slotPerch[slot], duration: 0.3),
                DockSprite.hop(height: h * 0.2, duration: 0.3),
            ]),
            .run { [weak self, weak pumpkin] in
                guard let self, let pumpkin else { return }
                pumpkin.zPosition = pumpkin.homeZ
                self.startWobble(pumpkin)
            },
        ]), withKey: "home")
    }

    // MARK: Combos and finds

    /// After a smash: combo words for quick smashes, a shower of sparkles for a golden pumpkin,
    /// and a bat out of a jack-o'-lantern.
    func celebrate(_ pumpkin: PumpkinNode) {
        let now = CACurrentMediaTime()
        streak = now - streak.time < 1.4 ? (streak.count + 1, now) : (1, now)
        let height = pumpkin.size.height * abs(pumpkin.yScale)
        let top = CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + height + 8)
        if pumpkin.isGolden {
            sounds.play(.chime)
            showLabel("Golden!", at: top, color: Palette.mustard.mixed(with: Palette.peach, 0.3))
            sparkleBurst(from: CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + height * 0.4))
        } else if streak.count >= 2 {
            let words = ["Double smash!", "Triple!", "Pumpkin party!", "Unstoppable!"]
            showLabel(words[min(streak.count - 2, words.count - 1)], at: top)
        }
        if pumpkin.isLantern {
            releaseBat(from: CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + height * 0.5))
        }
    }

    /// Bouncy words that pop up, float away and fade.
    func showLabel(_ text: String, at point: CGPoint, color: CGColor = Palette.orange) {
        let (texture, labelSize) = FunArt.labelTexture(text, pointSize: 20, color: color, scale: pixelScale)
        let label = SKSpriteNode(texture: texture, size: labelSize)
        let halfWidth = labelSize.width / 2 + 4
        label.position = CGPoint(x: point.x.clamped(to: halfWidth...max(halfWidth, size.width - halfWidth)),
                                 y: min(point.y, size.height - labelSize.height))
        label.zPosition = 30
        label.zRotation = CGFloat.random(in: -0.08...0.08)
        label.setScale(0.3)
        effectsLayer.addChild(label)
        let pop = SKAction.scale(to: 1.15, duration: 0.14)
        pop.timingMode = .easeOut
        let rise = SKAction.moveBy(x: 0, y: 34, duration: 1.2)
        rise.timingMode = .easeOut
        label.run(.sequence([
            pop,
            .scale(to: 1, duration: 0.1),
            .group([rise, .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.5)])]),
            .removeFromParent(),
        ]))
    }

    // MARK: Golden pumpkins

    /// A soft golden glow and sparkles that keep twinkling over the pumpkin.
    func addSparkles(to pumpkin: PumpkinNode) {
        let w = pumpkin.size.width, h = pumpkin.size.height
        let glow = SKSpriteNode(texture: CozyArt.glowTexture(color: Palette.mustard, diameter: (w * 1.5).rounded(), scale: pixelScale),
                                size: CGSize(width: (w * 1.5).rounded(), height: (w * 1.5).rounded()))
        glow.blendMode = .add
        glow.position = CGPoint(x: 0, y: h * 0.45)
        glow.zPosition = -0.4
        glow.alpha = 0.35
        let breathe = SKAction.sequence([.fadeAlpha(to: 0.55, duration: 1.1), .fadeAlpha(to: 0.3, duration: 1.1)])
        breathe.timingMode = .easeInEaseOut
        glow.run(.repeatForever(breathe))
        pumpkin.addChild(glow)

        pumpkin.run(.repeatForever(.sequence([
            .wait(forDuration: 0.35, withRange: 0.3),
            .run { [weak self, weak pumpkin] in
                guard let self, let pumpkin else { return }
                let s = (h * CGFloat.random(in: 0.12...0.22)).rounded()
                let sparkle = SKSpriteNode(texture: FunArt.sparkleTexture(size: s, scale: self.pixelScale), size: CGSize(width: s, height: s))
                sparkle.blendMode = .add
                sparkle.position = CGPoint(x: CGFloat.random(in: -w * 0.38...w * 0.38), y: h * CGFloat.random(in: 0.15...0.85))
                sparkle.zPosition = 0.3
                sparkle.setScale(0)
                pumpkin.addChild(sparkle)
                sparkle.run(.sequence([
                    .group([.scale(to: 1, duration: 0.25), .rotate(byAngle: 0.6, duration: 0.6)]),
                    .scale(to: 0, duration: 0.35),
                    .removeFromParent(),
                ]))
            },
        ])), withKey: "sparkle")
    }

    private func sparkleBurst(from center: CGPoint) {
        for _ in 0..<16 {
            let s = (pumpkinHeight * CGFloat.random(in: 0.12...0.24)).rounded()
            let sparkle = SKSpriteNode(texture: FunArt.sparkleTexture(size: s, scale: pixelScale), size: CGSize(width: s, height: s))
            sparkle.blendMode = .add
            launch(sparkle, from: center, spread: 6,
                   velocity: CGVector(dx: CGFloat.random(in: -260...260), dy: CGFloat.random(in: 200...460)),
                   radius: s * 0.3, damping: 1.2, life: 1.3)
        }
    }

    // MARK: Jack-o'-lanterns

    static var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 6
    }

    static var isHalloween: Bool {
        let date = Calendar.current.dateComponents([.month, .day], from: Date())
        return (date.month == 10 && (date.day ?? 0) >= 24) || (date.month == 11 && date.day == 1)
    }

    var lanternsLit: Bool {
        switch Settings.jackOLanterns {
        case .always: return true
        case .never: return false
        case .evenings: return Self.isEvening || Self.isHalloween
        }
    }

    /// About two in five carvable pumpkins become jack-o'-lanterns, the same ones each time.
    func wantsLantern(slot: Int, kind: PumpkinKind) -> Bool {
        kind.isCarvable && kind != .golden && (slot * 7 + Int(harvestSeed % 5)) % 5 < 2
    }

    /// Lights or puts out jack-o'-lanterns to match the setting and the time of day,
    /// one after another so it looks like someone going down the row.
    func updateLanterns(animated: Bool) {
        let lit = lanternsLit
        var delay: TimeInterval = 0
        for slot in pumpkins.keys.sorted() {
            guard let pumpkin = pumpkins[slot], !pumpkin.isSmashing else { continue }
            let wanted = lit && wantsLantern(slot: slot, kind: pumpkin.kind)
            guard wanted != pumpkin.isLantern else { continue }
            if !animated {
                wanted ? carve(pumpkin, animated: false) : uncarve(pumpkin)
                continue
            }
            run(.sequence([.wait(forDuration: delay), .run { [weak self, weak pumpkin] in
                guard let self, let pumpkin, !pumpkin.isSmashing else { return }
                wanted ? self.carve(pumpkin, animated: true) : self.uncarve(pumpkin)
            }]))
            delay += 0.3
        }
    }

    /// Carves a face into a pumpkin and lights a candle inside.
    func carve(_ pumpkin: PumpkinNode, animated: Bool) {
        guard !pumpkin.isLantern else { return }
        pumpkin.isLantern = true
        let face = SKSpriteNode(texture: FunArt.faceTexture(kind: pumpkin.kind, height: pumpkin.slotHeight,
                                                            face: (pumpkin.slot + pumpkin.variant) % FunArt.faceCount,
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
        let flicker = (0..<8).map { _ -> SKAction in
            let duration = Double.random(in: 0.08...0.2)
            return .group([.fadeAlpha(to: CGFloat.random(in: 0.3...0.5), duration: duration),
                           .scale(to: CGFloat.random(in: 0.94...1.05), duration: duration)])
        }
        pumpkin.addChild(glow)

        if animated {
            face.alpha = 0
            glow.alpha = 0
            face.run(.fadeIn(withDuration: 0.5))
            glow.run(.sequence([.fadeAlpha(to: 0.45, duration: 0.6), .repeatForever(.sequence(flicker))]), withKey: "flicker")
            sounds.play(.pop, volume: 0.4)
            // A few curls of pumpkin flesh from the carving.
            let center = CGPoint(x: pumpkin.position.x, y: pumpkin.position.y + pumpkin.size.height * 0.5)
            for i in 0..<4 {
                let s = (pumpkinHeight * 0.1).rounded()
                let bit = SKSpriteNode(texture: PumpkinArt.shardTexture(kind: pumpkin.kind, size: s, variant: i, scale: pixelScale),
                                       size: CGSize(width: s, height: s))
                launch(bit, from: center, spread: pumpkin.size.width * 0.2,
                       velocity: CGVector(dx: CGFloat.random(in: -90...90), dy: CGFloat.random(in: 80...200)),
                       radius: s * 0.3, damping: 0.4, life: 0.8)
            }
        } else {
            glow.alpha = 0.4
            glow.run(.repeatForever(.sequence(flicker)), withKey: "flicker")
        }
    }

    func uncarve(_ pumpkin: PumpkinNode) {
        guard pumpkin.isLantern else { return }
        pumpkin.isLantern = false
        for name in ["face", "candle"] {
            pumpkin.childNode(withName: name)?.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        }
    }

    /// The candle flares up when the pointer comes near, as if the jack-o'-lantern noticed.
    func flare(_ pumpkin: PumpkinNode) {
        guard pumpkin.isLantern, let glow = pumpkin.childNode(withName: "candle") else { return }
        glow.run(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeAlpha(to: 0.8, duration: 0.12)]),
                            .group([.scale(to: 1, duration: 0.5), .fadeAlpha(to: 0.42, duration: 0.5)])]), withKey: "flare")
    }

    // MARK: Bats

    /// A bat that flutters up out of a smashed jack-o'-lantern and away.
    func releaseBat(from point: CGPoint) {
        let bat = makeBat()
        bat.position = point
        bat.setScale(0.5)
        let side: CGFloat = Bool.random() ? 1 : -1
        let path = CGMutablePath()
        path.move(to: point)
        path.addCurve(to: CGPoint(x: point.x + side * 90, y: point.y + 120),
                      control1: CGPoint(x: point.x - side * 40, y: point.y + 60),
                      control2: CGPoint(x: point.x + side * 20, y: point.y + 140))
        path.addCurve(to: CGPoint(x: point.x + side * 260, y: size.height + 60),
                      control1: CGPoint(x: point.x + side * 160, y: point.y + 100),
                      control2: CGPoint(x: point.x + side * 180, y: size.height - 40))
        effectsLayer.addChild(bat)
        bat.run(.sequence([
            .group([.follow(path, asOffset: false, orientToPath: false, duration: 2.4), .scale(to: 1, duration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    /// A bat flying across the top of the Dock (Halloween evenings).
    func batAcross() {
        let bat = makeBat()
        let leftToRight = Bool.random()
        let y = dockRect.maxY + pumpkinHeight * CGFloat.random(in: 1.4...2.8)
        let start = CGPoint(x: leftToRight ? -40 : size.width + 40, y: y)
        let end = CGPoint(x: leftToRight ? size.width + 40 : -40, y: y + CGFloat.random(in: -30...60))
        let path = CGMutablePath()
        path.move(to: start)
        let third = (end.x - start.x) / 3
        path.addCurve(to: CGPoint(x: start.x + third * 1.5, y: y + 30), control1: CGPoint(x: start.x + third * 0.5, y: y - 40),
                      control2: CGPoint(x: start.x + third, y: y + 60))
        path.addCurve(to: end, control1: CGPoint(x: start.x + third * 2, y: y - 20), control2: CGPoint(x: start.x + third * 2.5, y: end.y + 50))
        bat.position = start
        effectsLayer.addChild(bat)
        bat.run(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: 6), .removeFromParent()]))
    }

    private func makeBat() -> SKSpriteNode {
        let h = pumpkinHeight
        let frames = [FunArt.batTexture(frame: 0, unit: h, scale: pixelScale), FunArt.batTexture(frame: 1, unit: h, scale: pixelScale)]
        let bat = SKSpriteNode(texture: frames[0], size: FunArt.batSize(unit: h))
        bat.zPosition = 25
        bat.run(.repeatForever(.animate(with: frames, timePerFrame: 0.09)))
        return bat
    }

    // MARK: Gusts of wind

    func scheduleGust() {
        removeAction(forKey: "gust")
        run(.sequence([.wait(forDuration: Double.random(in: 50...110)), .run { [weak self] in self?.gust() }]), withKey: "gust")
    }

    /// Now and then a gust blows a handful of leaves along the Dock, and everything sways as it passes.
    func gust() {
        defer { scheduleGust() }
        guard Settings.fallingLeaves, dockRect.width > 0, grab == nil else { return }
        let h = pumpkinHeight
        let direction: CGFloat = Bool.random() ? 1 : -1
        let speed: CGFloat = 520
        sounds.play(.whoosh, volume: 0.5)

        for i in 0..<8 {
            let s = (h * CGFloat.random(in: 0.2...0.28)).rounded()
            let kind = LeafKind.fallers.randomElement() ?? .oak
            let leaf = SKSpriteNode(texture: LeafArt.texture(kind, size: s, variant: i, scale: pixelScale), size: CGSize(width: s, height: s))
            let lead = CGFloat(i) * CGFloat.random(in: 30...90)
            let startX = direction > 0 ? dockRect.minX - 40 - lead : dockRect.maxX + 40 + lead
            leaf.position = CGPoint(x: startX, y: dockRect.maxY + h * CGFloat.random(in: 0.15...1.8))
            leaf.zPosition = 22
            leaf.alpha = 0
            effectsLayer.addChild(leaf)
            let distance = dockRect.width + 120 + lead
            let duration = Double(distance / speed) * Double.random(in: 0.85...1.2)
            let bob = SKAction.sequence([.moveBy(x: 0, y: CGFloat.random(in: 12...26), duration: 0.45),
                                         .moveBy(x: 0, y: -CGFloat.random(in: 12...26), duration: 0.45)])
            bob.timingMode = .easeInEaseOut
            leaf.run(.repeatForever(bob))
            leaf.run(.repeatForever(.rotate(byAngle: -direction * CGFloat.random(in: 3...6), duration: 1)))
            leaf.run(.sequence([
                .group([.moveBy(x: direction * distance, y: 0, duration: duration),
                        .sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: duration - 0.8), .fadeOut(withDuration: 0.5)])]),
                .removeFromParent(),
            ]))
        }

        // Everything sways as the gust reaches it.
        for case let sprite as DockSprite in pumpkinLayer.children where !sprite.isDetached {
            let reach = direction > 0 ? sprite.position.x - dockRect.minX : dockRect.maxX - sprite.position.x
            run(.sequence([.wait(forDuration: Double(max(0, reach) / speed)), .run { [weak self, weak sprite] in
                guard let self, let sprite, !sprite.isDetached else { return }
                self.rock(sprite, toward: direction, strength: 0.8)
                if let pile = sprite as? DecorNode, pile.kind == .leafPile, !pile.isScattered {
                    self.flutterLeaves(count: 2, from: CGPoint(x: pile.position.x, y: pile.position.y + pile.frame.height * 0.6),
                                       size: (h * 0.22).rounded(), upward: 80...160)
                }
            }]))
        }
    }

    // MARK: Treats for the squirrel

    /// Clicking the acorns knocks one out onto the Dock, and calls the squirrel over to fetch it.
    func dropTreat(from decor: DecorNode) {
        guard Settings.cozyExtras, !pumpkinLayer.children.contains(where: { $0 is TreatNode }) else { return }
        let h = pumpkinHeight
        let s = (h * 0.26).rounded()
        let treat = TreatNode(texture: FunArt.acornTexture(size: s, scale: pixelScale), color: .clear, size: CGSize(width: (s * 0.9).rounded(), height: s))
        treat.anchorPoint = CGPoint(x: 0.5, y: 0)
        treat.restX = decor.restX
        treat.restY = dockRect.maxY - 2
        treat.zPosition = 6.5
        pumpkinLayer.addChild(treat)
        place(treat)
        // Out toward the middle of the Dock, where there's room.
        let side: CGFloat = decor.restX < dockRect.midX ? 1 : -1
        let landing = decor.restX + side * (decor.size.width * 0.5 + s * 0.7)
        sounds.play(.pop, volume: 0.5)
        treat.run(.group([DockSprite.animate(\.restX, to: landing, duration: 0.45, curve: .linear),
                          DockSprite.hop(height: h * 0.35, duration: 0.45)]))
        // If nobody comes for it, it rolls away after a while.
        treat.run(.sequence([.wait(forDuration: 30), .fadeOut(withDuration: 0.6), .removeFromParent()]), withKey: "expire")
        run(.sequence([.wait(forDuration: 0.6), .run { [weak self, weak treat] in
            guard let self, let treat, treat.parent != nil else { return }
            self.squirrelVisit(treat: treat)
        }]))
    }

    /// The squirrel picks up the acorn and holds it while it nibbles.
    func pickUp(_ treat: TreatNode, by squirrel: SquirrelNode) {
        guard treat.parent != nil else { return }
        treat.removeAllActions()
        treat.removeFromParent()
        let held = SKSpriteNode(texture: treat.texture, size: CGSize(width: treat.size.width * 0.8, height: treat.size.height * 0.8))
        held.anchorPoint = CGPoint(x: 0.5, y: 0.3)
        held.position = CGPoint(x: squirrel.size.width * 0.32, y: squirrel.size.height * 0.4)
        held.zPosition = 0.1
        squirrel.addChild(held)
        sounds.play(.pop, volume: 0.5)
        showLabel("Yum!", at: CGPoint(x: squirrel.position.x, y: squirrel.position.y + squirrel.size.height + 6),
                  color: Palette.mustard)
    }
}
