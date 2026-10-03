import AppKit
import Combine
import SpriteKit
import SwiftUI

// The tabs of the app window (see MainWindow.swift), in the harvest-wagon colors:
// a live little harvest to play with, stat tiles, cards with colored badges, and picture tiles.

/// The window's own colors: the dark wagon colors, whatever the Dock art is using.
extension Color {
    static let pumpkin = Color(cgColor: .hex(0xEB6C15))
    static let harvestPlum = Color(cgColor: .hex(0x5D1C2B))
    static let harvestRust = Color(cgColor: .hex(0xA24B22))
    static let harvestMustard = Color(cgColor: .hex(0xDB9D24))
    static let harvestPeach = Color(cgColor: .hex(0xFCDCBE))
    static let harvestGreen = Color(cgColor: .hex(0x627329))
}

// MARK: - Building blocks

/// A rounded panel that groups related things.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

/// A small colored square with a white symbol, like the icons in System Settings.
struct Badge: View {
    var symbol: String
    var color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
    }
}

/// A row with a badge, a title, an optional explanation and a control on the right.
struct SettingRow<Trailing: View>: View {
    var symbol: String
    var color: Color
    var title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Badge(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

/// A big number with a label.
struct StatTile: View {
    var value: String
    var label: String
    var symbol: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 1))
    }
}

/// A chunky button with a symbol and two lines of text. Lit up in orange while `isOn`.
struct ActionTile: View {
    var symbol: String
    var title: String
    var detail: String
    var isOn = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? .white : Color.pumpkin)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(isOn ? Color.white.opacity(0.22) : Color.pumpkin.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.caption).opacity(0.75)
                }
            }
            .foregroundStyle(isOn ? .white : .primary)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(LinearGradient(colors: [.pumpkin, .harvestRust], startPoint: .topLeading,
                                                               endPoint: .bottomTrailing))
                               : AnyShapeStyle(.quaternary.opacity(0.45)))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Buttons that dip a little when pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A rounded label with a symbol, for facts about the Dock.
struct Chip: View {
    var symbol: String
    var text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.quaternary.opacity(0.6)))
    }
}

// MARK: - A live little harvest

/// The real Dock scene, running on a pretend Dock inside the window. Its pumpkins can be smashed.
@MainActor
final class LiveHarvest: ObservableObject {
    let scene: PumpkinScene

    init() {
        scene = PumpkinScene(size: CGSize(width: 512, height: 210))
        scene.onSmash = { AppModel.shared.recordSmash() }
    }

    /// Where the pretend Dock's top edge is, from the bottom of the view.
    static let dockTop: CGFloat = 54

    func layout(size: CGSize, regrow: Bool) {
        guard size.width > 100 else { return }
        scene.size = size
        scene.configure(dockRect: CGRect(x: 22, y: 8, width: size.width - 44, height: Self.dockTop - 8),
                        pixelScale: NSScreen.main?.backingScaleFactor ?? 2, magnifier: DockMagnifier(), regrow: regrow)
    }
}

struct LiveHarvestView: View {
    @ObservedObject var model: AppModel
    @StateObject private var harvest = LiveHarvest()
    var height: CGFloat = 210

    /// The settings that change what grows; the little harvest regrows when any of them change.
    private var look: [AnyHashable] {
        [model.showVines, model.cozyExtras, model.squirrel, model.enabledExtras, model.fullness, model.fallingLeaves,
         model.appearance]
    }

