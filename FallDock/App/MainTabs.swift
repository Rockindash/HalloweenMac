import AppKit
import Combine
import SpriteKit
import SwiftUI

// The building blocks of the app window (see MainView.swift) and its Customize page, laid out like
// the Mac App Store: big titles, a hero card with artwork, and plain rounded cards with no borders.

/// The window's own colors: the dark wagon colors, whatever the Dock art is using.
extension Color {
    static let pumpkin = Color(cgColor: .hex(0xEB6C15))
    static let harvestPlum = Color(cgColor: .hex(0x5D1C2B))
    static let harvestRust = Color(cgColor: .hex(0xA24B22))
    static let harvestMustard = Color(cgColor: .hex(0xDB9D24))
    static let harvestPeach = Color(cgColor: .hex(0xFCDCBE))
    static let harvestGreen = Color(cgColor: .hex(0x627329))
    /// Halloween's night-sky purple.
    static let harvestNight = Color(cgColor: .hex(0x2E2140))

    /// The page behind the cards: white in Light mode, near black in Dark.
    static let pageBackground = Color(nsColor: .textBackgroundColor)

    /// A card's fill, a step off the page in either mode.
    static let cardFill = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.075) : NSColor(white: 0, alpha: 0.045)
    })
}

// MARK: - Building blocks

/// A page: its big title, then its sections.
struct PageLayout<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .padding(.bottom, -6)
                content
            }
            .padding(.horizontal, 40)
            .padding(.top, 34)
            .padding(.bottom, 40)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Start near the top of the window, as the App Store does, rather than below the empty toolbar.
        .modifier(UnderToolbar())
        .background(Color.pageBackground)
    }
}

/// A rounded panel that groups related things, with an optional heading above it.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.title3.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardFill))
        }
    }
}

/// The small grey capitals over a card's title.
struct Eyebrow: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(.secondary)
    }
}

/// The wide card at the top of a page: words on the left, artwork on the right.
struct HeroCard<Art: View, Footer: View>: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var height: CGFloat = 300
    @ViewBuilder var art: Art
    @ViewBuilder var footer: Footer

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                footer
            }
            .padding(24)
            .frame(width: 250, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(LinearGradient(colors: [Color(cgColor: .hex(0x3A1620)), Color(cgColor: .hex(0x2A1218))],
                                       startPoint: .top, endPoint: .bottom))
            // Always light words on the dark harvest panel, in either mode.
            .environment(\.colorScheme, .dark)
            // The artwork fills what's left without asking for more room.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { art }
                .clipped()
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension HeroCard where Footer == EmptyView {
    init(eyebrow: String, title: String, subtitle: String, height: CGFloat = 300, @ViewBuilder art: () -> Art) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, height: height, art: art, footer: { EmptyView() })
    }
}

/// A card in the grid under the hero: words on the left, a round picture on the right.
struct FeatureCard<Footer: View>: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var image: NSImage
    var imageBackground: Color
    @ViewBuilder var footer: Footer

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Circle()
                .fill(imageBackground)
                .overlay {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                }
                .frame(width: 96, height: 96)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardFill))
    }
}

extension FeatureCard where Footer == EmptyView {
    init(eyebrow: String, title: String, subtitle: String, image: NSImage, imageBackground: Color) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, image: image, imageBackground: imageBackground) { EmptyView() }
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
            // The UI tests find the control by its row's title.
            trailing
                .accessibilityIdentifier(title)
        }
    }
}

