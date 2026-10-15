import AppKit
import SwiftUI

// The app window, laid out like the Mac App Store: a floating sidebar with Home, Themes, Customize,
// Background and Settings, and pages with a big title, a wide banner and plain rounded cards. Home
// answers "is it on?", Themes picks Fall or Halloween (or the calendar), Customize picks what grows,
// Background sets a desktop picture to match, and Settings holds everything else. The building blocks
// (cards, tiles, the live harvest) and the Customize page are in MainTabs.swift; the Themes page is in
// ThemesPage.swift and the Background page in BackgroundPage.swift.

enum Page: String, CaseIterable, Identifiable {
    case home, themes, customize, background, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .themes: return "Themes"
        case .customize: return "Customize"
        case .background: return "Background"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .themes: return "sparkles"
        case .customize: return "paintbrush"
        case .background: return "photo"
        case .settings: return "gearshape"
        }
    }
}

/// Where the harvest is: on the Dock, paused, switched off, or waiting for a hidden Dock.
enum HarvestState {
    case showing, dockHidden, paused, hidden, unlicensed

    var title: String {
        switch self {
        case .showing: return "On your Dock"
        case .dockHidden: return "Dock hidden"
        case .paused: return "Paused"
        case .hidden: return "Hidden"
        case .unlicensed: return "Not activated"
        }
    }

    var color: Color {
        switch self {
        case .showing: return .green
        case .dockHidden, .paused: return .yellow
        case .hidden, .unlicensed: return .gray
        }
    }

    @MainActor
    static func of(_ model: AppModel, dockShowing: Bool) -> HarvestState {
        if !model.license.isActive { return .unlicensed }
        if !model.showPumpkins { return .hidden }
        if model.isPaused { return .paused }
        return dockShowing ? .showing : .dockHidden
    }
}

struct MainView: View {
    /// The smallest the window can be and still show every page properly.
    static let minSize = NSSize(width: 940, height: 660)

    @ObservedObject var model: AppModel
    @AppStorage("mainWindowPage") private var pageName = Page.home.rawValue
    /// Whether the Dock itself is showing (it hides for full-screen apps); checked every second.
    @State private var dockShowing = AppModel.shared.dockStatus.isShowing
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var page: Page { Page(rawValue: pageName) ?? .home }
    private var state: HarvestState { .of(model, dockShowing: dockShowing) }

    var body: some View {
        NavigationSplitView {
            Sidebar(state: state, selection: Binding(get: { page }, set: { pageName = ($0 ?? .home).rawValue }))
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch page {
                case .home where !model.license.isActive, .themes where !model.license.isActive,
                     .customize where !model.license.isActive, .background where !model.license.isActive:
                    LicensePage(license: model.license)
                case .home:
                    HomePage(model: model, state: state, openCustomize: { pageName = Page.customize.rawValue },
                             openThemes: { pageName = Page.themes.rawValue })
                case .themes: ThemesPage(model: model)
                case .customize: CustomizePage(model: model)
                case .background: BackgroundPage(model: model)
                case .settings: SettingsPage(model: model)
                }
            }
            .id(page)
        }
        .modifier(NoSidebarToggle())
        .environment(\.isFullScreen, model.isFullScreen)
        .tint(.pumpkin)
        .frame(minWidth: Self.minSize.width, minHeight: Self.minSize.height)
        .onReceive(tick) { _ in dockShowing = model.dockStatus.isShowing }
    }
}

/// Whether the app's window is in full screen.
private struct IsFullScreenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isFullScreen: Bool {
        get { self[IsFullScreenKey.self] }
        set { self[IsFullScreenKey.self] = newValue }
    }
}

/// Lets a view run up under the see-through toolbar, `inset` points from the top of the window, as
/// the App Store does. In full screen the toolbar is a solid band, so the view starts below it instead.
struct UnderToolbar: ViewModifier {
    var inset: CGFloat = 0
    @Environment(\.isFullScreen) private var isFullScreen

    func body(content: Content) -> some View {
        if isFullScreen {
            content
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: inset) }
                .ignoresSafeArea(.container, edges: .top)
        }
    }
}

/// The sidebar always shows, so there's no button to hide it, and the empty toolbar shows no title.
private struct NoSidebarToggle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .sidebarToggle).toolbar(removing: .title)
        } else if #available(macOS 14.0, *) {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}

private struct Sidebar: View {
    var state: HarvestState
    @Binding var selection: Page?

