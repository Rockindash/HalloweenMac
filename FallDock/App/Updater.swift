import AppKit
import Combine
#if !APP_STORE
import Sparkle
#endif

#if APP_STORE
/// The Mac App Store updates Dockorate itself, so this build has no updater (and no Sparkle).
@MainActor
final class Updater: ObservableObject {
    /// Whether the app can check for updates itself.
    static let isAvailable = false
    @Published private(set) var canCheck = false
    @Published var checksAutomatically = false
    func checkForUpdates() {}
}
#else
/// Updates come from the appcast on the website (SUFeedURL in Info.plist), through Sparkle.
@MainActor
final class Updater: ObservableObject {
    /// Whether the app can check for updates itself.
    static let isAvailable = true
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var canCheckWatch: AnyCancellable?

    /// False while a check is already under way.
    @Published private(set) var canCheck = false

    @Published var checksAutomatically: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    init() {
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        canCheckWatch = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheck = $0 }
    }

    func checkForUpdates() {
        // Dockorate lives in the menu bar, so bring it forward or Sparkle's window opens behind others.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
#endif
