import AppKit
import Combine
import SpriteKit
import SwiftUI

// The building blocks of the app window (see MainView.swift) and its Customize tab, in the harvest-wagon colors:
// a live little harvest to play with, cards with colored badges, and picture tiles.

/// The window's own colors: the dark wagon colors, whatever the Dock art is using.
extension Color {
    static let pumpkin = Color(cgColor: .hex(0xEB6C15))
    static let harvestPlum = Color(cgColor: .hex(0x5D1C2B))
    static let harvestRust = Color(cgColor: .hex(0xA24B22))
    static let harvestMustard = Color(cgColor: .hex(0xDB9D24))
    static let harvestPeach = Color(cgColor: .hex(0xFCDCBE))
    static let harvestGreen = Color(cgColor: .hex(0x627329))
    static let harvestNight = Color(cgColor: .hex(0x2E2140))
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
         model.appearance, model.theme, model.bats, model.ghost]
    }

    private let icons: [(String, Color)] = [
        ("face.smiling", .blue), ("globe", .teal), ("envelope.fill", .indigo), ("music.note", .pink),
        ("photo.fill", .orange), ("message.fill", .green), ("calendar", .red), ("note.text", .yellow),
        ("gearshape.fill", .gray), ("folder.fill", .cyan),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // An evening sky with a harvest moon (a night sky and a pale moon at Halloween).
                LinearGradient(colors: model.theme == .halloween ? [Color.harvestNight, Color.harvestPlum.opacity(0.9)]
                                                                 : [Color.harvestPlum, Color.harvestRust.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(model.theme == .halloween ? Color(cgColor: .hex(0xF1EADF)).opacity(0.9) : Color.harvestMustard.opacity(0.85))
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

// MARK: - The season's tab

struct ThemeTab: View {
    @ObservedObject var model: AppModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        let theme = model.theme
        let halloween = theme == .halloween
        VStack(spacing: 14) {
            Image(nsImage: ThemePreview.image(for: theme))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.title)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                        Text(theme.subtitle)
                            .font(.callout.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(Color.harvestPeach)
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                ActionTile(symbol: halloween ? "mountain.2.fill" : "laurel.leading", title: theme.vineTitle,
                           detail: model.showVines ? theme.vineDetail : "Off", isOn: model.showVines) { model.showVines.toggle() }
                if halloween {
                    ActionTile(symbol: "bird.fill", title: theme.ambientTitle, detail: model.bats ? theme.ambientDetail : "Off",
                               isOn: model.bats) { model.bats.toggle() }
                } else {
                    ActionTile(symbol: "leaf.fill", title: theme.ambientTitle, detail: model.fallingLeaves ? theme.ambientDetail : "Off",
                               isOn: model.fallingLeaves) { model.fallingLeaves.toggle() }
                }
                ActionTile(symbol: halloween ? "theatermasks.fill" : "basket.fill", title: theme.extrasTitle,
                           detail: model.cozyExtras ? "Between the pumpkins" : "Off", isOn: model.cozyExtras) { model.cozyExtras.toggle() }
            }

            Card(title: "Pick your extras") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(theme.extras, id: \.self) { kind in
                        ExtraTile(image: ExtraArt.image(for: kind), title: kind.title, isOn: model.enabledExtras.contains(kind)) {
                            model.setExtra(kind, enabled: !model.enabledExtras.contains(kind))
                        }
                    }
                    if halloween {
                        ExtraTile(image: ExtraArt.ghost(), title: theme.visitorTitle, isOn: model.ghost) { model.ghost.toggle() }
                    } else {
                        ExtraTile(image: ExtraArt.squirrel(), title: theme.visitorTitle, isOn: model.squirrel) { model.squirrel.toggle() }
                    }
                }
                .disabled(!model.cozyExtras)
                .opacity(model.cozyExtras ? 1 : 0.45)
                Text(halloween
                     ? "Tap to switch each one on or off. On the Dock, click a tombstone and a zombie hand reaches out of the dirt. Click the cat, the cauldron, the candy, the candles, the crypt pedestals and the skull too, and smash a jack-o'-lantern to free its bat. Point at the ghost to spook it."
                     : "Tap to switch each one on or off. On the Dock, click the leaf piles, the latte and the lantern.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
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
        let texture = kind.isSpooky ? SpookyArt.tile(kind, unit: unit, scale: 2) : CozyArt.texture(kind, unit: unit, variant: 1, scale: 2)
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
            let shelf: CGFloat = 24
            ctx.setFillColor(Palette.soot.mixed(with: Palette.plum, 0.4))
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: shelf))

            let k = h / 60
            let dirtHeight = (h * 0.3).rounded()
            ctx.draw(SpookyArt.dirtTexture(width: size.width, height: dirtHeight, seed: 11, unit: k, scale: scale).cgImage(),
                     in: CGRect(x: 0, y: shelf - 6, width: size.width, height: dirtHeight))
            let web = CGSize(width: h * 0.7, height: h * 0.7)
            ctx.draw(SpookyArt.cobwebTexture(size: web, scale: scale).cgImage(), in: CGRect(origin: CGPoint(x: 2, y: shelf - 3), size: web))

            enum Item { case lantern(PumpkinKind, CGFloat, Int), pumpkin(PumpkinKind, CGFloat), decor(DecorKind), crypt(PumpkinKind) }
            let items: [Item] = [.lantern(.roundOrange, 1, 0), .decor(.tombstone), .pumpkin(.ghostWhite, 0.8), .decor(.cauldron),
                                 .crypt(.squatOrange), .decor(.skull), .lantern(.tallOrange, 0.95, 3), .decor(.candles),
                                 .lantern(.roundOrange, 0.86, 1), .decor(.candy)]
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
                if let face {
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
            let space = (size.width - used) / CGFloat(items.count + 1)
            var x = space
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
}