    var body: some View {
        List {
            ForEach(Page.allCases) { page in
                SidebarRow(page: page, isSelected: selection == page) { selection = page }
            }
        }
        .listStyle(.sidebar)
        // The first row sits just under the close, minimize and zoom buttons, not a toolbar's height
        // below (in full screen, where the toolbar is a solid band, it starts below the band instead).
        .modifier(UnderToolbar(inset: 40))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Who's here, where the App Store shows your account.
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dockorate").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle().fill(state.color).frame(width: 6, height: 6)
                        Text(state.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

/// A sidebar row: a soft grey highlight and the accent color when selected, as in the App Store.
private struct SidebarRow: View {
    var page: Page
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.symbol)
                    .font(.system(size: 15))
                    .frame(width: 22)
                Text(page.title).font(.system(size: 14))
                Spacer()
            }
            .foregroundStyle(isSelected ? Color.pumpkin : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("sidebar-\(page.rawValue)")
    }
}

// MARK: - Home

struct HomePage: View {
    @ObservedObject var model: AppModel
    var state: HarvestState
    var openCustomize: () -> Void
    var openThemes: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 20)]

    private var status: String {
        switch state {
        case .showing:
            return model.theme == .halloween
                ? "Click a jack-o'-lantern to smash it. The cat, the cauldron and the candles do things too."
                : "Click a pumpkin to smash it. Hay bales, leaf piles and the latte do things too."
        case .dockHidden: return "Your Dock is hidden right now. Changes show up when it's back."
        case .paused: return "Paused for an hour, then it comes back by itself."
        case .hidden: return "Switched off. Turn it on to bring the harvest back."
        case .unlicensed: return "Enter your license key to bring the harvest to your Dock."
        }
    }

    private var smashed: String {
        switch model.smashCount {
        case 0: return "No Pumpkins Smashed Yet"
        case 1: return "1 Pumpkin Smashed"
        default: return "\(model.smashCount) Pumpkins Smashed"
        }
    }

    var body: some View {
        // Checked every minute, so the greeting changes if the window stays open past noon or 5pm.
        TimelineView(.everyMinute) { context in
            PageLayout(title: Self.greeting(at: context.date)) {
                LiveHarvestView(model: model, height: 300)

                controls

                LazyVGrid(columns: columns, spacing: 20) {
                    FeatureCard(eyebrow: "Your harvest", title: smashed,
                                subtitle: "Smash one on your Dock and another grows in its place.",
                                image: ExtraArt.pumpkin(), imageBackground: Color.harvestMustard.opacity(0.22))
                    Button(action: openThemes) {
                        FeatureCard(eyebrow: "Theme", title: model.theme.title,
                                    subtitle: ThemeSchedule.summary(model.themeChoice),
                                    image: model.theme == .halloween ? ExtraArt.jackOLantern() : ExtraArt.pumpkin(),
                                    imageBackground: Color.harvestNight.opacity(0.2))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: openCustomize) {
                        FeatureCard(eyebrow: "Customize", title: "Make It Yours",
                                    subtitle: model.theme == .halloween
                                        ? "Graveyard dirt, bats, tombstones, candy and a friendly ghost."
                                        : "Vines, falling leaves, hay bales, a latte and a visiting squirrel.",
                                    image: model.theme == .halloween ? ExtraArt.ghost() : ExtraArt.squirrel(),
                                    imageBackground: Color.harvestRust.opacity(0.2))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    /// The page's big title: Good Morning from 5am, Good Afternoon from noon, Good Evening from 5pm.
    static func greeting(at date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    /// Under the harvest: where it is, what that means, then the switch most people need plus pause and regrow.
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Circle().fill(state.color).frame(width: 10, height: 10)
                    Text(state.title).font(.headline)
                }
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Buttons on the left, the switch pinned far right so it stays put when they come and go.
            HStack(spacing: 8) {
                if model.showPumpkins {
                    Button(model.isPaused ? "Resume" : "Pause") {
                        withAnimation { model.isPaused ? model.resume() : model.pauseForAnHour() }
                    }
                    .help(model.isPaused ? "Bring the harvest back now" : "Hide the harvest for an hour")
                    Button("Grow New") { model.regrow() }
                        .help("Grow a new harvest")
                        .disabled(model.isPaused)
                }
                Spacer(minLength: 0)
                Toggle(isOn: $model.showPumpkins.animation()) {
                    Text("Show on Dock")
                }
                .toggleStyle(.switch)
                .fixedSize()
                .accessibilityIdentifier("Show on Dock")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardFill))
    }
}

// MARK: - Settings

struct SettingsPage: View {
    @ObservedObject var model: AppModel
    @State private var hasAccessibility = DockLocator.hasAccessibility
    @State private var dockAtBottom = SettingsPage.isDockAtBottom
    @State private var confirmingSmashReset = false
    @State private var confirmingResetAll = false
    @State private var confirmingLicenseRemoval = false
    private let tick = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private static var isDockAtBottom: Bool {
        (UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom") == "bottom"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        PageLayout(title: "Settings") {
            Card(title: "General") {
                SettingRow(symbol: "power", color: .green, title: "Open at login",
                           detail: "Starts quietly, with the harvest already on your Dock.") {
                    Toggle("", isOn: $model.openAtLogin).labelsHidden().toggleStyle(.switch)
                }
                Divider()
                SettingRow(symbol: "menubar.rectangle", color: .pumpkin, title: "Show the pumpkin in the menu bar",
                           detail: model.showMenuBarIcon ? "Quick controls, one click away." : "To come back here, open Dockorate from Applications.") {
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
                               detail: "Dockorate measures your Dock, so everything lines up.") {
                        Button("Measure Again") { model.remeasure() }
                    }
                } else {
                    SettingRow(symbol: "ruler.fill", color: .harvestMustard, title: "Fit your Dock exactly",
                               detail: "The Dock's size is estimated for now. Allow Accessibility to measure it. Dockorate only reads its size.") {
                        Button("Allow") { DockLocator.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if !dockAtBottom {
                    Divider()
                    SettingRow(symbol: "exclamationmark.triangle.fill", color: .orange, title: "Your Dock is on the side",
                               detail: "The harvest only grows on a Dock at the bottom of the screen.") {
                        Button("Dock Settings") { openDockSettings() }
                    }
                }
            }

            // The App Store version is paid for on the App Store and updated by it: no license, no updater.
            if !model.license.isAppStore {
                Card(title: "License") {
                    if model.license.isActive {
                        SettingRow(symbol: "checkmark.seal.fill", color: .green, title: "Active",
                                   detail: "License key \(model.license.maskedKey)") {
                            Button("Remove License") { confirmingLicenseRemoval = true }
                        }
                    } else {
                        LicenseCard(license: model.license)
                            .padding(-18)
                    }
                }
                .alert("Remove the license from this Mac?", isPresented: $confirmingLicenseRemoval) {
                    Button("Remove License", role: .destructive) { model.license.remove() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The harvest leaves your Dock until a license key is entered again. Use this to move Dockorate to another Mac.")
                }
            }

            if Updater.isAvailable {
                UpdatesCard(updater: model.updater)
            }

            Card(title: "Reset") {
                SettingRow(symbol: "hammer.fill", color: .pumpkin, title: "Smash count",
                           detail: model.smashCount == 1 ? "1 pumpkin smashed so far." : "\(model.smashCount) pumpkins smashed so far.") {
                    Button("Reset Smash Count") { confirmingSmashReset = true }
                        .disabled(model.smashCount == 0)
                }
                Divider()
                SettingRow(symbol: "arrow.counterclockwise", color: .red, title: "Reset everything",
                           detail: "Puts every option back how it started, clears the smash count and grows a fresh harvest.") {
                    Button("Reset Everything", role: .destructive) { confirmingResetAll = true }
                        .tint(.red)
                }
            }
            .alert("Reset the smash count?", isPresented: $confirmingSmashReset) {
                Button("Reset", role: .destructive) { model.resetSmashCount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The count of \(model.smashCount) smashed pumpkins goes back to zero. This can't be undone.")
            }
            .alert("Reset everything?", isPresented: $confirmingResetAll) {
                Button("Reset Everything", role: .destructive) { model.resetEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All of Dockorate's options go back to how they started, the smash count goes back to zero, and a fresh harvest grows. Open at login stays as it is. This can't be undone.")
            }

            Card(title: "About") {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dockorate \(Self.version)").font(.headline)
                        Text("Drawn and voiced in code. It only goes online to check your license and look for updates.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    Button("Show Welcome") { model.showWelcome() }
                    Spacer()
                    Button("Quit Dockorate") { NSApp.terminate(nil) }
                }
            }
        }
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

/// Settings → Updates: Sparkle's automatic checks, and a button to check now.
private struct UpdatesCard: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Card(title: "Updates") {
            SettingRow(symbol: "arrow.down.circle.fill", color: .blue, title: "Version \(SettingsPage.version) (build \(SettingsPage.build))",
                       detail: "Dockorate checks the website for new versions.") {
                Button("Check for Updates") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
            }
            Divider()
            SettingRow(symbol: "clock.arrow.circlepath", color: .teal, title: "Automatically check for updates",
                       detail: "Looks once a day and asks before installing anything.") {
                Toggle("", isOn: $updater.checksAutomatically).labelsHidden().toggleStyle(.switch)
            }
        }
    }
}
