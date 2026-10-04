import AppKit
import SwiftUI

// The app window: three tabs at the top, like the settings of most Mac utilities.
// Home answers "is it on?" and "which theme?", Customize picks what grows, and Settings holds
// everything else. The building blocks (cards, tiles, the live harvest) and the Customize page
// are in MainTabs.swift.

enum Page: String, CaseIterable, Identifiable {
    case home, customize, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .customize: return "Customize"
        case .settings: return "Settings"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @AppStorage("mainWindowPage") private var pageName = Page.home.rawValue

    private var page: Binding<Page> {
        Binding(get: { Page(rawValue: pageName) ?? .home }, set: { pageName = $0.rawValue })
    }

    var body: some View {
        VStack(spacing: 0) {
            // In the title bar, between the window's buttons and the edge.
            Picker("", selection: page) {
                ForEach(Page.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            Divider()
            ScrollView {
                Group {
                    switch page.wrappedValue {
                    case .home: HomePage(model: model) { pageName = Page.customize.rawValue }
                    case .customize: ThemeTab(model: model)
                    case .settings: SettingsPage(model: model)
                    }
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .id(page.wrappedValue)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.pumpkin)
        .frame(minWidth: 620, minHeight: 560)
    }
}

// MARK: - Home

struct HomePage: View {
    @ObservedObject var model: AppModel
    var openCustomize: () -> Void

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            LiveHarvestView(model: model, height: 220)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                        Text(model.theme == .halloween ? "Something spooky is growing on your Dock. Try clicking things!"
                                                       : "The harvest is in on your Dock. Try clicking things!")
                            .font(.callout.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .padding(18)
                }
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            OnOffCard(model: model)
            ThemeCard(model: model, openCustomize: openCustomize)
        }
        .padding(24)
    }
}

/// Is the harvest on the Dock? The one switch most people need.
private struct OnOffCard: View {
    @ObservedObject var model: AppModel

    private var isShowing: Bool { model.showPumpkins && !model.isPaused }

    private var status: String {
        if !model.showPumpkins { return "Hidden. Switch it on to bring the harvest back." }
        if model.isPaused { return "Paused for an hour, then it comes back by itself." }
        return model.smashCount > 0 ? "Growing on your Dock · \(model.smashCount) smashed so far" : "Growing on your Dock"
    }

    var body: some View {
        Card(title: nil) {
            SettingRow(symbol: isShowing ? "eye.fill" : "eye.slash.fill", color: isShowing ? .green : .gray,
                       title: "Show on Dock", detail: status) {
                HStack(spacing: 10) {
                    if model.showPumpkins {
                        Button(model.isPaused ? "Resume" : "Pause for an Hour") {
                            withAnimation { model.isPaused ? model.resume() : model.pauseForAnHour() }
                        }
                        Button {
                            model.regrow()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .help("Grow a new harvest")
                        .disabled(model.isPaused)
                    }
                    Toggle("", isOn: $model.showPumpkins.animation()).labelsHidden().toggleStyle(.switch)
                }
            }
        }
    }
}

/// Which theme is on the Dock: pick one, or let it change with the calendar.
private struct ThemeCard: View {
    @ObservedObject var model: AppModel
    var openCustomize: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 190), spacing: 12)]

    private var rotation: Settings.ThemeChoice.Rotation? {
        if case let .rotate(rotation) = model.themeChoice { return rotation }
        return nil
    }

    private var followsCalendar: Binding<Bool> {
        Binding(get: { rotation != nil }, set: { on in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                model.themeChoice = on ? .rotate(.everything) : .keep(model.theme)
            }
        })
    }

    private var summary: String {
        guard rotation != nil else { return "\(model.theme.title) stays on your Dock all year." }
        return ThemeSchedule.next(model.themeChoice).map { "\(model.theme.title) now, then \($0)." }
            ?? "\(model.theme.title) now. More themes are on the way."
    }

    var body: some View {
        Card(title: nil) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme").font(.headline)
                    Text(summary).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Change with the calendar", isOn: followsCalendar)
                    .toggleStyle(.switch)
            }

            if let rotation {
                Picker("", selection: Binding(get: { rotation }, set: { new in withAnimation { model.themeChoice = .rotate(new) } })) {
                    ForEach(Settings.ThemeChoice.Rotation.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Settings.Theme.allCases, id: \.self) { theme in
                    ThemeTile(theme: theme, isOn: model.theme == theme, followsCalendar: rotation != nil,
                              isIncluded: rotation?.themes.contains(theme) ?? true) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { model.themeChoice = .keep(theme) }
                    }
                }
            }

            HStack {
                Text(rotation == nil ? "Click a theme to put it on your Dock." : "Click a theme to keep it on all year instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openCustomize()
                } label: {
                    Label("Customize \(model.theme.title)", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pumpkin)
                .font(.callout.weight(.semibold))
            }
        }
    }
}