/// A slider from 0 to 1 that snaps to the middle when dragged close to it.
struct MiddleMarkedSlider: NSViewRepresentable {
    @Binding var value: Double

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: context.coordinator,
                              action: #selector(Coordinator.changed(_:)))
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.value = $value
        if slider.doubleValue != value { slider.doubleValue = value }
    }

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    final class Coordinator: NSObject {
        var value: Binding<Double>
        /// How close to the middle, as a fraction of the slider's range, the knob snaps to it.
        private let snapDistance = 0.08
        private var isSnapped = false

        init(value: Binding<Double>) { self.value = value }

        // Sent continuously while dragging. Setting the slider's value here moves the knob right away,
        // so it visibly jumps to the middle mid-drag. (The slider doesn't ask its cell while tracking,
        // so snapping has to happen here.)
        @objc func changed(_ slider: NSSlider) {
            let snaps = abs(slider.doubleValue - 0.5) < snapDistance
            if snaps {
                slider.doubleValue = 0.5
                // A light click on the trackpad as it lands on the middle.
                if !isSnapped {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            isSnapped = snaps
            value.wrappedValue = slider.doubleValue
        }
    }
}

/// Buttons that dip a little when pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - A live little harvest

/// The real Dock scene, running on a pretend Dock inside the window. Its pumpkins can be smashed (and
/// its diyas lit), and they count.
@MainActor
final class LiveHarvest: ObservableObject {
    let scene: PumpkinScene

    init() {
        scene = PumpkinScene(size: CGSize(width: 512, height: 210))
        scene.onSmash = { AppModel.shared.addToCount() }
        scene.onLightUp = { AppModel.shared.addToCount() }
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
    var cornerRadius: CGFloat = 16

    /// The settings that change what grows; the little harvest regrows when any of them change.
    private var look: [AnyHashable] {
        [model.showVines, model.cozyExtras, model.squirrel, model.enabledExtras, model.fullness, model.fallingLeaves,
         model.bats, model.ghost, model.fireworks, model.peacock]
    }

    /// Light mode shows a fall afternoon with the sun out; Dark mode, a starry night under a harvest moon.
    /// At Halloween, a purple dusk or a deep purple night; at Diwali, a plum and saffron dusk or a moonless indigo night.
    private var isDay: Bool { model.appearance == .light }

    private func sky(_ theme: Settings.Theme, day: Bool) -> [Color] {
        switch (theme, day) {
        case (.fall, true): return [Color(cgColor: .hex(0x8CC4E8)), Color(cgColor: .hex(0xCFE3EE)), Color.harvestPeach]
        case (.fall, false): return [Color(cgColor: .hex(0x1C2340)), Color(cgColor: .hex(0x4A2238)), Color.harvestPlum]
        case (.halloween, true): return [Color(cgColor: .hex(0x6B5A8E)), Color(cgColor: .hex(0xC48BA0)), Color(cgColor: .hex(0xF2B279))]
        case (.halloween, false): return [Color(cgColor: .hex(0x120C1F)), Color.harvestNight, Color(cgColor: .hex(0x4D2A4A))]
        case (.diwali, true): return [Color(cgColor: .hex(0x7A3E7E)), Color(cgColor: .hex(0xE57A6E)), Color(cgColor: .hex(0xFBC46A))]
        case (.diwali, false): return [Color(cgColor: .hex(0x1A1240)), Color(cgColor: .hex(0x3D1E5C)), Color(cgColor: .hex(0x7A2E52))]
        }
    }

    /// A few stars for the night sky, as fractions of the view's size (x, y, diameter).
    private let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.10, 2.5), (0.17, 0.28, 1.5), (0.27, 0.08, 2), (0.36, 0.22, 1.5), (0.46, 0.06, 2.5),
        (0.55, 0.30, 1.5), (0.63, 0.14, 2), (0.72, 0.32, 1.5), (0.80, 0.06, 1.5), (0.94, 0.26, 2),
        (0.12, 0.42, 1.5), (0.40, 0.40, 1.5), (0.68, 0.46, 1.5),
    ]

    private let icons: [(String, Color)] = [
        ("face.smiling", .blue), ("globe", .teal), ("envelope.fill", .indigo), ("music.note", .pink),
        ("photo.fill", .orange), ("message.fill", .green), ("calendar", .red), ("note.text", .yellow),
        ("gearshape.fill", .gray), ("folder.fill", .cyan),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Day or night, following Light and Dark mode: the skies cross-fade while the sun sets
                // and the moon rises (or the other way round).
                // One sky for each theme, by night and by day, cross-fading as the theme or Light and Dark change.
                ForEach(Settings.Theme.allCases, id: \.self) { theme in
                    LinearGradient(colors: sky(theme, day: false), startPoint: .top, endPoint: .bottom)
                        .opacity(model.theme == theme ? 1 : 0)
                }
                ForEach(stars.indices, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.75))
                        .frame(width: stars[i].2, height: stars[i].2)
                        .position(x: geometry.size.width * stars[i].0, y: geometry.size.height * stars[i].1)
                }
                .opacity(isDay ? 0 : 1)
                ZStack {
                    ForEach(Settings.Theme.allCases, id: \.self) { theme in
                        LinearGradient(colors: sky(theme, day: true), startPoint: .top, endPoint: .bottom)
                            .opacity(model.theme == theme ? 1 : 0)
                    }
                }
                .opacity(isDay ? 1 : 0)
                // The sun, with a warm glow.
                Circle()
                    .fill(Color(cgColor: .hex(0xF7C948)))
                    .frame(width: 46, height: 46)
                    .shadow(color: Color(cgColor: .hex(0xF7C948)).opacity(0.8), radius: 18)
                    .position(x: geometry.size.width - 70, y: 44)
                    .offset(y: isDay ? 0 : geometry.size.height)
                // The harvest moon: a soft cream disc with a cool glow.
                Circle()
                    .fill(Color(cgColor: .hex(0xF4E6C3)))
                    .overlay(Circle().fill(Color(cgColor: .hex(0xE2CFA2))).frame(width: 10, height: 10).offset(x: -9, y: -6))
                    .overlay(Circle().fill(Color(cgColor: .hex(0xE2CFA2))).frame(width: 7, height: 7).offset(x: 8, y: 9))
                    .frame(width: 42, height: 42)
                    .shadow(color: .white.opacity(0.35), radius: 14)
                    .position(x: geometry.size.width - 70, y: 44)
                    .offset(y: isDay ? geometry.size.height : 0)
                    // Diwali falls on the new moon, so its nights are dark (and full of fireworks).
                    .opacity(model.theme == .diwali ? 0 : 1)
                // A pretend Dock.
                HStack(spacing: 10) {
                    // As many icons as fit, like a real Dock.
                    ForEach(0..<min(icons.count, max(1, Int((geometry.size.width - 62) / 44))), id: \.self) { i in
                        Image(systemName: icons[i].0)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(icons[i].1.gradient))
                    }
                }
                .padding(.horizontal, 14)
                .frame(width: geometry.size.width - 44, height: LiveHarvest.dockTop - 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(isDay ? 0.4 : 0.16)))
                .padding(.bottom, 8)
                SpriteView(scene: harvest.scene, options: [.allowsTransparency])
            }
            .onAppear { harvest.layout(size: geometry.size, regrow: true) }
            .onChange(of: geometry.size) { harvest.layout(size: $0, regrow: false) }
            .onChange(of: look) { _ in harvest.layout(size: geometry.size, regrow: true) }
            // A new theme grows in as the old one fades, as on the Dock.
            .onChange(of: model.theme) { _ in
                harvest.scene.crossfadeNextHarvest = true
                harvest.layout(size: geometry.size, regrow: true)
            }
            // Same harvest, redrawn in the new colors.
            .onChange(of: model.appearance) { _ in harvest.scene.repaint() }
            .animation(.easeInOut(duration: 0.8), value: isDay)
            .animation(.easeInOut(duration: 0.8), value: model.theme)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}


