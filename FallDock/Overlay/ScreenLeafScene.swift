import SpriteKit

/// Leaves drifting down across the whole screen the Dock is on, for Fill the whole screen.
/// Scene coordinates match the screen: (0, 0) is its bottom-left corner.
@MainActor
final class ScreenLeafScene: SKScene {
    private var pixelScale: CGFloat = 2
    /// The Dock's top edge. Leaves fade out as they reach it, as if settling behind it.
    private var dockTop: CGFloat = 0

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Starts the leaves falling, or keeps them going after the Dock moved.
    func start(dockTop: CGFloat, pixelScale: CGFloat) {
        self.dockTop = dockTop
        if pixelScale != self.pixelScale {
            self.pixelScale = pixelScale
            removeAllChildren()
        }
        guard !PumpkinScene.reduceMotion, action(forKey: "leaves") == nil else { return }
        // A few leaves already on their way down, so the screen doesn't start out empty.
        for _ in 0..<max(1, Int(4 * Settings.leafRate)) {
            dropLeaf(head: CGFloat.random(in: 0...0.7))
        }
        scheduleNextLeaf()
    }

    /// Stops the leaves and clears them away (the window has faded out).
    func stop() {
        removeAllActions()
        removeAllChildren()
    }

    /// The Amount setting changed: start counting toward the next leaf at the new pace.
    func amountChanged() {
        guard action(forKey: "leaves") != nil else { return }
        scheduleNextLeaf()
    }

    private func scheduleNextLeaf() {
        let rate = Settings.leafRate
        run(.sequence([
            .wait(forDuration: Double.random(in: 0.6...2.6) / rate),
            .run { [weak self] in
                self?.dropLeaf()
                self?.scheduleNextLeaf()
            },
        ]), withKey: "leaves")
    }

    /// Lets a leaf go above the top edge. `head` starts it that far down its fall already (0 to 1).
    private func dropLeaf(head: CGFloat = 0) {
        guard size.width > 0, children.count < max(4, Int((16 * Settings.leafRate).rounded())) else { return }

        // Nearer leaves are bigger, quicker and brighter; farther ones small, slow and faint.
        let depth = CGFloat.random(in: 0...1)
        let s = (18 + 16 * depth).rounded()
        let speed = 30 + 40 * depth
        let kind = LeafKind.fallers.randomElement() ?? .oak
        let leaf = SKSpriteNode(texture: LeafArt.texture(kind, size: s, variant: Int.random(in: 0..<4), scale: pixelScale),
                                size: CGSize(width: s, height: s))
        leaf.zPosition = depth
        leaf.zRotation = CGFloat.random(in: 0...(.pi * 2))

        let topY = size.height + s
        let landY = dockTop + CGFloat.random(in: -10...40)
        let startY = topY - (topY - landY) * head
        leaf.position = CGPoint(x: CGFloat.random(in: -20...(size.width + 20)), y: startY)
        leaf.alpha = head > 0 ? 0 : 0.7 + 0.3 * depth
        addChild(leaf)

        let fallTime = Double(max(1, startY - landY) / speed)
        let sway = CGFloat.random(in: 16...44)
        let swayTime = Double.random(in: 1.4...2.4)
        let swayRight = SKAction.moveBy(x: sway, y: 0, duration: swayTime)
        let swayLeft = SKAction.moveBy(x: -sway, y: 0, duration: swayTime)
        swayRight.timingMode = .easeInEaseOut
        swayLeft.timingMode = .easeInEaseOut
        leaf.run(.repeatForever(.sequence([swayRight, swayLeft])))
        leaf.run(.repeatForever(.rotate(byAngle: CGFloat.random(in: -1.2...1.2), duration: swayTime)))
        // A light breeze carries it a little sideways on the way down.
        leaf.run(.moveBy(x: CGFloat.random(in: -80...80), y: startY > landY ? landY - startY : 0, duration: fallTime))

        let fade = min(1.6, fallTime * 0.5)
        leaf.run(.sequence([
            head > 0 ? .fadeAlpha(to: 0.7 + 0.3 * depth, duration: 0.8) : .wait(forDuration: 0),
            .wait(forDuration: max(0, fallTime - fade - (head > 0 ? 0.8 : 0))),
            .fadeOut(withDuration: fade),
            .removeFromParent(),
        ]))
    }
}
