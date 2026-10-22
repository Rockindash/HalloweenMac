import AppKit
import ApplicationServices

/// Where the Dock is right now, in global screen coordinates (origin bottom-left of the main display).
struct DockInfo: Equatable {
    var screenFrame: CGRect
    /// The Dock's icon area. `maxY` is the top edge pumpkins sit on.
    var dockFrame: CGRect
    var isPrecise: Bool
}

/// Finds the Dock without touching it. macOS doesn't let apps draw inside the Dock,
/// so we work out where it is and float a see-through window just above it.
enum DockLocator {
    /// Smallest gap at the bottom of a screen that we treat as a visible Dock.
    /// An auto-hidden Dock leaves only a few points.
    private static let minimumDockThickness: CGFloat = 20
    /// How far the Dock's list of icons (as Accessibility reports it) reaches above the top of its glass.
    private static let accessibilityTopInset: CGFloat = 5

    /// Returns the Dock while it's showing at the bottom of a screen, or nil when it has slid
    /// away (full-screen apps, auto-hide) or sits on the left or right edge. In Mission Control the
    /// Dock shows even over a full-screen app, so `inMissionControl` skips that check.
    static func locate(inMissionControl: Bool = false) -> DockInfo? {
        let screens = NSScreen.screens
        let screen: NSScreen
        switch dockScreen(inMissionControl: inMissionControl) {
        case .showing(let frame):
            // The Dock follows the pointer between displays, so use the screen it's on now.
            guard let match = screens.first(where: { $0.frame.intersects(frame.insetBy(dx: 2, dy: 2)) }) else { return nil }
            screen = match
        case .hidden:
            return nil
        case .unknown:
            // Older macOS: fall back to the screen that reserves space for the Dock.
            guard let match = screens.first(where: { $0.visibleFrame.minY - $0.frame.minY >= minimumDockThickness }) else { return nil }
            screen = match
        }

        // The Dock's top edge. The screen it's on reports the space it takes up, which is exact. But
        // after the Dock changes size or moves to another display, that screen can report nothing
        // for a while, and the screen it left keeps the old figure. Accessibility measures the Dock
        // itself (its list of icons reaches a few points above the glass), so use that next, then
        // the largest gap any screen reports, then the Dock's icon size.
        let frame = screen.frame
        let precise = accessibilityDockFrame().flatMap { frame.intersects($0) ? $0 : nil }
        let ownGap = screen.visibleFrame.minY - frame.minY
        var thickness: CGFloat
        if ownGap >= minimumDockThickness {
            thickness = ownGap
        } else if let precise, precise.maxY - frame.minY - accessibilityTopInset >= minimumDockThickness {
            thickness = precise.maxY - frame.minY - accessibilityTopInset
        } else {
            thickness = screens.map { $0.visibleFrame.minY - $0.frame.minY }.max() ?? 0
        }
        if thickness < minimumDockThickness {
            let dock = UserDefaults(suiteName: "com.apple.dock")
            let orientation = dock?.string(forKey: "orientation") ?? "bottom"
            guard orientation == "bottom" else { return nil } // Dock on the left or right
            let tile = CGFloat(dock?.double(forKey: "tilesize") ?? 0)
            thickness = (tile > 0 ? tile : 48) + 22
        }

        if let precise {
            // The measured width, and the top edge worked out above.
            let rect = CGRect(x: precise.minX, y: frame.minY, width: precise.width, height: thickness)
            return DockInfo(screenFrame: frame, dockFrame: rect, isPrecise: true)
        }

        let width = min(frame.width - 16, estimatedDockWidth(thickness: thickness))
        let rect = CGRect(x: frame.midX - width / 2, y: frame.minY, width: width, height: thickness)
        return DockInfo(screenFrame: frame, dockFrame: rect, isPrecise: false)
    }

    // MARK: Is the Dock showing right now, and on which screen?

    enum DockState: Equatable {
        /// Showing on the screen with this frame (AppKit coordinates).
        case showing(CGRect)
        case hidden
        /// This macOS version doesn't give us the signal.
        case unknown
    }

    private static var dockWindowSupported: Bool?

    /// Forgets what was learned about the Dock and the screens, after a sleep or a screen lock.
    static func resetCaches() {
        dockWindowSupported = nil
        cachedDockPID = nil
        homeScreens.removeAll()
    }
    private static var cachedDockPID: pid_t?

    /// The Dock's process. Looking it up is slow and this runs often, so remember it until the
    /// Dock restarts (when the old process is gone).
    private static func dockPID() -> pid_t? {
        if let pid = cachedDockPID, kill(pid, 0) == 0 { return pid }
        cachedDockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        return cachedDockPID
    }

