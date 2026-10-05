import AppKit
import SwiftUI

/// The window that greets people the first time they open Fall Dock. The app lives only in the
/// menu bar, so without it opening the app would seem to do nothing.
@MainActor
final class WelcomeWindow {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 460, height: 520),
                                  styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: WelcomeView(model: model) { [weak window] in window?.close() })
            window.center()
            self.window = window
        }
        Settings.hasSeenWelcome = true
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var close: () -> Void
    @State private var hasAccessibility = DockLocator.hasAccessibility
    private let accessibilityCheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
            VStack(spacing: 4) {
                Text("Welcome to Fall Dock")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("A cozy harvest on top of your Dock.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                tip("macwindow", "Open Fall Dock from Applications or the 🎃 menu to change things.")
                tip("hand.tap", "Click a pumpkin to smash it. A new one grows back a few seconds later.")
                tip("cursorarrow.rays", "Point at the leaves, the latte and the lantern. Click them too.")
                tip("magnifyingglass", "If your Dock magnifies, the harvest grows along with it.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !hasAccessibility {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fit the pumpkins to your Dock exactly")
                        .font(.headline)
                    Text("Without this, Fall Dock guesses how long your Dock is. It only reads the Dock's size, never your screen or what you type.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Allow in System Settings…") { DockLocator.requestAccessibility() }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Label("Fall Dock can measure your Dock exactly.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Toggle("Open Fall Dock when I log in", isOn: $model.openAtLogin)

            Button(action: close) {
                Text("Start the Harvest").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .tint(.pumpkin)
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(width: 460)
        .onReceive(accessibilityCheck) { _ in hasAccessibility = DockLocator.hasAccessibility }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.orange)
                .frame(width: 22)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
