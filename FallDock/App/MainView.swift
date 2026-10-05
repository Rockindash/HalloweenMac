import AppKit
import SwiftUI

// The app window: a sidebar with Home, Customize and Settings, like System Settings and most
// pro Mac apps. Home answers "is it on?", Customize picks what grows, and
// Settings holds everything else. The building blocks (cards, tiles, the live harvest) and the
// Customize page are in MainTabs.swift.

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

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .customize: return "paintbrush.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .home: return .pumpkin
        case .customize: return .purple
        case .settings: return .gray
        }
    }
}

struct MainView: View {
    /// The smallest the window can be and still show every page properly.
    static let minSize = NSSize(width: 820, height: 600)

    @ObservedObject var model: AppModel
    @AppStorage("mainWindowPage") private var pageName = Page.home.rawValue

    private var page: Page { Page(rawValue: pageName) ?? .home }

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, selection: Binding(get: { page }, set: { pageName = ($0 ?? .home).rawValue }))
                .navigationSplitViewColumnWidth(min: 200, ideal: 210, max: 240)
        } detail: {
            VStack(spacing: 0) {
                PageHeader(model: model, page: page)
                Divider()
                ScrollView {
                    Group {
                        switch page {
                        case .home: HomePage(model: model)
                        case .customize: ThemeTab(model: model)
                        case .settings: SettingsPage(model: model)
                        }
                    }
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .id(page)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.pumpkin)
        .frame(minWidth: Self.minSize.width, minHeight: Self.minSize.height)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Binding var selection: Page?

    private var status: (text: String, color: Color) {
        if !model.showPumpkins { return ("Hidden", .gray) }
        if model.isPaused { return ("Paused", .yellow) }
        return ("On your Dock", .green)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(Page.allCases) { page in
                Label {
                    Text(page.title)
                } icon: {
                    Image(systemName: page.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(page.color.gradient))
                }
                .tag(page)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fall Dock").font(.system(size: 14, weight: .bold, design: .rounded))
                    HStack(spacing: 5) {
                        Circle().fill(status.color).frame(width: 6, height: 6)
                        Text(status.text).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }
}

/// The page's title, under the window's buttons.
private struct PageHeader: View {
    @ObservedObject var model: AppModel
    var page: Page

    private var subtitle: String {
        switch page {
        case .home: return "Your harvest, and whether it's on your Dock"
        case .customize: return "What grows on your Dock for \(model.theme.title)"
        case .settings: return "Startup, sounds, your Dock, and about Fall Dock"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(page == .customize ? "Customize \(model.theme.title)" : page.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

// MARK: - Home

struct HomePage: View {
    @ObservedObject var model: AppModel

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
                        Text("The harvest is in on your Dock. Try clicking things!")
                            .font(.callout.weight(.medium))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .padding(18)
                }
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

            OnOffCard(model: model)
        }
        .padding(24)
    }
}

/// Is the harvest on the Dock? The one switch most people need.
private struct OnOffCard: View {
    @ObservedObject var model: AppModel
    @State private var dockShowing = AppModel.shared.dockStatus.isShowing
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isShowing: Bool { model.showPumpkins && !model.isPaused }

    private var status: String {
        if !model.showPumpkins { return "Hidden. Switch it on to bring the harvest back." }
        if model.isPaused { return "Paused for an hour, then it comes back by itself." }
        if !dockShowing { return "Your Dock is hidden right now (a full-screen app?). Changes show up when it's back." }
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
        .onReceive(tick) { _ in dockShowing = model.dockStatus.isShowing }
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
                           detail: "A soft, squishy thump when a pumpkin is smashed.") {
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