    private let icons: [(String, Color)] = [
        ("face.smiling", .blue), ("globe", .teal), ("envelope.fill", .indigo), ("music.note", .pink),
        ("photo.fill", .orange), ("message.fill", .green), ("calendar", .red), ("note.text", .yellow),
        ("gearshape.fill", .gray), ("folder.fill", .cyan),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // An evening sky with a harvest moon.
                LinearGradient(colors: [Color.harvestPlum, Color.harvestRust.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(Color.harvestMustard.opacity(0.85))
                    .frame(width: 46, height: 46)
                    .position(x: geometry.size.width - 70, y: 44)
                // A pretend Dock.
                HStack(spacing: 10) {
                    ForEach(0..<icons.count, id: \.self) { i in
                        Image(systemName: icons[i].0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(icons[i].1.gradient))
                    }
                }
                .padding(.horizontal, 14)
                .frame(width: geometry.size.width - 44, height: LiveHarvest.dockTop - 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.18)))
                .padding(.bottom, 8)
                SpriteView(scene: harvest.scene, options: [.allowsTransparency])
            }
            .onAppear { harvest.layout(size: geometry.size, regrow: true) }
            .onChange(of: geometry.size) { harvest.layout(size: $0, regrow: false) }
            .onChange(of: look) { _ in harvest.layout(size: geometry.size, regrow: true) }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject var model: AppModel
    @State private var dock = AppModel.shared.dockStatus
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var status: (text: String, color: Color) {
        if !model.showPumpkins { return ("Hidden", .gray) }
        if model.isPaused { return ("Paused for an hour", .yellow) }
        return ("Growing on your Dock", .green)
    }

