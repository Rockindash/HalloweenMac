import AppKit
import OSLog
import SpriteKit

private let log = Logger(subsystem: "com.amol.dockorate", category: "overlay")

/// A borderless, see-through panel that floats just above the Dock on every desktop.
final class OverlayPanel: NSPanel {
    /// One level above the Dock, so pumpkins draw on top of it.
    static let aboveDock = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
    /// Above every normal window but just below the Dock, so screen-wide leaves settle behind it.
    static let belowDock = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) - 1)

    init(frame: CGRect, level: NSWindow.Level = OverlayPanel.aboveDock) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        self.level = level
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
    /// How much room above the Dock the window covers, for flying chunks and falling leaves.
    private let headroom: CGFloat = 240

    private var panel: OverlayPanel?
    private var skView: ClickThroughSKView?
    private var scene: PumpkinScene?
    private var currentDock: DockInfo?

    // Fill the whole screen: a second, click-through window of falling leaves over the Dock's screen.
    private var leafPanel: OverlayPanel?
    private var leafView: SKView?
    private var leafScene: ScreenLeafScene?
    private var isHidingLeaves = false

    private var timer: Timer?
    private var hoverTimer: Timer?
    private var dockWatchTimer: Timer?
    private var spaceSwitchTimer: Timer?
    private var healthTimer: Timer?
    private var hauntTimer: Timer?
    private var haunting = HauntingClock()
    private var spiritLedger = SpiritLedger()
    /// The apps open now that have a Dock icon, by `SpiritLedger.key(for:)`, with their icons. Noted
    /// while they run, since a quit app may no longer say what it was.
    private var dockApps: [String: NSImage] = [:]
    private var hauntTicks = 0
    /// The scene's frame count at the last health check, while the harvest was showing.
    private var lastFrameCount: Int?
    private var lastRebuild: TimeInterval = 0
    /// The Mac woke or the screen unlocked: show the harvest afresh once the Dock is back.
    private var reshowPending = false
    /// The last health check found the harvest not showing properly and showed it afresh.
    private var reshownForHealth = false
    /// While the screens slide to another space, the harvest stays hidden until this time (or until
    /// macOS reports the new space, whichever comes first).
    private var switchingSpacesUntil: TimeInterval = 0
    private var lastDockState: DockLocator.DockState = .unknown
    private var lastDockCheck: TimeInterval = 0
    /// A Dock stack (like Downloads) is open: the whole harvest tucks away behind the Dock
    /// until it closes, so the stack's items can be seen and picked.
    private var isStackOpen = false
    /// The tile that opened the stack, when it was spotted from the click (without Accessibility).
    private var clickedStack: CGRect?
    private var lastClickTime: TimeInterval = 0
    private var lastStackCheck: TimeInterval = 0
    /// Mission Control (or App Exposé) is showing. It adds screen-sized Dock windows of its own, so the
    /// Dock isn't re-measured until it closes. (It also takes every click, so pumpkins can't be smashed
    /// meanwhile; the harvest still follows the pointer.)
    private var isMissionControlShowing = false
    private var lastMissionControlCheck: TimeInterval = 0
    /// When the pointer was last over the Dock. With magnification on, the Dock measures wider while
    /// the pointer is on it and for a moment after it leaves (while the icons shrink back), so the
    /// harvest isn't re-laid out from a measurement taken then.
    private var lastPointerOnDock: TimeInterval = 0
    /// Where the Dock was last seen, to put the harvest back on it when Mission Control shows it.
    private var lastDock: DockInfo?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var isHiding = false
    /// A setting changed and the harvest hasn't regrown with it yet.
    private var needsRegrow = false
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    var onSmash: (() -> Void)?

    /// Without an activated license the harvest stays off the Dock.
    var isLicensed = false {
        didSet { if isLicensed != oldValue { refresh(force: true) } }
    }

    /// While paused (for presentations or screen sharing) the pumpkins stay hidden.
    private(set) var pausedUntil: Date?
    private var resumeTimer: Timer?
    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    /// Hides the pumpkins for `duration` seconds, or brings them back when it's nil.
    func pause(for duration: TimeInterval?) {
        resumeTimer?.invalidate()
        resumeTimer = nil
        pausedUntil = duration.map { Date().addingTimeInterval($0) }
        if let duration {
            resumeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.pausedUntil = nil
                    self?.onResume?()
                    self?.refresh()
                }
            }
        }
        refresh()
    }

    /// Called when a pause runs out by itself.
    var onResume: (() -> Void)?

    /// Called after the Mac switches between Light and Dark and the art has been redrawn.
    var onAppearanceChange: (() -> Void)?
    private var appearanceObservation: NSKeyValueObservation?

    /// Uses the light or dark colors to match the Mac, and redraws everything when that changes.
    private func followAppearance() {
        Palette.appearance = .system
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                let appearance = Palette.Appearance.system
                guard appearance != Palette.appearance else { return }
                Palette.appearance = appearance
                ArtCache.clear()
                self?.scene?.repaint()
                self?.onAppearanceChange?()
            }
        }
    }
    var isDockPrecise: Bool { currentDock?.isPrecise ?? false }

    /// What the app window's Dock tab shows.
    struct Status {
        var isShowing: Bool
        /// The Dock's length in points, while it's showing.
        var length: CGFloat?
        var isPrecise: Bool
        var pumpkins: Int
        var extras: Int
    }

    var status: Status {
        Status(isShowing: panel?.isVisible == true && !isHiding, length: currentDock?.dockFrame.width,
               isPrecise: currentDock?.isPrecise ?? false, pumpkins: scene?.pumpkinCount ?? 0, extras: scene?.gapKinds.count ?? 0)
    }

    func start() {
        followAppearance()
        // Switching spaces or apps (say, to a full-screen app) doesn't slide the Dock away; it just
        // isn't there. So the harvest goes at once too, rather than sliding.
        let onChange: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                // The slide to another space is over (if one was under way): show again if the Dock is here.
                self?.switchingSpacesUntil = 0
                self?.refresh(animated: false)
            }
        }
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            (center, center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: onChange)),
            (workspace, workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: onChange)),
            // Spirits of quit apps.
            (workspace, workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor in self?.appQuit(note) }
            }),
            (workspace, workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
                Task { @MainActor in self?.appLaunched(note) }
            }),
            // Reduce Motion turned on or off: grow the harvest again with or without the movement.
            (workspace, workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil,
                                              queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh(force: true) }
            }),
        ]

        // Safety net: Dock settings changes (size, position, auto-hide) don't always send a notification.
        // Only needed while the pumpkins are showing; watchDock notices the Dock coming back.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel?.isVisible == true, !self.isHiding, !self.isMissionControlShowing else { return }
                self.refresh()
            }
        }
        timer?.tolerance = 0.5

        // After a sleep or a screen lock, show the harvest afresh, just as the Dock hiding and coming
        // back does: macOS can leave the overlay off screen, or the harvest slid away, without saying so.
        let awake: @Sendable (Notification) -> Void = { [weak self] note in
            Task { @MainActor in self?.scheduleReshow(note.name.rawValue) }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append((workspace, workspace.addObserver(forName: name, object: nil, queue: .main, using: awake)))
        }
        let distributed = DistributedNotificationCenter.default()
        observers.append((distributed, distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil,
                                                                 queue: .main, using: awake)))

        // After the displays sleep, wake or reconnect, SpriteKit can stop drawing for good: the harvest
        // freezes (nothing reacts or follows the Dock's magnification) or stays slid away after a hide,
        // since sliding back is an animation too. While it should be showing, check that frames keep
        // coming, and rebuild the overlay if they've stopped.
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHealth() }
        }
        healthTimer?.tolerance = 1

        // Haunting while you're away: check now and then how long the Mac has been left alone.
        hauntTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkHaunting() }
        }
        hauntTimer?.tolerance = 0.3

        // The Dock slides away in full-screen apps (and with auto-hide), so check often
        // whether it's on screen (watchDock decides how often it's worth it).
        dockWatchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchDock() }
        }
        dockWatchTimer?.tolerance = 0.03

        // Sliding to another space (say, a full-screen app) would carry the harvest along over it until
        // macOS reports the change at the end, so watch for the slide itself while the harvest shows.
        spaceSwitchTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchSpaceSwitch() }
        }
        spaceSwitchTimer?.tolerance = 0.01

        // Watching the pointer needs no special permission (only key presses do).
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        // Clicks elsewhere tell us when a Dock stack opens or closes (no permission needed).
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            let point = NSEvent.mouseLocation
            let isLeft = event.type == .leftMouseDown
            Task { @MainActor in self?.handleClick(at: point, isLeft: isLeft) }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.isStackOpen else { return }
                self.lastClickTime = ProcessInfo.processInfo.systemUptime
                if DockLocator.isStackOpen() == nil { self.setStackOpen(false) }
            }
            return event
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseExited]) { [weak self] event in
            Task { @MainActor in self?.updateHover() }
            return event
        }

        refresh()
    }

    /// The screens started sliding to another space: hide the harvest at once, before it can ride along.
    private func watchSpaceSwitch() {
        guard panel?.isVisible == true, !isHiding, !isMissionControlShowing, let dock = currentDock,
              DockLocator.isSwitchingSpaces(on: dock.screenFrame) else { return }
        switchingSpacesUntil = ProcessInfo.processInfo.systemUptime + 1.5
        hide(animated: false)
    }

    /// Re-measures the Dock and moves, shows or hides the overlay.
    func refresh(force: Bool = false, animated: Bool = true) {
        // A change made while the harvest is hidden (the Dock slid away, paused, switched off) is
        // remembered, so the harvest regrows with it as soon as it shows again.
        if force { needsRegrow = true }
        // Mission Control's own screen-sized Dock windows would throw the measurement off;
        // watchDock re-measures as soon as it closes.
        if DockLocator.isMissionControlShowing() {
            setMissionControlShowing(true)
            return
        }
        lastDockState = DockLocator.dockScreen()
        let switchingSpaces = ProcessInfo.processInfo.systemUptime < switchingSpacesUntil
        guard isLicensed, Settings.showPumpkins, !isPaused, !switchingSpaces, let dock = DockLocator.locate() else {
            hide(animated: animated)
            return
        }
        // A magnified Dock measures wider than it really is; keep the harvest as it is and measure
        // again once the icons have settled (the safety-net timer does).
        if !needsRegrow, panel?.isVisible == true, !isHiding, let current = currentDock,
           dock.screenFrame == current.screenFrame, dock != current, isDockMagnified(current) {
            return
        }
        if needsRegrow || dock != currentDock || panel?.isVisible != true || isHiding {
            show(on: dock, force: needsRegrow)
            needsRegrow = false
        }
    }

    /// Whether the Dock may be magnified right now: the pointer is on it (magnified icons stand up to
    /// twice as tall, so the area above it counts too), or left it less than a second ago.
    private func isDockMagnified(_ dock: DockInfo) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let area = dock.dockFrame.insetBy(dx: -dock.dockFrame.height, dy: 0)
        let reach = CGRect(x: area.minX, y: dock.screenFrame.minY,
                           width: area.width, height: dock.dockFrame.maxY - dock.screenFrame.minY + dock.dockFrame.height * 1.5)
        if reach.contains(NSEvent.mouseLocation) { lastPointerOnDock = now }
        return now - lastPointerOnDock < 1.0
    }

    /// Hides the pumpkins as soon as the Dock goes away, brings them back with it,
    /// and follows it when it moves to another display.
    private func watchDock() {
        guard isLicensed, Settings.showPumpkins, !isPaused else { return }
        // A hidden Dock only comes back when the pointer reaches the bottom of a screen (or the
        // desktop changes, which sends its own notification), and a Dock showing over a full-screen
        // app goes away when the pointer leaves it. So check often while the pointer is near the
        // bottom of a screen, and only about once a second otherwise, to save battery.
        let now = ProcessInfo.processInfo.systemUptime
        let mouse = NSEvent.mouseLocation
        let nearBottom = NSScreen.screens.contains { $0.frame.contains(mouse) && mouse.y - $0.frame.minY < 250 }
        // Stacks open from a click or the keyboard and close the same ways, so keep watching:
        // closely while the pointer is near the Dock, while one is open and just after a click,
        // and a few times a second otherwise (it only asks about the Dock's folder tiles).
        if nearBottom, let dock = currentDock { _ = isDockMagnified(dock) }
        let watchClosely = nearBottom || isStackOpen || now - lastClickTime < 1.5
        if panel?.isVisible == true, watchClosely || now - lastStackCheck >= 0.25 {
            lastStackCheck = now
            if let open = DockLocator.isStackOpen() { setStackOpen(open) }
        }
        // Mission Control brings the Dock up even over a full-screen app (where the harvest is
        // hidden), so watch for it whether the harvest is showing or not.
        if now - lastMissionControlCheck >= 0.15 {
            lastMissionControlCheck = now
            setMissionControlShowing(DockLocator.isMissionControlShowing())
        }
        // Mission Control adds screen-sized windows of its own, so don't re-measure the Dock until it's gone.
        guard !isMissionControlShowing else { return }
        guard nearBottom || now - lastDockCheck >= 1 else { return }
        lastDockCheck = now
        // Also retry while the Dock shows but the harvest doesn't: measuring it can fail for a
        // moment (right after it moves to another display), and nothing else would try again.
        let state = DockLocator.dockScreen()
        let missing: Bool
        if case .showing = state { missing = panel?.isVisible != true || isHiding } else { missing = false }
        if state != lastDockState || missing {
            refresh()
        }
    }

    /// A click anywhere. With Accessibility, watchDock reads whether a stack opened; without it,
    /// a click on a stack tile opens it (or closes it, if it's the open one), and any other click
    /// closes an open stack, picking an item or not.
    private func handleClick(at point: CGPoint, isLeft: Bool) {
        lastClickTime = ProcessInfo.processInfo.systemUptime
        guard DockLocator.isStackOpen() == nil else { return }
        let tile = isLeft ? currentDock.flatMap { DockLocator.stackTile(at: point, dock: $0) } : nil
        if let tile, clickedStack.map({ !$0.intersects(tile.insetBy(dx: 4, dy: 0)) }) ?? true {
            clickedStack = tile
        } else {
            clickedStack = nil
        }
        setStackOpen(clickedStack != nil)
    }

    /// Tucks the harvest away while a Dock stack is open, and brings it back when it closes.
    private func setStackOpen(_ open: Bool) {
        if !open { clickedStack = nil }
        guard open != isStackOpen else { return }
        isStackOpen = open
        updateStackState()
    }

    /// Re-measures the Dock once Mission Control closes.
    private func setMissionControlShowing(_ showing: Bool) {
        guard showing != isMissionControlShowing else { return }
        isMissionControlShowing = showing
        if showing {
            // Mission Control always shows the Dock, even when it was hidden (in a full-screen app
            // or with auto-hide), and it stays where it was, so bring the harvest up on it there.
            if panel?.isVisible != true || isHiding, isLicensed, Settings.showPumpkins, !isPaused,
               let dock = lastDock ?? DockLocator.locate(inMissionControl: true) {
                show(on: dock, force: false)
            }
        } else {
            // Back to a desktop or a full-screen app: the Dock may be gone again.
            refresh(animated: false)
        }
    }

    private func updateStackState() {
        // While the Dock is away the harvest stays slid off screen; it comes back up when the Dock does.
        if panel?.isVisible == true, !isHiding {
            scene?.setTuck(isStackOpen ? .behindDock : .none)
        }
        updateHover()
    }

    private func show(on dock: DockInfo, force: Bool) {
        currentDock = dock
        lastDock = dock
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
            scene.isOnDock = true
            scene.onSmash = { [weak self] in
                self?.onSmash?()
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
            // Slide up alongside the Dock (updateStackState below starts it rising).
            isHiding = false
            if !panel.isVisible { scene.setTuck(.offScreen, animated: false) }
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            log.debug("Showing the harvest on the Dock")
        }
        updateScreenLeaves()
        updateStackState()
    }

    /// The theme changed: the old harvest fades away as the new one grows in, left to right.
    func changeTheme() {
        // Only while it's showing: a hidden harvest just comes back in the new theme.
        scene?.crossfadeNextHarvest = panel?.isVisible == true && !isHiding
        refresh(force: true)
    }

    /// Falling leaves settings changed: the pace applies right away, without regrowing the harvest.
    func updateLeaves() {
        scene?.leafAmountChanged()
        leafScene?.amountChanged()
        updateScreenLeaves()
    }

    /// Shows the screen-wide leaves while the harvest is showing and the setting is on, and hides them otherwise.
    private func updateScreenLeaves() {
        // Leaves fall across the screen in fall only.
        guard Settings.theme == .fall, Settings.leavesFillScreen, Settings.fallingLeaves, !PumpkinScene.reduceMotion,
              let dock = currentDock, panel?.isVisible == true, !isHiding else {
            hideScreenLeaves()
            return
        }
        let frame = dock.screenFrame
        if leafPanel == nil {
            let panel = OverlayPanel(frame: frame, level: OverlayPanel.belowDock)
            let view = SKView(frame: CGRect(origin: .zero, size: frame.size))
            view.allowsTransparency = true
            // Slow, gentle movement looks smooth at a modest frame rate, which keeps the battery happy.
            view.preferredFramesPerSecond = 30
            view.ignoresSiblingOrder = true
            view.autoresizingMask = [.width, .height]
            let scene = ScreenLeafScene(size: frame.size)
            view.presentScene(scene)
            panel.contentView = view
            leafPanel = panel
            leafView = view
            leafScene = scene
        }
        guard let leafPanel, let leafScene else { return }
        if leafPanel.frame != frame {
            leafPanel.setFrame(frame, display: false)
            leafScene.size = frame.size
        }
        let scale = NSScreen.screens.first(where: { $0.frame == frame })?.backingScaleFactor ?? 2
        leafScene.start(dockTop: dock.dockFrame.maxY - frame.minY, pixelScale: scale)
        leafView?.isPaused = false
        if !leafPanel.isVisible || isHidingLeaves {
            isHidingLeaves = false
            if !leafPanel.isVisible { leafPanel.alphaValue = 0 }
            leafPanel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                leafPanel.animator().alphaValue = 1
            }
        }
    }

    private func hideScreenLeaves(animated: Bool = true) {
        guard let leafPanel, leafPanel.isVisible else { return }
        if isHidingLeaves, animated { return }
        isHidingLeaves = true
        let finish = { [weak self] in
            guard let self, self.isHidingLeaves else { return }
            self.isHidingLeaves = false
            self.leafView?.isPaused = true
            self.leafScene?.stop()
            self.leafPanel?.orderOut(nil)
        }
        guard animated else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            leafPanel.animator().alphaValue = 0
        }, completionHandler: { Task { @MainActor in finish() } })
    }

    private func hide(animated: Bool = true) {
        currentDock = nil
        hideScreenLeaves(animated: animated)
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard let panel, panel.isVisible else { return }
        // A slide already under way finishes on its own, unless this hide is meant to be instant.
        if isHiding, animated { return }
        panel.ignoresMouseEvents = true
        isHiding = true
        log.debug("Hiding the harvest (animated: \(animated, privacy: .public))")
        // Slide down off the screen as the Dock slides away, then stop drawing.
        scene?.setTuck(.offScreen, animated: animated)
        let finish: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self, self.isHiding else { return }
            self.isHiding = false
            self.skView?.isPaused = true
            self.panel?.orderOut(nil)
        }
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { MainActor.assumeIsolated { finish() } }
        } else {
            finish()
        }
    }

    /// Haunting while you're away: the ghosts gather once the Mac has been left alone for a while at
    /// Halloween, and scatter the moment anyone's back.
    func checkHaunting() {
        // Every few seconds, note where the Dock's app icons are, for the spirits of quit apps.
        hauntTicks &+= 1
        if hauntTicks % 3 == 0, spiritsAllowed { noteDockApps() }
        let allowed = Settings.haunting && Settings.theme == .halloween && isLicensed && !isPaused
            && panel?.isVisible == true && !isHiding && !isMissionControlShowing
        let change = haunting.update(idle: HauntingClock.secondsSinceInput(), now: ProcessInfo.processInfo.systemUptime, allowed: allowed)
        switch change {
        case .gather?:
            log.debug("Nobody's at the Mac: haunting the Dock")
            scene?.haunt()
        case .scatter?:
            scene?.unhaunt()
        case nil:
            // A fresh harvest (the Dock changed, say) clears the ghosts away; bring them straight back.
            if haunting.isHaunting, scene?.isHaunted == false { scene?.haunt(animated: false) }
        }
    }

    // MARK: Spirits of quit apps

    private var spiritsAllowed: Bool {
        Settings.spirits && Settings.theme == .halloween && isLicensed && !isPaused && panel?.isVisible == true && !isHiding
    }

    /// Notes the open apps with Dock icons, and where their icons are: exactly, from the Dock itself
    /// with Accessibility allowed, or else worked out from the Dock's settings and the open apps.
    private func noteDockApps() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleURL != nil }
        for app in apps {
            let key = SpiritLedger.key(for: app.bundleURL!)
            if dockApps[key] == nil { dockApps[key] = app.icon ?? NSWorkspace.shared.icon(forFile: app.bundleURL!.path) }
        }
        // The worked-out spots first, then the exact ones over them wherever the Dock gives them.
        if let dock = currentDock {
            let settings = UserDefaults(suiteName: "com.apple.dock")
            let kept = (settings?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []).compactMap { entry in
                (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
            }
            let guesses = SpiritLedger.estimatedIconX(kept: kept, open: apps.compactMap(\.bundleIdentifier), dockFrame: dock.dockFrame,
                                                      tileSize: CGFloat(settings?.double(forKey: "tilesize") ?? 0))
            var xs: [String: CGFloat] = [:]
            for app in apps {
                if let id = app.bundleIdentifier, let x = guesses[id] { xs[SpiritLedger.key(for: app.bundleURL!)] = x }
            }
            spiritLedger.noteIconX(xs)
        }
        spiritLedger.noteIcons(DockLocator.appIconFrames())
    }

    /// The app a launch or quit notification is about, if it has (or had) a Dock icon and isn't Dockorate.
    private func dockApp(in note: Notification) -> (key: String, icon: NSImage)? {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier, let url = app.bundleURL else { return nil }
        let key = SpiritLedger.key(for: url)
        // A quit app can report no activation policy any more, so one noted while it ran counts too.
        guard app.activationPolicy == .regular || dockApps[key] != nil else {
            log.debug("Spirits: \(url.lastPathComponent, privacy: .public) has no Dock icon")
            return nil
        }
        let icon = dockApps[key] ?? app.icon ?? NSWorkspace.shared.icon(forFile: url.path)
        return (key, icon)
    }

    /// The icon's middle across the scene, from its middle across the screen.
    private func sceneX(_ screenX: CGFloat?) -> CGFloat? {
        guard let screenX, let panel else { return nil }
        return screenX - panel.frame.minX
    }

    /// An app quit: its spirit rises out of where its icon was.
    private func appQuit(_ note: Notification) {
        guard let app = dockApp(in: note) else { return }
        dockApps[app.key] = nil
        let x = spiritLedger.quit(app.key, now: ProcessInfo.processInfo.systemUptime)
        guard spiritsAllowed else {
            log.debug("Spirits: an app quit, but spirits can't show now")
            return
        }
        log.info("Spirits: an app quit; its spirit rises (icon spot known: \(x != nil, privacy: .public))")
        scene?.releaseSpirit(icon: app.icon, key: app.key, atSceneX: sceneX(x))
    }

    /// An app opened: if its spirit left a little while ago, it swoops back in once the app's icon is in the Dock.
    private func appLaunched(_ note: Notification) {
        guard let app = dockApp(in: note) else { return }
        dockApps[app.key] = app.icon
        let returning = spiritLedger.launched(app.key, now: ProcessInfo.processInfo.systemUptime)
        // Note where its icon is once it's in the Dock, even if it quits again before the next check.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self, self.spiritsAllowed else { return }
            self.noteDockApps()
            guard returning else { return }
            log.info("Spirits: an app came back; its spirit returns")
            self.scene?.returnSpirit(icon: app.icon, key: app.key, toSceneX: self.sceneX(self.spiritLedger.iconX[app.key]))
        }
    }

    /// Try It: haunt the Dock as soon as the Mac is left alone for a moment.
    func tryHaunting() {
        haunting.tryIt(now: ProcessInfo.processInfo.systemUptime)
    }

    /// Tells the scene where the pointer is, and lets clicks through everywhere except right on top
    /// of a pumpkin or something else that reacts to a click.
    private func updateHover() {
        // The pointer moving is someone back at the Mac: scatter the ghosts without waiting.
        if haunting.isHaunting { checkHaunting() }
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
        let wantsClicks = target != nil
        if panel.ignoresMouseEvents == wantsClicks {
            panel.ignoresMouseEvents = !wantsClicks
        }
        if wantsClicks {
            NSCursor.pointingHand.set()
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

    private func scheduleReshow(_ reason: String) {
        log.info("\(reason, privacy: .public): showing the harvest afresh shortly")
        reshowPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { MainActor.assumeIsolated { self.reshowIfPending() } }
    }

    /// Once the screen is unlocked and the Dock's display is awake, hides the harvest and shows it again
    /// from scratch, as the Dock hiding and coming back would. Until then, the health check tries again.
    private func reshowIfPending() {
        guard reshowPending, !Self.isScreenLocked, !isMissionControlShowing else { return }
        if let dock = currentDock ?? lastDock, Self.isDisplayAsleep(under: dock.screenFrame) { return }
        reshowPending = false
        reshow("after waking or unlocking")
    }

    private func reshow(_ reason: String) {
        log.info("Showing the harvest afresh: \(reason, privacy: .public)")
        DockLocator.resetCaches()
        lastDockState = .unknown
        switchingSpacesUntil = 0
        hide(animated: false)
        refresh(animated: true)
    }

    /// While the harvest should be showing, checks that it really is: SpriteKit is still drawing, the
    /// window is on screen where it was put, and the harvest isn't stuck slid away. If not, it's shown
    /// afresh, and if that didn't help by the next check, the overlay is rebuilt.
    private func checkHealth() {
        reshowIfPending()
        guard let panel, let scene, let skView, panel.isVisible, !isHiding, !skView.isPaused,
              let dock = currentDock, !isMissionControlShowing, !isStackOpen,
              ProcessInfo.processInfo.systemUptime >= switchingSpacesUntil,
              !Self.isDisplayAsleep(under: dock.screenFrame), !Self.isScreenLocked else {
            lastFrameCount = nil
            reshownForHealth = false
            return
        }
        defer { lastFrameCount = scene.frameCount }
        let framesStopped = lastFrameCount.map { scene.frameCount == $0 } ?? false
        let offScreen = !Self.isOnScreen(panel)
        let stuckAway = scene.isStuckAway
        guard framesStopped || offScreen || stuckAway else {
            reshownForHealth = false
            return
        }
        let problem = framesStopped ? "frames stopped" : offScreen ? "window off screen" : "harvest stuck away"
        guard reshownForHealth else {
            reshownForHealth = true
            lastFrameCount = nil
            reshow(problem)
            return
        }
        // At most once a minute, in case something a rebuild can't fix is wrong.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRebuild > 60 else { return }
        lastRebuild = now
        reshownForHealth = false
        log.error("Rebuilding the overlay: \(problem, privacy: .public)")
        rebuild()
    }

    /// Whether the window server has the panel on screen, where AppKit thinks it is.
    private static func isOnScreen(_ panel: NSPanel) -> Bool {
        guard let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(panel.windowNumber))
                            as? [[String: Any]])?.first else { return false }
        guard (info[kCGWindowIsOnscreen as String] as? Bool) == true,
              let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { return false }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let frame = CGRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
        return abs(frame.minX - panel.frame.minX) < 2 && abs(frame.minY - panel.frame.minY) < 2
            && abs(frame.width - panel.frame.width) < 2 && abs(frame.height - panel.frame.height) < 2
    }

    /// Throws away the overlay's windows and SpriteKit views and grows a fresh harvest in new ones.
    private func rebuild() {
        lastFrameCount = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        isHiding = false
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
        skView = nil
        scene = nil
        isHidingLeaves = false
        leafPanel?.orderOut(nil)
        leafPanel?.contentView = nil
        leafPanel?.close()
        leafPanel = nil
        leafView = nil
        leafScene = nil
        currentDock = nil
        refresh(force: true, animated: false)
    }

    private static var isScreenLocked: Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private static func isDisplayAsleep(under frame: CGRect) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame == frame }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return false }
        return CGDisplayIsAsleep(CGDirectDisplayID(number.uint32Value)) != 0
    }


    func stop() {
        timer?.invalidate()
        healthTimer?.invalidate()
        hauntTimer?.invalidate()
        dockWatchTimer?.invalidate()
        spaceSwitchTimer?.invalidate()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        hide()
    }
}
