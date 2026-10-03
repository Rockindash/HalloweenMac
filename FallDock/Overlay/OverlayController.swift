import AppKit
import SpriteKit

/// A borderless, see-through panel that floats just above the Dock on every desktop.
final class OverlayPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // One level above the Dock, so pumpkins draw on top of it.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// An SKView that reacts to the very first click, even though our app is never "active".
final class ClickThroughSKView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Keeps the overlay window lined up with the Dock and decides when clicks
/// should reach the pumpkins (only while the pointer is over one).
@MainActor
final class OverlayController {
    /// How much room above the Dock the window covers, for tossed pumpkins, flying chunks,
    /// bats and falling leaves.
    private let headroom: CGFloat = 420

    private var panel: OverlayPanel?
    private var skView: ClickThroughSKView?
    private var scene: PumpkinScene?
    private var currentDock: DockInfo?

    private var timer: Timer?
    private var hoverTimer: Timer?
    private var dockWatchTimer: Timer?
    private var lastDockState: DockLocator.DockState = .unknown
    private var isHiding = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    /// Called after every smash; `true` for a golden pumpkin.
    var onSmash: ((Bool) -> Void)?
    var isDockPrecise: Bool { currentDock?.isPrecise ?? false }

    func start() {
        let onChange: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            (center, center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: onChange)),
        ]

        // Safety net: Dock settings changes (size, position, auto-hide) don't always send a notification.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 0.5

        // The Dock slides away in full-screen apps (and with auto-hide), so check often
        // whether it's on screen. This check is cheap; the full re-measure above is not.
        dockWatchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchDock() }
        }
        dockWatchTimer?.tolerance = 0.03

        // Watching the pointer needs no special permission (only key presses do).
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseExited, .leftMouseUp]) { [weak self] event in
            Task { @MainActor in self?.updateHover() }
            return event
        }

        refresh()
    }

    /// Re-measures the Dock and moves, shows or hides the overlay.
    func refresh(force: Bool = false) {
        lastDockState = DockLocator.dockScreen()
        guard Settings.showPumpkins, let dock = DockLocator.locate() else {
            hide()
            return
        }
        if force || dock != currentDock || panel?.isVisible != true || isHiding {
            show(on: dock, force: force)
        }
    }

    /// Hides the pumpkins as soon as the Dock goes away, brings them back with it,
    /// and follows it when it moves to another display.
    private func watchDock() {
        guard Settings.showPumpkins else { return }
        if DockLocator.dockScreen() != lastDockState {
            refresh()
        }
    }

    private func show(on dock: DockInfo, force: Bool) {
        currentDock = dock
        let screen = dock.screenFrame
        let frame = CGRect(x: screen.minX, y: screen.minY,
                           width: screen.width, height: dock.dockFrame.maxY - screen.minY + headroom)

        if panel == nil {
            let panel = OverlayPanel(frame: frame)
            let view = ClickThroughSKView(frame: CGRect(origin: .zero, size: frame.size))
            view.allowsTransparency = true
            view.preferredFramesPerSecond = 30
            view.ignoresSiblingOrder = true
            view.autoresizingMask = [.width, .height]
            let scene = PumpkinScene(size: frame.size)
            scene.onSmash = { [weak self] golden in
                self?.onSmash?(golden)
                self?.updateHover()
            }
            view.presentScene(scene)
            panel.contentView = view
            self.panel = panel
            self.skView = view
            self.scene = scene
        }

        guard let panel, let scene else { return }
        panel.setFrame(frame, display: false)
        scene.size = frame.size

        let localDock = dock.dockFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
        let scale = NSScreen.screens.first(where: { $0.frame == screen })?.backingScaleFactor ?? 2
        // A forced refresh (a menu change) grows a fresh harvest.
        scene.configure(dockRect: localDock, pixelScale: scale, magnifier: DockMagnifier.current(), regrow: force)
        skView?.isPaused = false
        if !panel.isVisible || isHiding {
            // Fade in alongside the Dock.
            isHiding = false
            if !panel.isVisible { panel.alphaValue = 0 }
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hide() {
        currentDock = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard let panel, panel.isVisible, !isHiding else { return }
        panel.ignoresMouseEvents = true
        isHiding = true
        // Fade out as the Dock slides away, then stop drawing.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.isHiding else { return }
                self.isHiding = false
                self.skView?.isPaused = true
                self.panel?.orderOut(nil)
            }
        })
    }

    /// Tells the scene where the pointer is, and lets clicks through everywhere except right on top
    /// of a pumpkin or something else that reacts to a click.
    private func updateHover() {
        guard let panel, let scene, panel.isVisible, !isHiding else {
            hoverTimer?.invalidate()
            hoverTimer = nil
            return
        }
        let mouse = NSEvent.mouseLocation
        let point = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        scene.pointerMoved(to: point)
        let target = scene.target(at: point)
        scene.setHovered(target)
        // Keep the clicks while a pumpkin is being dragged, even when the pointer runs ahead of it.
        let wantsClicks = target != nil || scene.isHolding
        if panel.ignoresMouseEvents == wantsClicks {
            panel.ignoresMouseEvents = !wantsClicks
        }
        if wantsClicks {
            (scene.isHolding ? NSCursor.closedHand : target is PumpkinNode ? NSCursor.openHand : NSCursor.pointingHand).set()
            // While we're catching clicks, the whole window would block the screen below it,
            // so keep checking quickly until the pointer leaves it.
            if hoverTimer == nil {
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.updateHover() }
                }
            }
        } else {
            hoverTimer?.invalidate()
            hoverTimer = nil
        }
    }

    /// Carves or uncarves jack-o'-lanterns after the menu setting changes.
    func refreshLanterns() {
        scene?.updateLanterns(animated: true)
    }

    func stop() {
        timer?.invalidate()
        dockWatchTimer?.invalidate()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        hide()
    }
}