    var body: some View {
        VStack(spacing: 14) {
            LiveHarvestView(model: model)
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 12) {
                        Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 46, height: 46)
                            .shadow(radius: 4, y: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fall Dock")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            HStack(spacing: 6) {
                                Circle().fill(status.color).frame(width: 7, height: 7)
                                Text(status.text).font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.25)))
                        }
                    }
                    .padding(14)
                }
                .overlay(alignment: .topTrailing) {
                    Text("Click a pumpkin!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.harvestPlum)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.harvestPeach))
                        .padding(14)
                        .padding(.trailing, 64)
                }

            HStack(spacing: 10) {
                StatTile(value: "\(model.smashCount)", label: "Pumpkins smashed", symbol: "hammer.fill", color: .pumpkin)
                StatTile(value: dock.isShowing ? "\(dock.pumpkins)" : "–",
                         label: dock.isShowing ? "On your Dock now" : "Dock hidden right now", symbol: "leaf.fill", color: .harvestGreen)
                StatTile(value: model.theme.title, label: "Season", symbol: model.theme.symbol, color: .harvestMustard)
            }

            HStack(spacing: 10) {
                ActionTile(symbol: model.showPumpkins ? "eye.fill" : "eye.slash.fill",
                           title: model.showPumpkins ? "On the Dock" : "Hidden",
                           detail: model.showPumpkins ? "Click to hide" : "Click to show",
                           isOn: model.showPumpkins) { model.showPumpkins.toggle() }
                ActionTile(symbol: model.isPaused ? "play.fill" : "pause.fill",
                           title: model.isPaused ? "Resume" : "Pause",
                           detail: model.isPaused ? "Paused for an hour" : "Hide for an hour",
                           isOn: model.isPaused) { model.isPaused ? model.resume() : model.pauseForAnHour() }
                ActionTile(symbol: "sparkles", title: "Grow New", detail: "A fresh harvest") { model.regrow() }
            }

            HStack {
                Picker("Season", selection: $model.theme) {
                    ForEach(Settings.Theme.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                .fixedSize()
                Text("More seasons coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset Count") { model.resetSmashCount() }
                    .disabled(model.smashCount == 0)
                Button("Welcome") { model.showWelcome() }
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(20)
        .tint(.pumpkin)
        .onReceive(tick) { _ in dock = model.dockStatus }
    }
}

// MARK: - Settings

struct SettingsTab: View {
    @ObservedObject var model: AppModel
    @State private var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 14) {
            Card(title: "Startup") {
                SettingRow(symbol: "power", color: .green, title: "Open when I log in",
                           detail: "Starts quietly, with the harvest already on your Dock.") {
                    Toggle("", isOn: $model.openAtLogin).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "menubar.rectangle", color: .pumpkin, title: "Show 🎃 in the menu bar",
                           detail: model.showMenuBarIcon ? "Quick settings, one click away."
                               : "To get back here, open Fall Dock from your Applications folder.") {
                    Toggle("", isOn: $model.showMenuBarIcon).labelsHidden().toggleStyle(.switch)
                }
            }
            Card(title: "Sound and motion") {
                SettingRow(symbol: "speaker.wave.2.fill", color: .pink, title: "Smash sound",
                           detail: "A soft, squishy thump, made right in the app.") {
                    Toggle("", isOn: $model.sound).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "wind", color: .blue, title: "Reduce Motion is \(reduceMotion ? "on" : "off")",
                           detail: "When it's on in your Mac's settings, nothing moves by itself. Clicks still work.") {
                    Button("Change…") { open("x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") }
                }
            }
            Card(title: "Privacy") {
                SettingRow(symbol: "hand.raised.fill", color: .gray, title: "Nothing leaves your Mac",
                           detail: "Fall Dock doesn't collect or send anything. It only looks at where the Dock and the pointer are, to place the harvest.") {
                    EmptyView()
                }
            }
            Text("Fall Dock \(version) · Made with 🧡 for cozy autumn days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .tint(.pumpkin)
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
        VStack(spacing: 14) {
            Card(title: "Your Dock") {
                DockDiagram(pumpkins: status.pumpkins, extras: status.extras, isShowing: status.isShowing)
                HStack(spacing: 6) {
                    Text(status.length.map { "\(Int($0)) pt wide" } ?? "Not showing right now")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    if status.length != nil {
                        Text(status.isPrecise ? "measured" : "estimated")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill((status.isPrecise ? Color.green : Color.harvestMustard).opacity(0.2)))
                    }
                }
                FlowChips(chips: [
                    ("rectangle.bottomthird.inset.filled", dock.position),
                    ("square.grid.2x2", dock.tile > 0 ? "\(Int(dock.tile)) pt icons" : "Standard icons"),
                    ("plus.magnifyingglass", dock.magnification ? "Magnifies to \(Int(dock.large)) pt" : "No magnification"),
                    ("eye", dock.autohide ? "Hides automatically" : "Always showing"),
                ])
                if dock.position != "Bottom" {
                    Label("Move your Dock to the bottom of the screen to see the harvest.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Card(title: "Fit") {
                if hasAccessibility {
                    SettingRow(symbol: "checkmark", color: .green, title: "Measured exactly",
                               detail: "Fall Dock reads your Dock's size, so the harvest lines up perfectly.") {
                        Button("Measure Again") { model.remeasure(); refresh() }
                    }
                } else {
                    SettingRow(symbol: "ruler", color: .harvestMustard, title: "Estimated from your settings",
                               detail: "Allow Fall Dock under Accessibility to measure exactly. It only reads the Dock's size.") {
                        Button("Allow…") { DockLocator.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            Card(title: "How full") {
                HStack(spacing: 10) {
                    ForEach(Settings.Fullness.allCases, id: \.self) { fullness in
                        FullnessTile(fullness: fullness, isSelected: model.fullness == fullness) { model.fullness = fullness }
                    }
                }
                Text("Pumpkins always stay the same size. A longer Dock simply fits more of them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Open Desktop & Dock Settings…") { open("x-apple.systempreferences:com.apple.Desktop-Settings.extension") }
                .buttonStyle(.link)
        }
        .padding(20)
        .tint(.pumpkin)
        .onReceive(tick) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        status = model.dockStatus
        dock = DockSettings.read()
        hasAccessibility = DockLocator.hasAccessibility
    }
}

/// A little drawing of the Dock with pumpkins and extras along its top.
struct DockDiagram: View {
    var pumpkins: Int
    var extras: Int
    var isShowing: Bool

    var body: some View {
        // While the Dock is hidden, show a faded example row.
        let items = isShowing ? min(max(pumpkins + extras, 1), 21) : 13
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<items, id: \.self) { i in
                    if i % 2 == 0 || (isShowing && extras == 0) {
                        Ellipse().fill(Color.pumpkin.gradient).frame(width: 16, height: 13)
                    } else {
                        RoundedRectangle(cornerRadius: 2).fill(Color.harvestMustard.opacity(0.8)).frame(width: 9, height: 7)
                    }
                }
            }
            .opacity(isShowing ? 1 : 0.35)
            Capsule().fill(Color.harvestGreen).frame(height: 3)
                .padding(.horizontal, 6)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.quaternary)
                .frame(height: 26)
                .overlay(
                    HStack(spacing: 5) {
                        ForEach(0..<14, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4).fill(.tertiary).frame(width: 16, height: 16)
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity)
    }
}

/// Chips that wrap onto a second line when they don't fit.
struct FlowChips: View {
    var chips: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<min(2, chips.count), id: \.self) { Chip(symbol: chips[$0].0, text: chips[$0].1) }
            }
            HStack(spacing: 6) {
                ForEach(min(2, chips.count)..<chips.count, id: \.self) { Chip(symbol: chips[$0].0, text: chips[$0].1) }
            }
        }
    }
}

/// One of the "How full" choices, with a picture of how close together things sit.
struct FullnessTile: View {
    var fullness: Settings.Fullness
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 12 * fullness.spacing + 1) {
                    ForEach(0..<(fullness == .aFew ? 3 : fullness == .plenty ? 5 : 6), id: \.self) { _ in
                        Ellipse().fill(Color.pumpkin.gradient).frame(width: 13, height: 11)
                    }
                }
                .frame(height: 16)
                Text(fullness.title).font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.pumpkin.opacity(0.15) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.pumpkin : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - The season's tab

struct ThemeTab: View {
    @ObservedObject var model: AppModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: ThemePreview.image(for: model.theme))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.theme.title)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                        Text("Pumpkins, hay and falling leaves")
                            .font(.callout.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(Color.harvestPeach)
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                ActionTile(symbol: "laurel.leading", title: "Vine", detail: model.showVines ? "Curling along the Dock" : "Off",
                           isOn: model.showVines) { model.showVines.toggle() }
                ActionTile(symbol: "leaf.fill", title: "Falling leaves", detail: model.fallingLeaves ? "Drifting down" : "Off",
                           isOn: model.fallingLeaves) { model.fallingLeaves.toggle() }
                ActionTile(symbol: "basket.fill", title: "Cozy extras", detail: model.cozyExtras ? "Between the pumpkins" : "Off",
                           isOn: model.cozyExtras) { model.cozyExtras.toggle() }
            }

            Card(title: "Pick your extras") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(DecorKind.allCases, id: \.self) { kind in
                        ExtraTile(image: ExtraArt.image(for: kind), title: kind.title, isOn: model.enabledExtras.contains(kind)) {
                            model.setExtra(kind, enabled: !model.enabledExtras.contains(kind))
                        }
                    }
                    ExtraTile(image: ExtraArt.squirrel(), title: "Squirrel", isOn: model.squirrel) { model.squirrel.toggle() }
                }
                .disabled(!model.cozyExtras)
                .opacity(model.cozyExtras ? 1 : 0.45)
                Text("Tap to switch each one on or off. On the Dock, click the leaf piles, the latte and the lantern.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .tint(.pumpkin)
    }
}

