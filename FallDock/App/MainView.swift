import AppKit
import SwiftUI

// The app window: a sidebar of pages (like System Settings), a top bar with the season switcher on
// every page, and the pages themselves. The building blocks (cards, tiles, the live harvest) and the
// Dock, Settings and season pages are in MainTabs.swift.

enum Page: String, CaseIterable, Identifiable {
    case home, season, dock, settings, about
    var id: String { rawValue }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    @AppStorage("mainWindowPage") private var pageName = Page.home.rawValue

    private var page: Page { Page(rawValue: pageName) ?? .home }

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, selection: Binding(get: { page }, set: { pageName = ($0 ?? .home).rawValue }))
                .navigationSplitViewColumnWidth(min: 210, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                TopBar(model: model, page: page)
                Divider()
                ScrollView {
                    pageContent
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                }
                .id(page)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.pumpkin)
        .frame(minWidth: 820, minHeight: 600)
    }

    @ViewBuilder private var pageContent: some View {
        switch page {
        case .home: HomePage(model: model) { pageName = Page.season.rawValue }
        case .season: ThemeTab(model: model)
        case .dock: DockTab(model: model)
        case .settings: SettingsTab(model: model)
        case .about: AboutPage(model: model)
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Binding var selection: Page?

    var body: some View {
        List(selection: $selection) {
            Section {
                row(.home, "Home", "house.fill", .pumpkin)
                row(.season, model.theme.title, model.theme.symbol, model.theme == .halloween ? .purple : .harvestRust)
            }
            Section("Setup") {
                row(.dock, "Dock", "dock.rectangle", .blue)
                row(.settings, "Settings", "gearshape.fill", .gray)
            }
            Section {
                row(.about, "About", "info.circle.fill", .harvestGreen)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private func row(_ page: Page, _ title: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
        }
        .tag(page)
    }

    private var status: (text: String, color: Color) {
        if !model.showPumpkins { return ("Hidden", .gray) }
        if model.isPaused { return ("Paused for an hour", .yellow) }
        return ("Growing on your Dock", .green)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Fall Dock")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                HStack(spacing: 5) {
                    Circle().fill(status.color).frame(width: 6, height: 6)
                    Text(status.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            Toggle(isOn: $model.showPumpkins.animation()) {
                Label("Show on Dock", systemImage: "eye")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            Button {
                withAnimation { model.isPaused ? model.resume() : model.pauseForAnHour() }
            } label: {
                Label(model.isPaused ? "Resume" : "Pause for 1 Hour", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .disabled(!model.showPumpkins)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }
}

// MARK: - Top bar

/// The page's title, and the season switcher on the right, on every page.
private struct TopBar: View {
    @ObservedObject var model: AppModel
    var page: Page

    private var title: (String, String) {
        switch page {
        case .home: return ("Home", "Your harvest at a glance")
        case .season: return (model.theme.title, "What grows on your Dock this season")
        case .dock: return ("Dock", "How the harvest fits your Dock")
        case .settings: return ("Settings", "Startup, sound and privacy")
        case .about: return ("About", "Fall Dock \(AboutPage.version)")
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title.0)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(title.1)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SeasonSwitcher(model: model)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

/// A menu showing the current season, to switch it from anywhere in the window.
struct SeasonSwitcher: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            Picker("Season", selection: $model.themeChoice.animation()) {
                ForEach(Settings.ThemeChoice.allCases, id: \.self) { choice in
                    Label(choice.title, systemImage: choice.symbol).tag(choice)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: model.theme.symbol)
                Text(model.themeChoice == .automatic ? "\(model.theme.title) · Auto" : model.theme.title)
                    .fontWeight(.semibold)
            }
        }
        .menuStyle(.borderedButton)
        .fixedSize()
        .help("Choose the season on your Dock")
    }
}

// MARK: - Home

struct HomePage: View {
    @ObservedObject var model: AppModel
    var openSeason: () -> Void
    @State private var dock = AppModel.shared.dockStatus
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LiveHarvestView(model: model, height: 230)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                        Text(model.theme == .halloween ? "Something spooky is growing on your Dock." : "The harvest is in on your Dock.")
                            .font(.callout.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .padding(18)
                }
                .overlay(alignment: .topTrailing) {
                    Text(model.theme == .halloween ? "Try clicking things!" : "Click a pumpkin!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.harvestPlum)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.harvestPeach))
                        .padding(16)
                        .padding(.trailing, 110)
                }
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            section("Season", "Choose what grows on your Dock. Automatic follows the calendar.") {
                HStack(spacing: 12) {
                    ForEach(Settings.ThemeChoice.allCases, id: \.self) { choice in
                        SeasonCard(choice: choice, isSelected: model.themeChoice == choice) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { model.themeChoice = choice }
                        }
                    }
                }
                Button {
                    openSeason()
                } label: {
                    Label("Customize \(model.theme.title)", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.pumpkin)
                .font(.callout.weight(.semibold))
            }

            section("At a glance", nil) {
                HStack(spacing: 10) {
                    StatTile(value: "\(model.smashCount)", label: "Pumpkins smashed", symbol: "hammer.fill", color: .pumpkin)
                    StatTile(value: dock.isShowing ? "\(dock.pumpkins)" : "–",
                             label: dock.isShowing ? "On your Dock now" : "Dock hidden right now", symbol: "leaf.fill", color: .harvestGreen)
                    StatTile(value: "\(dock.extras)", label: "Extras between them", symbol: "sparkles", color: .harvestMustard)
                }
            }

            section("Quick actions", nil) {
                HStack(spacing: 10) {
                    ActionTile(symbol: "arrow.triangle.2.circlepath", title: "Grow New", detail: "A fresh harvest") { model.regrow() }
                    ActionTile(symbol: model.isPaused ? "play.fill" : "pause.fill",
                               title: model.isPaused ? "Resume" : "Pause",
                               detail: model.isPaused ? "Paused for an hour" : "Hide for an hour",
                               isOn: model.isPaused) { model.isPaused ? model.resume() : model.pauseForAnHour() }
                    ActionTile(symbol: "arrow.counterclockwise", title: "Reset Count", detail: "Start smashing afresh") { model.resetSmashCount() }
                }
            }
        }
        .padding(24)
        .onReceive(tick) { _ in dock = model.dockStatus }
    }

    private func section<Content: View>(_ title: String, _ subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                }
            }
            content()
        }
    }
}

/// One of the season choices, as a big picture card.
struct SeasonCard: View {
    var choice: Settings.ThemeChoice
    var isSelected: Bool
    var action: () -> Void
    @State private var hovering = false

    /// The season the card shows a picture of (Automatic shows today's).
    private var theme: Settings.Theme {
        switch choice {
        case .automatic: return Settings.Theme.forDate(Date())
        case .fall: return .fall
        case .halloween: return .halloween
        }
    }

    private var subtitle: String {
        switch choice {
        case .automatic: return "\(theme.title) now, changing with the calendar"
        case .fall: return "Pumpkins, hay and falling leaves"
        case .halloween: return "Jack-o'-lanterns, candy and a ghost"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Image(nsImage: ThemePreview.image(for: theme))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if choice == .automatic {
                            Label("Auto", systemImage: "calendar")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.35)))
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.pumpkin)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Label(choice.title, systemImage: choice.symbol)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.45)))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.pumpkin : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2.5 : 1))
            .shadow(color: .black.opacity(hovering ? 0.2 : 0.06), radius: hovering ? 10 : 4, y: hovering ? 4 : 2)
            .scaleEffect(hovering ? 1.02 : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressableStyle())
        .onHover { hovering = $0 }
        .help(choice == .automatic ? "Fall now, Halloween from October 15th to November 1st" : "Show \(choice.title) on your Dock")
    }
}

// MARK: - About

struct AboutPage: View {
    @ObservedObject var model: AppModel

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 110, height: 110)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            VStack(spacing: 4) {
                Text("Fall Dock")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("Version \(Self.version)")
                    .foregroundStyle(.secondary)
                Text("A cozy harvest on top of your Dock, for every season.")
                    .padding(.top, 4)
            }
            Card(title: nil) {
                SettingRow(symbol: "paintbrush.pointed.fill", color: .pumpkin, title: "Drawn in code",
                           detail: "Every pumpkin, leaf, ghost and bat is drawn by the app itself, in a flat harvest-wagon style.") { EmptyView() }
                Divider()
                SettingRow(symbol: "waveform", color: .pink, title: "Sounds made from scratch",
                           detail: "The smash and the cat's meow are synthesized, with no audio files.") { EmptyView() }
                Divider()
                SettingRow(symbol: "hand.raised.fill", color: .gray, title: "Private by design",
                           detail: "Nothing leaves your Mac.") { EmptyView() }
            }
            HStack {
                Button("Show Welcome") { model.showWelcome() }
                Button("Quit Fall Dock") { NSApp.terminate(nil) }
            }
            Text("Made with 🧡 for cozy autumn days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}