/// A theme, as a picture card.
struct ThemeTile: View {
    var theme: Settings.Theme
    /// It's the one on the Dock now.
    var isOn: Bool
    var followsCalendar: Bool
    /// Part of the calendar rotation (always true when keeping one theme).
    var isIncluded: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Image(nsImage: ThemePreview.image(for: theme))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            HStack(spacing: 4) {
                                if followsCalendar { Text("NOW").font(.caption2.weight(.heavy)) }
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.pumpkin))
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Label(theme.title, systemImage: theme.symbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text("\(theme.kind == .festival ? "Festival" : "Season") · \(ThemeSchedule.window(theme))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.45)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOn ? Color.pumpkin : Color.secondary.opacity(0.2), lineWidth: isOn ? 2.5 : 1))
            .opacity(isIncluded || isOn ? 1 : 0.5)
            .shadow(color: .black.opacity(hovering ? 0.18 : 0.05), radius: hovering ? 8 : 3, y: hovering ? 3 : 1)
            .scaleEffect(hovering ? 1.015 : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .help(isIncluded ? "Keep \(theme.title) on your Dock all year" : "Not part of this rotation. Click to keep \(theme.title) on instead.")
    }
}

// MARK: - Settings

struct SettingsPage: View {
    @ObservedObject var model: AppModel
    @State private var hasAccessibility = DockLocator.hasAccessibility
    @State private var dockAtBottom = SettingsPage.isDockAtBottom
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private static var isDockAtBottom: Bool {
        (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom") == "bottom"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            Card(title: "General") {
                SettingRow(symbol: "power", color: .green, title: "Open at login",
                           detail: "Starts quietly, with the harvest already on your Dock.") {
                    Toggle("", isOn: $model.openAtLogin).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "menubar.rectangle", color: .pumpkin, title: "Show 🎃 in the menu bar",
                           detail: model.showMenuBarIcon ? "Quick controls, one click away." : "To come back here, open Fall Dock from Applications.") {
                    Toggle("", isOn: $model.showMenuBarIcon).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "speaker.wave.2.fill", color: .pink, title: "Sounds",
                           detail: "Smashing pumpkins, and the cat's meow.") {
                    Toggle("", isOn: $model.sound).labelsHidden().toggleStyle(.switch)
                }
            }

            Card(title: "Dock") {
                SettingRow(symbol: "square.grid.3x1.below.line.grid.1x2", color: .harvestGreen, title: "How full",
                           detail: "Everything stays the same size. A longer Dock fits more.") {
                    Picker("", selection: $model.fullness) {
                        ForEach(Settings.Fullness.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                Divider()
                if hasAccessibility {
                    SettingRow(symbol: "ruler.fill", color: .blue, title: "Fits your Dock exactly",
                               detail: "Fall Dock measures your Dock, so everything lines up.") {
                        Button("Measure Again") { model.remeasure() }
                    }
                } else {
                    SettingRow(symbol: "ruler.fill", color: .harvestMustard, title: "Fit your Dock exactly",
                               detail: "The Dock's size is estimated for now. Allow Accessibility to measure it. Fall Dock only reads its size.") {
                        Button("Allow…") { DockLocator.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if !dockAtBottom {
                    Divider()
                    SettingRow(symbol: "exclamationmark.triangle.fill", color: .orange, title: "Your Dock is on the side",
                               detail: "The harvest only grows on a Dock at the bottom of the screen.") {
                        Button("Dock Settings…") { openDockSettings() }
                    }
                }
            }

            Card(title: "About") {
                HStack(spacing: 12) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fall Dock \(Self.version)").font(.headline)
                        Text("Drawn and voiced in code. Nothing leaves your Mac.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    Button("Show Welcome") { model.showWelcome() }
                    Button("Reset Smash Count") { model.resetSmashCount() }
                        .disabled(model.smashCount == 0)
                    Spacer()
                    Button("Quit Fall Dock") { NSApp.terminate(nil) }
                }
            }
        }
        .padding(24)
        .onReceive(tick) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        hasAccessibility = DockLocator.hasAccessibility
        dockAtBottom = Self.isDockAtBottom
    }

    private func openDockSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}

// MARK: - The theme menu

/// The theme choices as checkmarked menu items, for the 🎃 menu.
struct ThemeChoiceItems: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Section("Change with the Calendar") {
            ForEach(Settings.ThemeChoice.Rotation.allCases, id: \.self) { item(.rotate($0)) }
        }
        Section("Always Show") {
            ForEach(Settings.Theme.allCases, id: \.self) { item(.keep($0)) }
        }
    }

    private func item(_ choice: Settings.ThemeChoice) -> some View {
        Toggle(choice.title, isOn: Binding(get: { model.themeChoice == choice },
                                           set: { if $0 { model.themeChoice = choice } }))
    }
}

/// Words for when themes change.
enum ThemeSchedule {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Halloween on Oct 15", or nil when it never changes.
    static func next(_ choice: Settings.ThemeChoice) -> String? {
        guard case let .rotate(rotation) = choice, let next = rotation.next(after: Date()) else { return nil }
        return "\(next.theme.title) on \(day(next.date))"
    }

    /// When a theme is on in the calendar, like "Oct 15 – Nov 1".
    static func window(_ theme: Settings.Theme) -> String {
        func date(_ md: (Int, Int)) -> String {
            day(Calendar.current.date(from: DateComponents(year: 2001, month: md.0, day: md.1)) ?? Date())
        }
        return "\(date(theme.window.start)) – \(date(theme.window.end))"
    }
}