/// A picture tile for one of the extras that switches it on or off.
struct ExtraTile: View {
    var image: NSImage
    var title: String
    var isOn: Bool
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 48)
                    .saturation(isOn ? 1 : 0)
                    .opacity(isOn ? 1 : 0.4)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOn ? (colorScheme == .dark ? Color.harvestPlum.opacity(0.35) : Color.pumpkin.opacity(0.1)) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOn ? Color.pumpkin.opacity(0.7) : Color.secondary.opacity(0.25), lineWidth: isOn ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.pumpkin : Color.secondary)
                    .padding(6)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Pictures of the extras for their tiles, drawn with the same art as the Dock.
enum ExtraArt {
    private static var cache: [String: NSImage] = [:]

    static func image(for kind: DecorKind) -> NSImage {
        let key = "\(kind.rawValue)-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let unit: CGFloat = 60
        let size = CozyArt.size(of: kind, unit: unit)
        let texture = CozyArt.texture(kind, unit: unit, variant: 1, scale: 2)
        let image = NSImage(cgImage: texture.cgImage(), size: size)
        cache[key] = image
        return image
    }

    static func squirrel() -> NSImage {
        let key = "squirrel-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let unit: CGFloat = 60
        let size = CozyArt.squirrelSize(unit: unit)
        let texture = TextureMaker.make(size: size, scale: 2) { ctx in
            ctx.draw(CozyArt.squirrelTailTexture(unit: unit, scale: 2).cgImage(), in: CGRect(origin: .zero, size: size))
            ctx.draw(CozyArt.squirrelTexture(unit: unit, scale: 2).cgImage(), in: CGRect(origin: .zero, size: size))
        }
        let image = NSImage(cgImage: texture.cgImage(), size: size)
        cache[key] = image
        return image
    }
}

