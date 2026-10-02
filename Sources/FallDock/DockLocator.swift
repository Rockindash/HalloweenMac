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

    /// Returns the Dock if it's visible at the bottom of a screen, or nil when it's
    /// hidden, auto-hiding, on the left/right edge, or an app is full screen.
    static func locate() -> DockInfo? {
        for screen in NSScreen.screens {
            let frame = screen.frame
            let visible = screen.visibleFrame
            let thickness = visible.minY - frame.minY
            guard thickness >= minimumDockThickness else { continue }

            if let precise = accessibilityDockFrame(), frame.intersects(precise) {
                // Use the measured width, but the screen gap for the top edge.
                let rect = CGRect(x: precise.minX, y: frame.minY, width: precise.width, height: thickness)
                return DockInfo(screenFrame: frame, dockFrame: rect, isPrecise: true)
            }

            let width = min(frame.width - 16, estimatedDockWidth(thickness: thickness))
            let rect = CGRect(x: frame.midX - width / 2, y: frame.minY, width: width, height: thickness)
            return DockInfo(screenFrame: frame, dockFrame: rect, isPrecise: false)
        }
        return nil
    }

    // MARK: Is the Dock showing right now?

    /// The Dock keeps a window at Dock level that is on screen only while the Dock can be seen.
    /// In a full-screen app (or with auto-hide) the Dock slides away and that window goes off screen.
    /// Window positions and owners are readable without Screen Recording permission.
    static func isDockOnScreen() -> Bool {
        guard let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        else { return true }
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))

        func hasDockWindow(_ options: CGWindowListOption) -> Bool {
            guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
            return windows.contains { window in
                (window[kCGWindowOwnerPID as String] as? Int).map { pid_t($0) } == dockPID
                    && (window[kCGWindowLayer as String] as? Int) == dockLevel
            }
        }

        // If this macOS version has no such window at all, don't hide anything.
        guard hasDockWindow([.optionAll]) else { return true }
        return hasDockWindow([.optionOnScreenOnly])
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
        let unpinnedRunning = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular
                && app.bundleIdentifier != "com.apple.finder"
                && !(app.bundleIdentifier.map { pinnedIDs.contains($0) } ?? false)
        }.count

        let extras = unpinnedRunning + (showRecents ? 1 : 0)
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
              let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }

        let app = AXUIElementCreateApplication(dockApp.processIdentifier)
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

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
