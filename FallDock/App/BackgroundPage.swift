import AppKit
import SwiftUI

/// The Background page: sets the desktop picture to go with the theme. Off until switched on. Each
/// theme has a light and a dark picture; the desktop can switch between them with the Dock's Light
/// or Dark look, or keep one of them. The pictures are drawn in WallpaperArt.swift and put on the
/// desktop by WallpaperController.
struct BackgroundPage: View {
    @ObservedObject var model: AppModel

    /// The picture on the desktop now (or that would be, once switched on).
    private var showing: Palette.Appearance {
        switch model.wallpaperMode {
        case .matchDock: return model.appearance
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var matchesDock: Binding<Bool> {
        Binding(get: { model.wallpaperMode == .matchDock },
                // Switching it off keeps the picture that's showing, so nothing jumps.
                set: { model.wallpaperMode = $0 ? .matchDock : (showing == .dark ? .dark : .light) })
    }

    var body: some View {
        PageLayout(title: "Background") {
            HeroCard(eyebrow: model.theme.title, title: "A Desktop to Match",
                     subtitle: "A soft sky and rolling hills behind your Dock, light or dark.", height: 240) {
                Image(nsImage: WallpaperArt.preview(for: model.theme, showing))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }

            Card(title: "Desktop Picture") {
                SettingRow(symbol: "photo.fill", color: .harvestPlum, title: "Match my desktop to the Dock",
                           detail: model.wallpaperEnabled
                               ? "Your desktop shows the \(model.theme.title) picture. Switch this off and your own picture comes back."
                               : "Sets your desktop picture to go with the \(model.theme.title) theme. Your own picture comes back when you switch it off.") {
                    Toggle("", isOn: $model.wallpaperEnabled.animation(.easeInOut(duration: 0.2))).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "circle.lefthalf.filled", color: .harvestRust, title: "Switch with Light and Dark",
                           detail: "The light picture when your Dock is light, and the dark one when it's dark.") {
                    Toggle("", isOn: matchesDock).labelsHidden().toggleStyle(.switch)
                }
                .disabled(!model.wallpaperEnabled)
                .opacity(model.wallpaperEnabled ? 1 : 0.45)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pictures").font(.title3.weight(.bold))
                HStack(spacing: 14) {
                    ForEach([Palette.Appearance.light, .dark], id: \.self) { appearance in
                        WallpaperTile(image: WallpaperArt.preview(for: model.theme, appearance),
                                      title: appearance == .light ? "Light" : "Dark",
                                      detail: detail(for: appearance),
                                      isSelected: showing == appearance) {
                            model.wallpaperMode = appearance == .light ? .light : .dark
                        }
                    }
                }
                .disabled(!model.wallpaperEnabled)
                .opacity(model.wallpaperEnabled ? 1 : 0.45)
                Text(model.wallpaperEnabled
                     ? "Click a picture to keep it, whether your Dock is light or dark."
                     : "Switch on Match my desktop to the Dock to pick one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detail(for appearance: Palette.Appearance) -> String {
        if model.wallpaperMode == .matchDock {
            return showing == appearance ? "Showing now" : "When your Dock is \(appearance == .light ? "light" : "dark")"
        }
        return showing == appearance ? "Always" : ""
    }
}

/// One of the theme's two pictures, picked by clicking it.
private struct WallpaperTile: View {
    var image: NSImage
    var title: String
    var detail: String
    var isSelected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardFill)
                .brightness(hovering ? 0.03 : 0))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.pumpkin, lineWidth: isSelected ? 2 : 0))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white, Color.pumpkin)
                        .padding(18)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title) picture")
        .accessibilityIdentifier("wallpaper-\(title.lowercased())")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
