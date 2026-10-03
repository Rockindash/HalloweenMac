import AppKit
import Combine
import SpriteKit
import SwiftUI

// The tabs of the app window (see MainWindow.swift).

// MARK: - General

struct GeneralTab: View {
    @ObservedObject var model: AppModel

    private var status: String {
        if !model.showPumpkins { return "The harvest is hidden." }
        if model.isPaused { return "Paused for an hour." }
        return "Growing on your Dock."
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fall Dock")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(status)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Form {
                Section("Harvest") {
                    Toggle("Show the harvest on my Dock", isOn: $model.showPumpkins)
                    LabeledContent("Taking a break") {
                        if model.isPaused {
                            Button("Resume") { model.resume() }
                        } else {
                            Button("Pause for 1 Hour") { model.pauseForAnHour() }
                        }
                    }
                    LabeledContent("Something new") {
                        Button("Grow New Pumpkins") { model.regrow() }
                    }
                }
                Section {
                    Picker("Season on the Dock", selection: $model.theme) {
                        ForEach(Settings.Theme.allCases, id: \.self) { theme in
                            Label(theme.title, systemImage: theme.symbol).tag(theme)
                        }
                    }
                } footer: {
                    Text("More seasons and festivals are on the way. Each one gets its own tab here.")
                        .foregroundStyle(.secondary)
                }
                Section("Your harvest") {
                    LabeledContent("Pumpkins smashed") {
                        HStack {
                            Text("\(model.smashCount)")
                                .monospacedDigit()
                            Button("Reset") { model.resetSmashCount() }
                                .disabled(model.smashCount == 0)
                        }
                    }
                }
                Section {
                    HStack {
                        Button("Show Welcome") { model.showWelcome() }
                        Spacer()
                        Button("Quit Fall Dock") { NSApp.terminate(nil) }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(height: 510)
    }
}

// MARK: - Settings

struct SettingsTab: View {
    @ObservedObject var model: AppModel
    @State private var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Open Fall Dock when I log in", isOn: $model.openAtLogin)
                Toggle("Show 🎃 in the menu bar", isOn: $model.showMenuBarIcon)
                if !model.showMenuBarIcon {
                    Text("To get back here, open Fall Dock from your Applications folder.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Sound") {
                Toggle("Play a sound when a pumpkin is smashed", isOn: $model.sound)
            }
            Section {
                LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
                Button("Open Accessibility Settings…") {
                    open("x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display")
                }
            } header: {
                Text("Motion")
            } footer: {
                Text("Fall Dock follows your Mac's Reduce Motion setting. When it's on, nothing moves by itself; things still react when you click them.")
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("Fall Dock doesn't collect or send anything. It only looks at where the Dock is and where the pointer is, to place the harvest.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 580)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
            reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    }
}

// MARK: - Dock

struct DockTab: View {
    @ObservedObject var model: AppModel
    @State private var status = AppModel.shared.dockStatus
    @State private var dock = DockSettings.read()
    @State private var hasAccessibility = DockLocator.hasAccessibility
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    /// The Dock's own settings, as macOS saves them.
    struct DockSettings {
        var position = "Bottom"
        var autohide = false
        var tile: CGFloat = 0
        var magnification = false
        var large: CGFloat = 0

        static func read() -> DockSettings {
            let dock = UserDefaults(suiteName: "com.apple.dock")
            let orientation = dock?.string(forKey: "orientation") ?? "bottom"
            return DockSettings(position: orientation.capitalized, autohide: dock?.bool(forKey: "autohide") ?? false,
                                tile: CGFloat(dock?.double(forKey: "tilesize") ?? 0),
                                magnification: dock?.bool(forKey: "magnification") ?? false,
                                large: CGFloat(dock?.double(forKey: "largesize") ?? 0))
        }
    }

    var body: some View {
        Form {
            Section("Your Dock") {
                LabeledContent("Position", value: dock.position)
                LabeledContent("Hides automatically", value: dock.autohide ? "On" : "Off")
                LabeledContent("Icon size", value: dock.tile > 0 ? "\(Int(dock.tile)) pt" : "Standard")
                LabeledContent("Magnification", value: dock.magnification ? "On, up to \(Int(dock.large)) pt" : "Off")
                LabeledContent("Length", value: status.length.map { "\(Int($0)) pt, \(status.isPrecise ? "measured" : "estimated")" }
                    ?? "Not showing right now")
                LabeledContent("On it now", value: "\(status.pumpkins) pumpkins and \(status.extras) extras")
                if dock.position != "Bottom" {
                    Label("Move your Dock to the bottom of the screen to see the harvest.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            Section("Fit") {
                if hasAccessibility {
                    Label("Fall Dock measures your Dock exactly.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fall Dock is guessing how long your Dock is.")
                        Text("Allow it under Accessibility to measure exactly. It only reads the Dock's size.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Button("Allow in System Settings…") { DockLocator.requestAccessibility() }
                }
                Button("Measure Again") {
                    model.remeasure()
                    refresh()
                }
            }
            Section {
                Picker("How full", selection: $model.fullness) {
                    ForEach(Settings.Fullness.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Spacing")
            } footer: {
                Text("Pumpkins always stay the same size. A longer Dock simply fits more of them, and if your Dock magnifies, the harvest grows along with it.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Open Desktop & Dock Settings…") { open("x-apple.systempreferences:com.apple.Desktop-Settings.extension") }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 740)
        .onReceive(tick) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        status = model.dockStatus
        dock = DockSettings.read()
        hasAccessibility = DockLocator.hasAccessibility
    }
}

// MARK: - The season's tab

struct ThemeTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: ThemePreview.image(for: model.theme))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Form {
                Section("On the Dock") {
                    Toggle("Vine", isOn: $model.showVines)
                    Toggle("Falling leaves", isOn: $model.fallingLeaves)
                }
                Section {
                    Toggle("Show cozy extras", isOn: $model.cozyExtras)
                    Group {
                        ForEach(DecorKind.allCases, id: \.self) { kind in
                            Toggle(kind.title, isOn: Binding(get: { model.enabledExtras.contains(kind) },
                                                             set: { model.setExtra(kind, enabled: $0) }))
                        }
                        Toggle("Squirrel visits", isOn: $model.squirrel)
                    }
                    .disabled(!model.cozyExtras)
                    .padding(.leading, 16)
                } header: {
                    Text("Cozy extras")
                } footer: {
                    Text("Extras sit in the gaps between pumpkins. Click the leaf piles, the mug and the lantern.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(height: 690)
    }
}

/// A little picture of each season's harvest, drawn with the same art as the Dock.
enum ThemePreview {
    private static var cache: [Settings.Theme: NSImage] = [:]

    static func image(for theme: Settings.Theme) -> NSImage {
        if let image = cache[theme] { return image }
        let image: NSImage
        switch theme {
        case .fall: image = fall()
        }
        cache[theme] = image
        return image
    }

    private static func fall() -> NSImage {
        let size = CGSize(width: 472, height: 150)
        let scale: CGFloat = 2
        let h: CGFloat = 64
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            // Evening sky, a harvest moon and a shelf like the Dock.
            ctx.setFillColor(Palette.plum.mixed(with: Palette.rust, 0.18))
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setFillColor(Palette.mustard.mixed(with: Palette.peach, 0.35))
            ctx.fillEllipse(in: CGRect(x: 380, y: 92, width: 40, height: 40))
            let shelf: CGFloat = 26
            ctx.setFillColor(Palette.rust.mixed(with: Palette.plum, 0.35))
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: shelf))

            let k = h / 60
            let vineHeight = (h * 1.25).rounded()
            if let vine = VineArt.texture(width: size.width - 8, height: vineHeight, seed: 7, unit: k, scale: scale).cgImageIfAvailable {
                ctx.draw(vine, in: CGRect(x: 4, y: shelf - 2 - VineArt.baseLevel(unit: k), width: size.width - 8, height: vineHeight))
            }

            // Left to right along the shelf.
            enum Item { case pumpkin(PumpkinKind, CGFloat), decor(DecorKind), bale(PumpkinKind) }
            let items: [Item] = [.pumpkin(.roundOrange, 1), .decor(.leafPile), .pumpkin(.butternutMustard, 0.92),
                                 .decor(.mug), .bale(.squatOrange), .decor(.acorns), .pumpkin(.tallOrange, 0.95),
                                 .decor(.lantern), .pumpkin(.roundMustard, 0.86), .decor(.apples)]
            let decorUnit = (h * 0.75).rounded()
            func width(_ item: Item) -> CGFloat {
                switch item {
                case let .pumpkin(kind, s): return PumpkinArt.size(of: kind, height: (h * s).rounded()).width
                case let .decor(kind): return CozyArt.size(of: kind, unit: decorUnit).width
                case .bale: return CozyArt.size(of: .hayBale, unit: h).width
                }
            }
            let used = items.map(width).reduce(0, +)
            let space = (size.width - used) / CGFloat(items.count + 1)
            var x = space
            func drawPumpkin(_ kind: PumpkinKind, height: CGFloat, centerX: CGFloat, y: CGFloat) {
                let s = PumpkinArt.size(of: kind, height: height)
                guard let image = PumpkinArt.texture(kind: kind, height: height, variant: 1, scale: scale).cgImageIfAvailable else { return }
                ctx.draw(image, in: CGRect(x: centerX - s.width / 2, y: y, width: s.width, height: s.height))
            }
            for item in items {
                let w = width(item)
                let center = x + w / 2
                switch item {
                case let .pumpkin(kind, s):
                    drawPumpkin(kind, height: (h * s).rounded(), centerX: center, y: shelf - 3)
                case let .decor(kind):
                    let s = CozyArt.size(of: kind, unit: decorUnit)
                    if let image = CozyArt.texture(kind, unit: decorUnit, variant: 1, scale: scale).cgImageIfAvailable {
                        ctx.draw(image, in: CGRect(x: center - s.width / 2, y: shelf - 2, width: s.width, height: s.height))
                    }
                case let .bale(kind):
                    let s = CozyArt.size(of: .hayBale, unit: h)
                    if let image = CozyArt.texture(.hayBale, unit: h, variant: 2, scale: scale).cgImageIfAvailable {
                        ctx.draw(image, in: CGRect(x: center - s.width / 2, y: shelf - 3, width: s.width, height: s.height))
                    }
                    drawPumpkin(kind, height: (h * 0.78).rounded(), centerX: center, y: shelf - 3 + s.height * 0.86)
                }
                x += w + space
            }
            // A falling leaf.
            LeafArt.drawWagonLeaf(ctx, kind: .oak, at: CGPoint(x: 120, y: 128), length: 18, angle: -30, flip: false)
        }
        guard let image = texture.cgImageIfAvailable else { return NSImage(size: size) }
        return NSImage(cgImage: image, size: size)
    }
}

private extension SKTexture {
    var cgImageIfAvailable: CGImage? { cgImage() }
}

private func open(_ url: String) {
    if let url = URL(string: url) { NSWorkspace.shared.open(url) }
}