// MARK: - Customize

struct CustomizePage: View {
    @ObservedObject var model: AppModel
    /// The theme whose options are showing: the one on the Dock, unless another one is picked above.
    @State private var picked: Settings.Theme?
    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 14)]

    private var theme: Settings.Theme { picked ?? model.theme }

    /// The symbol and color of the theme's vine row, and of its extras row.
    private var vineMark: (symbol: String, color: Color) {
        switch theme {
        case .fall: return ("laurel.leading", .harvestGreen)
        case .halloween: return ("mountain.2.fill", .purple)
        case .diwali: return ("camera.macro", .orange)
        }
    }

    private var extrasMark: (symbol: String, color: Color) {
        switch theme {
        case .fall: return ("basket.fill", .harvestMustard)
        case .halloween: return ("theatermasks.fill", .purple)
        case .diwali: return ("gift.fill", .pink)
        }
    }

    private var extrasHint: String {
        switch theme {
        case .fall: return "Click to switch each one on or off. On the Dock, click the hay bales, leaf piles, the latte and the lantern."
        case .halloween: return "Click to switch each one on or off. On the Dock, click the jack-o'-lanterns, the cat, the cauldron and the candles."
        case .diwali: return "Click to switch each one on or off. On the Dock, click the diyas, the crackers and the sweets."
        }
    }

    var body: some View {
        PageLayout(title: "Customize") {
            if Settings.Theme.allCases.count > 1 {
                HStack(spacing: 10) {
                    Text("Theme").foregroundStyle(.secondary)
                    // A drop-down menu, with room for many seasons and festivals.
                    Picker("Theme", selection: Binding(get: { theme }, set: { new in withAnimation(.easeInOut(duration: 0.25)) { picked = new } })) {
                        ForEach(Settings.Theme.Kind.allCases, id: \.self) { kind in
                            Section(kind.title) {
                                ForEach(Settings.Theme.allCases.filter { $0.kind == kind }, id: \.self) {
                                    Label($0.title, systemImage: $0.symbol).tag($0)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("customize-theme")
                    if theme != model.theme {
                        Text("Not on your Dock right now.").font(.callout).foregroundStyle(.secondary)
                        Button("Show \(theme.title)") { model.themeChoice = .keep(theme) }
                    }
                    Spacer(minLength: 0)
                }
            }

            HeroCard(eyebrow: theme.title, title: theme.headline,
                     subtitle: "Pick what grows on your Dock. Changes show up right away.", height: 240) {
                Image(nsImage: ThemePreview.image(for: theme))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(theme)
                    .transition(.opacity)
            }

            Card(title: "On Your Dock") {
                SettingRow(symbol: vineMark.symbol, color: vineMark.color, title: theme.vineTitle, detail: theme.vineDetail) {
                    Toggle("", isOn: $model.showVines).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                switch theme {
                case .fall:
                    fallingLeaves
                case .halloween:
                    SettingRow(symbol: "moon.stars.fill", color: .harvestNight, title: "Bats",
                               detail: "A bat fluttering past now and then, and one hiding in each jack-o'-lantern.") {
                        Toggle("", isOn: $model.bats).labelsHidden().toggleStyle(.switch)
                    }
                case .diwali:
                    SettingRow(symbol: "sparkles", color: Settings.Theme.diwali.color, title: "Fireworks",
                               detail: "Little fireworks bursting in the sky now and then. Click a diya to send one up yourself.") {
                        Toggle("", isOn: $model.fireworks).labelsHidden().toggleStyle(.switch)
                    }
                }
                Divider()
                SettingRow(symbol: extrasMark.symbol, color: extrasMark.color, title: theme.extrasTitle, detail: theme.extrasDetail) {
                    Toggle("", isOn: $model.cozyExtras).labelsHidden().toggleStyle(.switch)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Extras").font(.title3.weight(.bold))
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(theme.extras, id: \.self) { kind in
                        ExtraTile(image: ExtraArt.image(for: kind), title: kind.title, isOn: model.enabledExtras.contains(kind)) {
                            model.setExtra(kind, enabled: !model.enabledExtras.contains(kind))
                        }
                    }
                    switch theme {
                    case .fall:
                        ExtraTile(image: ExtraArt.squirrel(), title: theme.visitorTitle, isOn: model.squirrel) { model.squirrel.toggle() }
                    case .halloween:
                        ExtraTile(image: ExtraArt.ghost(), title: theme.visitorTitle, isOn: model.ghost) { model.ghost.toggle() }
                    case .diwali:
                        ExtraTile(image: ExtraArt.peacock(), title: theme.visitorTitle, isOn: model.peacock) { model.peacock.toggle() }
                    }
                }
                .id(theme)
                .disabled(!model.cozyExtras)
                .opacity(model.cozyExtras ? 1 : 0.45)
                Text(!model.cozyExtras ? "Switch on \(theme.extrasTitle) to pick them." : extrasHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // A new theme on the Dock (picked elsewhere, or by the calendar) shows its own options.
        .onChange(of: model.theme) { _ in picked = nil }
    }

    /// Fall's falling leaves, with how many and whether they fill the screen.
    private var fallingLeaves: some View {
        Group {
            SettingRow(symbol: "leaf.fill", color: .harvestRust, title: "Falling leaves",
                       detail: "A leaf drifting down now and then.") {
                Toggle("", isOn: $model.fallingLeaves.animation(.easeInOut(duration: 0.25))).labelsHidden().toggleStyle(.switch)
            }
            if model.fallingLeaves {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                    SettingRow(symbol: "slider.horizontal.3", color: .harvestRust, title: "Amount",
                               detail: "How many leaves fall, from a few to lots.") {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf").font(.caption).foregroundStyle(.secondary)
                            MiddleMarkedSlider(value: $model.leafAmount)
                                .accessibilityLabel("Amount of falling leaves")
                                // A small mark under the middle of the track, where the usual amount is.
                                .overlay(alignment: .bottom) {
                                    Capsule()
                                        .fill(.secondary)
                                        .frame(width: 2, height: 5)
                                        .offset(y: 4)
                                }
                            Image(systemName: "leaf.fill").foregroundStyle(.secondary)
                        }
                        .frame(width: 190)
                    }
                    Divider()
                    SettingRow(symbol: "rectangle.inset.filled", color: .harvestRust, title: "Fill the whole screen",
                               detail: "Leaves drift down across the screen the Dock is on, not just above the Dock.") {
                        Toggle("", isOn: $model.leavesFillScreen).labelsHidden().toggleStyle(.switch)
                    }
                }
                .padding(.leading, 40)
            }
        }
    }
}

/// A picture card for one of the extras that switches it on or off.
struct ExtraTile: View {
    var image: NSImage
    var title: String
    var isOn: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 54)
                    .saturation(isOn ? 1 : 0)
                    .opacity(isOn ? 1 : 0.45)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardFill)
                .brightness(hovering ? 0.03 : 0))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.pumpkin, lineWidth: isOn ? 2 : 0))
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white, Color.pumpkin)
                        .padding(8)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

