import SwiftUI

/// The Themes page: which theme is on the Dock. Fall (the original) or Halloween all year, or
/// changing with the calendar: Halloween for its fortnight, Fall the rest of the year.
struct ThemesPage: View {
    @ObservedObject var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 300), spacing: 20)]

    private var followsCalendar: Binding<Bool> {
        Binding(get: { model.themeChoice == .calendar },
                // Switching it off keeps the theme that's on, so nothing jumps.
                set: { on in choose(on ? .calendar : .keep(model.theme)) })
    }

    private func choose(_ choice: Settings.ThemeChoice) {
        withAnimation(.easeInOut(duration: 0.35)) { model.themeChoice = choice }
    }

    var body: some View {
        PageLayout(title: "Themes") {
            HeroCard(eyebrow: "On your Dock now", title: model.theme.title,
                     subtitle: ThemeSchedule.summary(model.themeChoice), height: 240) {
                Image(nsImage: ThemePreview.image(for: model.theme))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(model.theme)
                    .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pick a Theme").font(.title3.weight(.bold))
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Settings.Theme.allCases, id: \.self) { theme in
                        ThemeTile(theme: theme, isPicked: model.themeChoice == .keep(theme),
                                  isOnNow: model.theme == theme) { choose(.keep(theme)) }
                    }
                }
            }

            Card(title: "Change Automatically") {
                SettingRow(symbol: "calendar", color: .pumpkin, title: "Change with the calendar",
                           detail: "Halloween from \(ThemeSchedule.window(.halloween)), and Fall the rest of the year.") {
                    Toggle("", isOn: followsCalendar).labelsHidden().toggleStyle(.switch)
                }
                if let next = model.themeChoice.next(after: Date()) {
                    Divider()
                    SettingRow(symbol: next.theme.symbol, color: .harvestNight, title: "Next up",
                               detail: "\(next.theme.title) on \(ThemeSchedule.day(next.date)). The harvest changes by itself.") {
                        EmptyView()
                    }
                }
            }
        }
    }
}

/// A theme as a picture card. Picking it keeps it on the Dock all year.
struct ThemeTile: View {
    var theme: Settings.Theme
    /// Kept on the Dock all year.
    var isPicked: Bool
    /// On the Dock now (picked, or put there by the calendar).
    var isOnNow: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Image(nsImage: ThemePreview.image(for: theme))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if theme == .fall {
                            Text("THE ORIGINAL")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.black.opacity(0.45)))
                                .padding(10)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isOnNow {
                            Label("On your Dock", systemImage: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(isPicked ? Color.pumpkin : Color.black.opacity(0.45)))
                                .padding(10)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.system(size: 15, weight: .semibold))
                    Text(theme.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardFill)
                .brightness(hovering ? 0.03 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.pumpkin, lineWidth: isPicked ? 2.5 : 0))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .help("Keep \(theme.title) on your Dock all year")
        .accessibilityLabel("\(theme.title) theme")
        .accessibilityIdentifier("theme-\(theme.rawValue)")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// Words for which theme is on and when it changes.
enum ThemeSchedule {
    /// "Oct 15".
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// When the calendar puts a theme on the Dock, like "Oct 15 to Nov 1".
    static func window(_ theme: Settings.Theme) -> String {
        guard let window = theme.window else { return "all year" }
        func date(_ md: (month: Int, day: Int)) -> String {
            day(Calendar.current.date(from: DateComponents(year: 2001, month: md.month, day: md.day)) ?? Date())
        }
        return "\(date(window.start)) to \(date(window.end))"
    }

    /// "Fall stays on your Dock all year." or "Halloween now, then Fall on Nov 2."
    static func summary(_ choice: Settings.ThemeChoice, now: Date = Date()) -> String {
        let theme = choice.theme(on: now)
        guard let next = choice.next(after: now) else { return "\(theme.title) stays on your Dock all year." }
        return "\(theme.title) now, then \(next.theme.title) on \(day(next.date)), with the calendar."
    }
}