    /// The Dock keeps a screen-sized window at Dock level that is on screen only while the Dock
    /// can be seen, and it moves to whichever display the Dock is on. In a full-screen app (or
    /// with auto-hide) the Dock slides away and that window goes off screen. Window positions
    /// and owners are readable without Screen Recording permission.
    static func dockScreen(inMissionControl: Bool = false) -> DockState {
        guard let dockPID = dockPID() else { return .unknown }
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        let screenSizes = NSScreen.screens.map { $0.frame.size }

        // Mission Control and Dock menus briefly add other Dock windows, so only count
        // a Dock-level window that is exactly the size of a screen.
        func dockWindows(_ options: CGWindowListOption) -> [CGRect] {
            guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
            return windows.compactMap { window in
                guard (window[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) == dockPID,
                      (window[kCGWindowLayer as String] as? Int) == dockLevel,
                      let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                      let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                      screenSizes.contains(where: { abs($0.width - bounds.width) < 1 && abs($0.height - bounds.height) < 1 })
                else { return nil }
                return bounds
            }
        }

        if dockWindowSupported == nil {
            dockWindowSupported = !dockWindows([.optionAll]).isEmpty
        }
        guard dockWindowSupported == true else { return .unknown }

        guard let bounds = dockWindows([.optionOnScreenOnly]).first else { return .hidden }
        let screen = flipped(bounds)

        // In a full-screen app the Dock only shows while the pointer is on it, but macOS takes
        // a second or two to report it gone. Hide the moment the pointer leaves the Dock instead.
        if !inMissionControl, fullScreenAppIsShowing(on: screen, dockPID: dockPID) {
            let mouse = NSEvent.mouseLocation
            let thickness = max(minimumDockThickness, NSScreen.screens.map { $0.visibleFrame.minY - $0.frame.minY }.max() ?? 0)
            let onDock = screen.contains(mouse) && mouse.y <= screen.minY + thickness
            if !onDock { return .hidden }
        }
        return .showing(screen)
    }

    /// Whether the screens are sliding from one space to another (a swipe or Control-arrow between
    /// desktops and full-screen apps). macOS only reports a space change once the slide is over, but
    /// while it slides, windows as wide as a screen (the menu bar, a full-screen app) sit part-way
    /// between screen edges, so it shows up in the window list right away.
    /// Only the Dock's own screen counts: with "Displays have separate Spaces", swiping on another
    /// screen slides that screen alone, and the harvest should stay put. A window sliding off a
    /// neighbouring screen passes right across this one's coordinates, so where it sits mid-slide
    /// doesn't tell which screen is sliding. What does is the screen it sat on before the slide, which
    /// is remembered for every screen-wide window seen resting on a screen.
    static func isSwitchingSpaces(on screen: CGRect) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        // The window list uses top-left-origin coordinates, flipped against the main screen.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let screens = NSScreen.screens.map {
            CGRect(x: $0.frame.minX, y: mainHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height)
        }
        let dockScreen = CGRect(x: screen.minX, y: mainHeight - screen.maxY, width: screen.width, height: screen.height)
        if homeScreens.count > 500 { homeScreens.removeAll() }
        var sliding = false
        // The Dock screen's own menu bar (or a full-screen app on it) resting in place means that screen
        // isn't sliding, whatever windows from a neighbouring screen's slide pass across its coordinates.
        // This also covers windows never seen resting before (say, the first swipe to a space).
        var dockScreenAtRest = false
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0 || layer == menuLevel,
                  (window[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) != ownPID,
                  let number = window[kCGWindowNumber as String] as? Int,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            // Resting on a screen (give or take a pixel or two of rounding): remember which.
            if let home = screens.first(where: { abs($0.minX - bounds.minX) < 3 && abs($0.width - bounds.width) < 1 }) {
                homeScreens[number] = home
                if abs(home.minX - dockScreen.minX) < 1, abs(home.minY - dockScreen.minY) < 1,
                   abs(bounds.minY - dockScreen.minY) < 3,
                   layer == menuLevel || bounds.height >= dockScreen.height - 1 {
                    dockScreenAtRest = true
                }
                continue
            }
            // As wide as the Dock's screen, part-way across it, mostly on it, and not last seen on another screen.
            // Only a menu bar or a full-height window counts: some apps (like Chrome) keep thin screen-wide
            // helper windows at odd positions that never move.
            guard !sliding, abs(bounds.width - dockScreen.width) < 1,
                  layer == menuLevel || bounds.height >= dockScreen.height - 1,
                  bounds.minY >= dockScreen.minY - 1, bounds.minY < dockScreen.maxY else { continue }
            if let home = homeScreens[number], abs(home.minX - dockScreen.minX) >= 1 || abs(home.minY - dockScreen.minY) >= 1 {
                continue
            }
            let overlap = bounds.intersection(dockScreen)
            sliding = !overlap.isNull && overlap.width > bounds.width / 2
        }
        return sliding && !dockScreenAtRest
    }

    /// The screen each screen-wide window (a full-screen app, a menu bar) was last seen resting on.
    private static var homeScreens: [Int: CGRect] = [:]

    /// Whether Mission Control or App Exposé is showing. While it is, the Dock covers each screen
    /// with an extra screen-sized window just below Dock level (layer 18), which isn't there otherwise.
    static func isMissionControlShowing() -> Bool {
        guard let dockPID = dockPID(),
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        let level = Int(CGWindowLevelForKey(.dockWindow)) - 2
        let screenSizes = NSScreen.screens.map { $0.frame.size }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }) == dockPID,
                  (window[kCGWindowLayer as String] as? Int) == level,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return false }
            return screenSizes.contains { abs($0.width - bounds.width) < 1 && abs($0.height - bounds.height) < 1 }
        }
    }

    /// The frame (AppKit coordinates) of the stack tile (a folder like Downloads) under `point`, if
    /// the pointer is on one. An open stack is drawn inside the Dock's own screen-sized window, so it
    /// can't be found from the window list; instead we notice the click that opens it.
    static func stackTile(at point: CGPoint, dock: DockInfo) -> CGRect? {
        guard dock.dockFrame.contains(point) else { return nil }
        if AXIsProcessTrusted(), let dockPID = dockPID() {
            // With Accessibility access, ask the Dock exactly what's under the pointer.
            let mainHeight = NSScreen.screens.first?.frame.height ?? 0
            var element: AXUIElement?
            guard AXUIElementCopyElementAtPosition(AXUIElementCreateApplication(dockPID), Float(point.x),
                                                   Float(mainHeight - point.y), &element) == .success,
                  let element else { return nil }
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
            guard (subrole as? String) == "AXFolderDockItem" else { return nil }
            return frame(of: element) ?? CGRect(x: point.x - 30, y: dock.dockFrame.minY, width: 60, height: dock.dockFrame.height)
        }
        // Without it, stacks are the tiles just left of the Trash at the Dock's right end.
        let others = (UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-others")?.count) ?? 0
        guard others > 0 else { return nil }
        let tileSize = CGFloat(UserDefaults(suiteName: "com.apple.dock")?.double(forKey: "tilesize") ?? 0)
        let icon = tileSize > 0 ? tileSize : dock.dockFrame.height * 0.78
        let pitch = icon + max(4, icon * 0.1)
        let right = dock.dockFrame.maxX - 10 - pitch // left edge of the Trash
        let left = right - CGFloat(others) * pitch
        guard point.x >= left, point.x <= right else { return nil }
        let index = floor((point.x - left) / pitch)
        return CGRect(x: left + index * pitch, y: dock.dockFrame.minY, width: pitch, height: dock.dockFrame.height)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef, let sizeValue = sizeRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: position.x, y: mainHeight - position.y - size.height, width: size.width, height: size.height)
    }

    /// Window bounds use a top-left origin on the main display; this flips them to AppKit's bottom-left.
    private static func flipped(_ bounds: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: bounds.minX, y: mainHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }

    /// True when an app's full-screen window fills `screen` (regular windows never cover the menu bar).
    private static func fullScreenAppIsShowing(on screen: CGRect, dockPID: pid_t) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        // Some apps (like Chrome) fill a full-screen space with several windows (toolbars and
        // content), so add up each app's windows on this screen rather than looking for one.
        var covered: [pid_t: CGRect] = [:]
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        for window in windows {
            // A full-screen app hides the menu bar. If this screen's menu bar is resting in place, it's
            // showing a desktop, whatever a slide on a neighbouring screen parks over its coordinates
            // (an app coming in can sit there for a moment before it slides across).
            if (window[kCGWindowLayer as String] as? Int) == menuLevel,
               let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                let bar = flipped(bounds)
                if abs(bar.width - screen.width) < 1, abs(bar.minX - screen.minX) < 3, abs(bar.maxY - screen.maxY) < 3 {
                    return false
                }
            }
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let pid = (window[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }),
                  pid != dockPID, pid != ownPID,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }
            // Only windows resting on this screen: one sliding off a neighbouring screen (a swipe
            // there) passes across this screen's coordinates without being on it.
            let window = flipped(bounds)
            guard window.minX >= screen.minX - 1, window.maxX <= screen.maxX + 1 else { continue }
            let frame = window.intersection(screen)
            guard !frame.isNull, frame.width > 1, frame.height > 1 else { continue }
            covered[pid] = covered[pid]?.union(frame) ?? frame
        }
        return covered.values.contains { abs($0.width - screen.width) < 1 && abs($0.height - screen.height) < 1 }
    }

    // MARK: Estimating the width (no permissions needed)

    /// The Dock is centered and as wide as its icons. Without Accessibility access we can't
    /// measure it, so we estimate from the Dock's own settings and the running apps.
    static func estimatedDockWidth(thickness: CGFloat) -> CGFloat {
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let pinned = dock?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
        let others = dock?.array(forKey: "persistent-others")?.count ?? 1
        let showRecents = dock?.object(forKey: "show-recents") as? Bool ?? true
        let tileSize = CGFloat(dock?.double(forKey: "tilesize") ?? 0)

        let pinnedIDs: Set<String> = Set(pinned.compactMap { entry in
            (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
        })
        let unpinnedRunning = Set(NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                  id != "com.apple.finder", !pinnedIDs.contains(id) else { return nil }
            return id
        })
        // The section after the pinned apps holds the running apps that aren't pinned, plus the
        // recently used ones when "Show suggested and recent apps" is on.
        let recents = showRecents ? Set((dock?.array(forKey: "recent-apps") as? [[String: Any]] ?? []).compactMap { entry in
            (entry["tile-data"] as? [String: Any])?["bundle-identifier"] as? String
        }) : []
        let extras = unpinnedRunning.union(recents).subtracting(pinnedIDs).count
        let tiles = 1 /* Finder */ + pinned.count + extras + others + 1 /* Trash */
        let separators = extras > 0 ? 2 : 1

        let icon = tileSize > 0 ? tileSize : thickness * 0.78
        let pitch = icon + max(4, icon * 0.1)
        return CGFloat(tiles) * pitch + CGFloat(separators) * 14 + 20
    }

    // MARK: Measuring exactly (optional, needs Accessibility permission)

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that asks the user to allow Accessibility access.
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Reads the Dock's icon list frame through the Accessibility API.
    static func accessibilityDockFrame() -> CGRect? {
        guard AXIsProcessTrusted(),
              let dockPID = dockPID()
        else { return nil }

        let app = AXUIElementCreateApplication(dockPID)
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement],
              let list = children.first(where: { role(of: $0) == kAXListRole as String })
        else { return nil }

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(list, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(list, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef, let sizeValue = sizeRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // swiftlint:enable force_cast
        guard size.width > 0, size.height > 0 else { return nil }

        // Accessibility uses a top-left origin; flip it into AppKit's bottom-left one.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: position.x, y: mainHeight - position.y - size.height, width: size.width, height: size.height)
    }

    /// The Dock's folder tiles (stacks like Downloads), looked up again every few seconds.
    private static var folderItems: [AXUIElement] = []
    private static var folderItemsTime: TimeInterval = 0

    /// Whether a Dock stack (like Downloads) is open right now, read through the Accessibility API:
    /// an open stack's tile reports it in `AXShownStack`. Nil without Accessibility permission.
    static func isStackOpen() -> Bool? {
        guard AXIsProcessTrusted(), let dockPID = dockPID() else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
        if now - folderItemsTime > 5 {
            folderItemsTime = now
            folderItems = []
            let app = AXUIElementCreateApplication(dockPID)
            // Never let a busy Dock stall the overlay.
            AXUIElementSetMessagingTimeout(app, 0.2)
            var childrenRef: CFTypeRef?
            var itemsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let list = (childrenRef as? [AXUIElement])?.first(where: { role(of: $0) == kAXListRole as String }),
               AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &itemsRef) == .success,
               let items = itemsRef as? [AXUIElement] {
                folderItems = items.filter { item in
                    var subrole: CFTypeRef?
                    AXUIElementCopyAttributeValue(item, kAXSubroleAttribute as CFString, &subrole)
                    return (subrole as? String) == "AXFolderDockItem"
                }
            }
        }
        return folderItems.contains { item in
            var stack: CFTypeRef?
            return AXUIElementCopyAttributeValue(item, "AXShownStack" as CFString, &stack) == .success && stack != nil
        }
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