enum ExtraArt {
    private static var cache: [String: NSImage] = [:]

    static func image(for kind: DecorKind) -> NSImage {
        let key = "\(kind.rawValue)-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let unit: CGFloat = 60
        let size = CozyArt.size(of: kind, unit: unit)
        let texture: SKTexture
        switch kind.theme {
        case .fall: texture = CozyArt.texture(kind, unit: unit, variant: 1, scale: 2)
        case .halloween: texture = SpookyArt.tile(kind, unit: unit, scale: 2)
        case .diwali: texture = DiwaliArt.tile(kind, unit: unit, scale: 2)
        }
        let image = NSImage(cgImage: texture.cgImage(), size: size)
        cache[key] = image
        return image
    }

    /// The theme's own pumpkin (or lamp), for the Theme card.
    static func themeImage(_ theme: Settings.Theme) -> NSImage {
        switch theme {
        case .fall: return pumpkin()
        case .halloween: return jackOLantern()
        case .diwali: return diya()
        }
    }

    /// The theme's visitor, for the Customize card.
    static func visitor(_ theme: Settings.Theme) -> NSImage {
        switch theme {
        case .fall: return squirrel()
        case .halloween: return ghost()
        case .diwali: return peacock()
        }
    }

    /// A lit diya, for Diwali.
    static func diya() -> NSImage {
        let key = "diya-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let height: CGFloat = 100
        let image = NSImage(cgImage: DiwaliArt.litLamp(.diyaPink, height: height, scale: 2).cgImage(),
                            size: DiwaliArt.litLampSize(.diyaPink, height: height))
        cache[key] = image
        return image
    }

    /// The peacock with its tail fanned out, for Diwali.
    static func peacock() -> NSImage {
        let key = "peacock-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let unit: CGFloat = 60
        let body = DiwaliArt.peacockSize(unit: unit), fan = DiwaliArt.fanSize(unit: unit)
        // The fan rises behind the bird from its rump, so the picture is as wide as the fan and tall enough for both.
        let rump = CGPoint(x: DiwaliArt.peacockRump.x * body.width, y: DiwaliArt.peacockRump.y * body.height)
        let fanOrigin = CGPoint(x: rump.x - fan.width / 2, y: rump.y - fan.height * DiwaliArt.fanPivot)
        let minX = min(0, fanOrigin.x), maxX = max(body.width, fanOrigin.x + fan.width)
        let size = CGSize(width: (maxX - minX).rounded(), height: max(body.height, fanOrigin.y + fan.height).rounded())
        let texture = TextureMaker.make(size: size, scale: 2) { ctx in
            ctx.draw(DiwaliArt.fanTexture(unit: unit, scale: 2).cgImage(),
                     in: CGRect(origin: CGPoint(x: fanOrigin.x - minX, y: fanOrigin.y), size: fan))
            ctx.draw(DiwaliArt.peacockTexture(unit: unit, scale: 2).cgImage(), in: CGRect(origin: CGPoint(x: -minX, y: 0), size: body))
        }
        let image = NSImage(cgImage: texture.cgImage(), size: size)
        cache[key] = image
        return image
    }