/// A little picture of each season's harvest, drawn with the same art as the Dock.
enum ThemePreview {
    private static var cache: [String: NSImage] = [:]

    static func image(for theme: Settings.Theme) -> NSImage {
        let key = "\(theme.rawValue)-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let image: NSImage
        switch theme {
        case .fall: image = fall()
        }
        cache[key] = image
        return image
    }

    private static func fall() -> NSImage {
        let size = CGSize(width: 520, height: 170)
        let scale: CGFloat = 2
        let h: CGFloat = 64
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            // Evening sky, a harvest moon and a shelf like the Dock.
            ctx.setFillColor(Palette.plum.mixed(with: Palette.rust, 0.18))
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setFillColor(Palette.mustard.mixed(with: Palette.peach, 0.35))
            ctx.fillEllipse(in: CGRect(x: 430, y: 108, width: 42, height: 42))
            let shelf: CGFloat = 26
            ctx.setFillColor(Palette.rust.mixed(with: Palette.plum, 0.35))
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: shelf))

            let k = h / 60
            let vineHeight = (h * 1.25).rounded()
            ctx.draw(VineArt.texture(width: size.width - 8, height: vineHeight, seed: 7, unit: k, scale: scale).cgImage(),
                     in: CGRect(x: 4, y: shelf - 2 - VineArt.baseLevel(unit: k), width: size.width - 8, height: vineHeight))

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
                ctx.draw(PumpkinArt.texture(kind: kind, height: height, variant: 1, scale: scale).cgImage(),
                         in: CGRect(x: centerX - s.width / 2, y: y, width: s.width, height: s.height))
            }
            for item in items {
                let w = width(item)
                let center = x + w / 2
                switch item {
                case let .pumpkin(kind, s):
                    drawPumpkin(kind, height: (h * s).rounded(), centerX: center, y: shelf - 3)
                case let .decor(kind):
                    let s = CozyArt.size(of: kind, unit: decorUnit)
                    ctx.draw(CozyArt.texture(kind, unit: decorUnit, variant: 1, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 2, width: s.width, height: s.height))
                case let .bale(kind):
                    let s = CozyArt.size(of: .hayBale, unit: h)
                    ctx.draw(CozyArt.texture(.hayBale, unit: h, variant: 2, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 3, width: s.width, height: s.height))
                    drawPumpkin(kind, height: (h * 0.78).rounded(), centerX: center, y: shelf - 3 + s.height * 0.86)
                }
                x += w + space
            }
            // Falling leaves.
            LeafArt.drawWagonLeaf(ctx, kind: .oak, at: CGPoint(x: 300, y: 140), length: 18, angle: -30, flip: false)
            LeafArt.drawWagonLeaf(ctx, kind: .ovate, at: CGPoint(x: 380, y: 112), length: 15, angle: 40, flip: true)
        }
        return NSImage(cgImage: texture.cgImage(), size: size)
    }
}

private func open(_ url: String) {
    if let url = URL(string: url) { NSWorkspace.shared.open(url) }
}
