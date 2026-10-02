// Dock behavior probe. Run with: swift dock-probe.swift
// Prints a line whenever anything Dock-related changes, for 3 minutes.
import AppKit
import ApplicationServices

func dockWindows() -> String {
    guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return "none" }
    let onscreen = Set(((CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? [])
        .compactMap { $0[kCGWindowNumber as String] as? Int })
    return list.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" }
        .compactMap { w -> String? in
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let num = w[kCGWindowNumber as String] as? Int ?? 0
            let alpha = w[kCGWindowAlpha as String] as? CGFloat ?? 0
            // Skip wallpaper/desktop windows (very negative layers).
            if layer < 0 { return nil }
            return "L\(layer) #\(num) (\(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)) \(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0))) a\(alpha) \(onscreen.contains(num) ? "ON" : "off")"
        }.joined(separator: " | ")
}

func fullScreenWindow() -> String {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return "?" }
    for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
        let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        let rect = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
        for s in NSScreen.screens where abs(s.frame.width - rect.width) < 1 && abs(s.frame.height - rect.height) < 1 {
            return "\(w[kCGWindowOwnerName as String] as? String ?? "?") \(Int(rect.width))x\(Int(rect.height))"
        }
    }
    return "no"
}

func axDock() -> String {
    guard AXIsProcessTrusted() else { return "AX:untrusted" }
    guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return "AX:nodock" }
    let app = AXUIElementCreateApplication(dock.processIdentifier)
    var children: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
          let kids = children as? [AXUIElement] else { return "AX:nokids" }
    for k in kids {
        var pos: CFTypeRef?, size: CFTypeRef?
        AXUIElementCopyAttributeValue(k, kAXPositionAttribute as CFString, &pos)
        AXUIElementCopyAttributeValue(k, kAXSizeAttribute as CFString, &size)
        var p = CGPoint.zero, s = CGSize.zero
        if let pos { AXValueGetValue(pos as! AXValue, .cgPoint, &p) }
        if let size { AXValueGetValue(size as! AXValue, .cgSize, &s) }
        return "AX:(\(Int(p.x)),\(Int(p.y)) \(Int(s.width))x\(Int(s.height)))"
    }
    return "AX:empty"
}

_ = NSApplication.shared
let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
var last = ""
let start = Date()
print("screens:", NSScreen.screens.map { "\($0.frame)" })
while Date().timeIntervalSince(start) < 180 {
    let gaps = NSScreen.screens.map { "gap=\(Int($0.visibleFrame.minY - $0.frame.minY))" }.joined(separator: ",")
    let autohide = dockDefaults?.bool(forKey: "autohide") ?? false
    let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
    let line = "autohide=\(autohide) \(gaps) front=\(front) fullscreen=\(fullScreenWindow()) \(axDock()) dock=[\(dockWindows())]"
    if line != last {
        let m = NSEvent.mouseLocation
        print(String(format: "%6.1fs", Date().timeIntervalSince(start)), "mouse=(\(Int(m.x)),\(Int(m.y)))", line)
        fflush(stdout)
        last = line
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
}