    static func ghost() -> NSImage {
        let key = "ghost-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let unit: CGFloat = 60
        let image = NSImage(cgImage: SpookyArt.ghostTexture(unit: unit, scale: 2).cgImage(), size: SpookyArt.ghostSize(unit: unit))
        cache[key] = image
        return image
    }

    static func pumpkin() -> NSImage {
        let key = "pumpkin-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let height: CGFloat = 80
        let texture = PumpkinArt.texture(kind: .roundOrange, height: height, variant: 1, scale: 2)
        let image = NSImage(cgImage: texture.cgImage(), size: PumpkinArt.size(of: .roundOrange, height: height))
        cache[key] = image
        return image
    }

    /// A glowing jack-o'-lantern, for Halloween.
    static func jackOLantern() -> NSImage {
        let key = "jackOLantern-\(Palette.appearance)"
        if let image = cache[key] { return image }
        let height: CGFloat = 80
        let size = PumpkinArt.size(of: .roundOrange, height: height)
        let texture = TextureMaker.make(size: size, scale: 2) { ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.draw(PumpkinArt.texture(kind: .roundOrange, height: height, variant: 1, scale: 2).cgImage(), in: rect)
            ctx.draw(SpookyArt.faceTexture(kind: .roundOrange, height: height, face: 0, scale: 2).cgImage(), in: rect)
        }
        let image = NSImage(cgImage: texture.cgImage(), size: size)
        cache[key] = image
        return image
    }

    /// The menu bar icon for a theme: Fall's pumpkin, Halloween's jack-o'-lantern or Diwali's diya.
    static func menuBarIcon(_ theme: Settings.Theme) -> NSImage {
        switch theme {
        case .fall: return menuBarPumpkin()
        case .halloween: return menuBarJackOLantern()
        case .diwali: return menuBarDiya()
        }
    }

    /// A menu bar icon, 20 by 18 points, drawn in black. It's a template image, so macOS draws it white
    /// on a dark menu bar (and dark on a light one), like the system's own menu bar icons.
    private static func menuBarTemplate(_ key: String, draw: @escaping (CGContext) -> Void) -> NSImage {
        if let image = cache[key] { return image }
        let image = NSImage(size: CGSize(width: 20, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(.black)
            draw(ctx)
            return true
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }

    /// The menu bar pumpkin's body and stem.
    private static func fillMenuBarPumpkin(_ ctx: CGContext) {
        // Three overlapping lobes for the body.
        ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 10.5, height: 13))
        ctx.fillEllipse(in: CGRect(x: 8.5, y: 1, width: 10.5, height: 13))
        ctx.fillEllipse(in: CGRect(x: 5, y: 0.5, width: 10, height: 14))
        // A chunky stem leaning a little to the right.
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 9, y: 13))
        ctx.addLine(to: CGPoint(x: 11.2, y: 13))
        ctx.addLine(to: CGPoint(x: 12.4, y: 17.2))
        ctx.addLine(to: CGPoint(x: 10.4, y: 17.6))
        ctx.closePath()
        ctx.fillPath()
    }

    /// A plain pumpkin silhouette for the menu bar, for Fall.
    static func menuBarPumpkin() -> NSImage {
        menuBarTemplate("menuBarPumpkin") { ctx in
            ExtraArt.fillMenuBarPumpkin(ctx)
            // Rib lines cut out of the body, so they show as gaps.
            ctx.setBlendMode(.clear)
            ctx.setLineWidth(1.2)
            ctx.setLineCap(.round)
            for (x, bulge) in [(7.6, -1.6), (12.4, 1.6)] {
                ctx.beginPath()
                ctx.move(to: CGPoint(x: x, y: 12.2))
                ctx.addQuadCurve(to: CGPoint(x: x, y: 2), control: CGPoint(x: x + bulge, y: 7.1))
                ctx.strokePath()
            }
        }
    }

    /// The same pumpkin with a carved face, for Halloween.
    static func menuBarJackOLantern() -> NSImage {
        menuBarTemplate("menuBarJackOLantern") { ctx in
            ExtraArt.fillMenuBarPumpkin(ctx)
            // The face is cut out of it: pointed eyes, a little nose and a wide grin.
            ctx.setBlendMode(.clear)
            func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) {
                ctx.beginPath()
                ctx.addLines(between: [a, b, c])
                ctx.closePath()
                ctx.fillPath()
            }
            for x in [4.8, 11.8] as [CGFloat] {
                triangle(CGPoint(x: x, y: 8.4), CGPoint(x: x + 3.4, y: 8.4), CGPoint(x: x + 1.7, y: 11.4))
            }
            triangle(CGPoint(x: 9.1, y: 6.5), CGPoint(x: 10.9, y: 6.5), CGPoint(x: 10, y: 7.9))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4.2, y: 5.6))
            ctx.addQuadCurve(to: CGPoint(x: 15.8, y: 5.6), control: CGPoint(x: 10, y: 3.4))
            ctx.addQuadCurve(to: CGPoint(x: 4.2, y: 5.6), control: CGPoint(x: 10, y: -0.6))
            ctx.fillPath()
            // Two teeth left in the grin, one up and one down.
            ctx.setBlendMode(.normal)
            ctx.fill(CGRect(x: 7.4, y: 3.7, width: 1.4, height: 1.6))
            ctx.fill(CGRect(x: 11.2, y: 2, width: 1.4, height: 1.6))
        }
    }

    /// A lit diya, for Diwali: a round clay lamp with its spout up to the right and a flame on it.
    static func menuBarDiya() -> NSImage {
        menuBarTemplate("menuBarDiya") { ctx in
            // The bowl, curving down from its rim and up into the pinched spout.
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0.8, y: 8.4))
            ctx.addCurve(to: CGPoint(x: 8.4, y: 1.4), control1: CGPoint(x: 1, y: 4.4), control2: CGPoint(x: 4.2, y: 1.4))
            ctx.addCurve(to: CGPoint(x: 14.6, y: 4.6), control1: CGPoint(x: 11.4, y: 1.4), control2: CGPoint(x: 13.4, y: 2.6))
            ctx.addQuadCurve(to: CGPoint(x: 17.8, y: 9.8), control: CGPoint(x: 16.6, y: 6.6))
            ctx.addQuadCurve(to: CGPoint(x: 13.6, y: 8.6), control: CGPoint(x: 15.4, y: 8.6))
            ctx.closePath()
            ctx.fillPath()
            // Its little foot.
            ctx.fillEllipse(in: CGRect(x: 5.8, y: 0.2, width: 5.4, height: 2.2))
            // The flame, standing on the spout.
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 17, y: 17.7))
            ctx.addQuadCurve(to: CGPoint(x: 17.6, y: 10.5), control: CGPoint(x: 20.6, y: 12.2))
            ctx.addQuadCurve(to: CGPoint(x: 17, y: 17.7), control: CGPoint(x: 14.2, y: 12.2))
            ctx.fillPath()
            // A line cut just under the rim, like the pumpkin's ribs.
            ctx.setBlendMode(.clear)
            ctx.setLineWidth(0.9)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 2.2, y: 7))
            ctx.addLine(to: CGPoint(x: 13.2, y: 7.2))
            ctx.strokePath()
        }
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
        case .halloween: image = halloween()
        case .diwali: image = diwali()
        }
        cache[key] = image
        return image
    }

    /// The flat sky at the top of a theme's preview, to give the picture more room above.
    static func sky(for theme: Settings.Theme) -> Color {
        switch theme {
        case .fall: return Color(cgColor: Palette.plum.mixed(with: Palette.rust, 0.18))
        case .halloween: return Color(cgColor: Palette.night)
        case .diwali: return Color(cgColor: diwaliSky)
        }
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

    private static func halloween() -> NSImage {
        let size = CGSize(width: 520, height: 170)
        let scale: CGFloat = 2
        let h: CGFloat = 62
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            // A night sky with stars, a big moon and bats.
            ctx.setFillColor(Palette.night)
            ctx.fill(CGRect(origin: .zero, size: size))
            var rng = SeededRandom(seed: 31)
            ctx.setFillColor(Palette.ghost.withAlpha(0.7))
            for _ in 0..<26 {
                let r = rng.float(0.6...1.4)
                ctx.fillEllipse(in: CGRect(x: rng.float(0...size.width), y: rng.float(70...size.height), width: r * 2, height: r * 2))
            }
            ctx.setFillColor(Palette.ghost.mixed(with: Palette.mustard, 0.25))
            ctx.fillEllipse(in: CGRect(x: 420, y: 100, width: 52, height: 52))
            ctx.setFillColor(Palette.ghost.mixed(with: Palette.stone, 0.35))
            ctx.fillEllipse(in: CGRect(x: 436, y: 124, width: 9, height: 8))
            ctx.fillEllipse(in: CGRect(x: 452, y: 112, width: 6, height: 5))
            for (x, y, frame) in [(330.0, 128.0, 0), (372.0, 146.0, 1), (238.0, 140.0, 1)] {
                let bat = SpookyArt.batSize(unit: h * 0.7)
                ctx.draw(SpookyArt.batTexture(frame: frame, unit: h * 0.7, scale: scale).cgImage(),
                         in: CGRect(x: CGFloat(x), y: CGFloat(y), width: bat.width, height: bat.height))
            }
            // A Dock that stops short of the edges, with a cobweb in each top corner.
            let shelf: CGFloat = 24
            let dock = CGRect(x: 30, y: 0, width: size.width - 60, height: shelf)
            ctx.setFillColor(Palette.soot.mixed(with: Palette.plum, 0.4))
            ctx.fill(dock)

            let k = h / 60
            let dirtHeight = (h * 0.3).rounded()
            ctx.draw(SpookyArt.dirtTexture(width: dock.width, height: dirtHeight, seed: 11, unit: k, scale: scale).cgImage(),
                     in: CGRect(x: dock.minX, y: shelf - 6, width: dock.width, height: dirtHeight))

            // Hanging from each top corner, fanning down and in across the end of the Dock.
            let web = CGSize(width: shelf, height: shelf)
            let webTexture = SpookyArt.cobwebTexture(size: web, scale: scale).cgImage()
            ctx.draw(webTexture, in: CGRect(origin: CGPoint(x: dock.minX, y: shelf - web.height), size: web))
            ctx.saveGState()
            ctx.translateBy(x: dock.maxX, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.draw(webTexture, in: CGRect(origin: CGPoint(x: 0, y: shelf - web.height), size: web))
            ctx.restoreGState()

            enum Item { case lantern(PumpkinKind, CGFloat, Int), pumpkin(PumpkinKind, CGFloat), decor(DecorKind), crypt(PumpkinKind) }
            let items: [Item] = [.lantern(.roundOrange, 1, 0), .decor(.tombstone), .pumpkin(.ghostWhite, 0.8), .decor(.cauldron),
                                 .crypt(.squatOrange), .decor(.skull), .lantern(.tallOrange, 0.95, 3), .decor(.candles),
                                 .lantern(.roundOrange, 0.86, 1)]
            let decorUnit = (h * 0.75).rounded()
            func width(_ item: Item) -> CGFloat {
                switch item {
                case let .lantern(kind, s, _), let .pumpkin(kind, s): return PumpkinArt.size(of: kind, height: (h * s).rounded()).width
                case let .decor(kind): return CozyArt.size(of: kind, unit: decorUnit).width
                case .crypt: return CozyArt.size(of: .crypt, unit: h).width
                }
            }
            func drawPumpkin(_ kind: PumpkinKind, height: CGFloat, centerX: CGFloat, y: CGFloat, face: Int?) {
                let s = PumpkinArt.size(of: kind, height: height)
                let rect = CGRect(x: centerX - s.width / 2, y: y, width: s.width, height: s.height)
                if face != nil {
                    // The candle's glow around a jack-o'-lantern.
                    let glow = s.width * 1.5
                    ctx.draw(CozyArt.glowTexture(color: Palette.orange.mixed(with: Palette.mustard, 0.5), diameter: glow, scale: scale).cgImage(),
                             in: CGRect(x: centerX - glow / 2, y: y + s.height * 0.42 - glow / 2, width: glow, height: glow))
                }
                ctx.draw(PumpkinArt.texture(kind: kind, height: height, variant: 1, scale: scale).cgImage(), in: rect)
                if let face {
                    ctx.draw(SpookyArt.faceTexture(kind: kind, height: height, face: face, scale: scale).cgImage(), in: rect)
                }
            }
            let used = items.map(width).reduce(0, +)
            let space = max(2, (dock.width - used) / CGFloat(items.count + 1))
            var x = dock.minX + space
            for item in items {
                let w = width(item)
                let center = x + w / 2
                switch item {
                case let .lantern(kind, s, face):
                    drawPumpkin(kind, height: (h * s).rounded(), centerX: center, y: shelf - 3, face: face)
                case let .pumpkin(kind, s):
                    drawPumpkin(kind, height: (h * s).rounded(), centerX: center, y: shelf - 3, face: nil)
                case let .decor(kind):
                    let s = CozyArt.size(of: kind, unit: decorUnit)
                    ctx.draw(SpookyArt.tile(kind, unit: decorUnit, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 2, width: s.width, height: s.height))
                case let .crypt(kind):
                    let s = CozyArt.size(of: .crypt, unit: h)
                    ctx.draw(CozyArt.texture(.crypt, unit: h, variant: 2, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 3, width: s.width, height: s.height))
                    drawPumpkin(kind, height: (h * 0.78).rounded(), centerX: center, y: shelf - 3 + s.height * 0.86, face: 3)
                }
                x += w + space
            }
            // The ghost, floating by.
            let ghost = SpookyArt.ghostSize(unit: h * 0.8)
            ctx.setAlpha(0.92)
            ctx.draw(SpookyArt.ghostTexture(unit: h * 0.8, scale: scale).cgImage(), in: CGRect(x: 300, y: 86, width: ghost.width, height: ghost.height))
            ctx.setAlpha(1)
        }
        return NSImage(cgImage: texture.cgImage(), size: size)
    }

    /// Diwali's dark, moonless night sky.
    private static var diwaliSky: CGColor { Palette.night.mixed(with: Palette.royal, 0.2).mixed(with: Palette.soot, 0.3) }

    private static func diwali() -> NSImage {
        let size = CGSize(width: 520, height: 170)
        let scale: CGFloat = 2
        let h: CGFloat = 62
        let texture = TextureMaker.make(size: size, scale: scale) { ctx in
            // A moonless night full of fireworks, with a kandil hanging at each side.
            ctx.setFillColor(diwaliSky)
            ctx.fill(CGRect(origin: .zero, size: size))
            var rng = SeededRandom(seed: 47)
            ctx.setFillColor(Palette.ghost.withAlpha(0.6))
            for _ in 0..<18 {
                let r = rng.float(0.5...1.2)
                ctx.fillEllipse(in: CGRect(x: rng.float(0...size.width), y: rng.float(80...size.height), width: r * 2, height: r * 2))
            }
            DiwaliArt.drawFirework(ctx, center: CGPoint(x: 150, y: 128), radius: 26, colors: [Palette.magenta, Palette.marigold], seed: 1)
            DiwaliArt.drawFirework(ctx, center: CGPoint(x: 268, y: 146), radius: 16, colors: [Palette.teal, Palette.candlelight], rays: 12, seed: 2)
            DiwaliArt.drawFirework(ctx, center: CGPoint(x: 384, y: 120), radius: 30, colors: [Palette.marigold, Palette.candyPink, Palette.slime], seed: 3)
            let kandil = DiwaliArt.kandilSize(unit: h * 0.85)
            for x in [52, 468] as [CGFloat] {
                let top = size.height - 6
                ctx.setFillColor(Palette.soot.mixed(with: Palette.ghost, 0.3))
                ctx.fill(CGRect(x: x - 0.5, y: top, width: 1, height: 6))
                let glow = kandil.width * 1.8
                ctx.draw(CozyArt.glowTexture(color: Palette.marigold, diameter: glow, scale: scale).cgImage(),
                         in: CGRect(x: x - glow / 2, y: top - kandil.height * 0.4 - glow / 2, width: glow, height: glow))
                ctx.draw(DiwaliArt.kandilTexture(unit: h * 0.85, scale: scale).cgImage(),
                         in: CGRect(x: x - kandil.width / 2, y: top - kandil.height, width: kandil.width, height: kandil.height))
            }

            // A Dock that stops short of the edges, with the garland along it and strings of marigolds at its ends.
            let shelf: CGFloat = 24
            let dock = CGRect(x: 30, y: 0, width: size.width - 60, height: shelf)
            ctx.setFillColor(Palette.soot.mixed(with: Palette.plum, 0.45))
            ctx.fill(dock)
            let k = h / 60
            let garlandHeight = (h * 0.34).rounded()
            ctx.draw(DiwaliArt.garlandTexture(width: dock.width, height: garlandHeight, seed: 5, unit: k, scale: scale).cgImage(),
                     in: CGRect(x: dock.minX, y: shelf - 8, width: dock.width, height: garlandHeight))
            let strand = CGSize(width: (shelf * 0.55).rounded(), height: shelf)
            let strandTexture = DiwaliArt.strandTexture(size: strand, scale: scale).cgImage()
            ctx.draw(strandTexture, in: CGRect(origin: CGPoint(x: dock.minX, y: shelf - strand.height), size: strand))
            ctx.saveGState()
            ctx.translateBy(x: dock.maxX, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.draw(strandTexture, in: CGRect(origin: CGPoint(x: 0, y: shelf - strand.height), size: strand))
            ctx.restoreGState()

            enum Item { case lamp(PumpkinKind, CGFloat), decor(DecorKind), boxes(PumpkinKind) }
            let items: [Item] = [.lamp(.diyaClay, 1), .decor(.rangoli), .lamp(.lampStand, 0.95), .decor(.laddoos), .boxes(.diyaBrass),
                                 .decor(.anar), .lamp(.diyaLotus, 0.9), .decor(.mithai), .lamp(.diyaTeal, 1)]
            let decorUnit = (h * 0.75).rounded()
            func width(_ item: Item) -> CGFloat {
                switch item {
                case let .lamp(kind, s): return PumpkinArt.size(of: kind, height: (h * s).rounded()).width
                case let .decor(kind): return CozyArt.size(of: kind, unit: decorUnit).width
                case .boxes: return CozyArt.size(of: .giftBoxes, unit: h).width
                }
            }
            func drawLamp(_ kind: PumpkinKind, height: CGFloat, centerX: CGFloat, y: CGFloat) {
                let s = DiwaliArt.litLampSize(kind, height: height)
                let glow = s.width * (kind == .lampStand ? 2 : 1.3)
                ctx.draw(CozyArt.glowTexture(color: Palette.marigold, diameter: glow, scale: scale).cgImage(),
                         in: CGRect(x: centerX - glow / 2, y: y + s.height * 0.75 - glow / 2, width: glow, height: glow))
                ctx.draw(DiwaliArt.litLamp(kind, height: height, scale: scale).cgImage(),
                         in: CGRect(x: centerX - s.width / 2, y: y, width: s.width, height: s.height))
            }
            let used = items.map(width).reduce(0, +)
            let space = max(2, (dock.width - used) / CGFloat(items.count + 1))
            var x = dock.minX + space
            for item in items {
                let w = width(item)
                let center = x + w / 2
                switch item {
                case let .lamp(kind, s):
                    drawLamp(kind, height: (h * s).rounded(), centerX: center, y: shelf - 3)
                case let .decor(kind):
                    let s = CozyArt.size(of: kind, unit: decorUnit)
                    ctx.draw(DiwaliArt.tile(kind, unit: decorUnit, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 2, width: s.width, height: s.height))
                case let .boxes(kind):
                    let s = CozyArt.size(of: .giftBoxes, unit: h)
                    ctx.draw(CozyArt.texture(.giftBoxes, unit: h, variant: 2, scale: scale).cgImage(),
                             in: CGRect(x: center - s.width / 2, y: shelf - 3, width: s.width, height: s.height))
                    drawLamp(kind, height: (h * 0.78).rounded(), centerX: center, y: shelf - 3 + s.height * 0.86)
                }
                x += w + space
            }
        }
        return NSImage(cgImage: texture.cgImage(), size: size)
    }
}
