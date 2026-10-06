import AppKit
import Combine
import Sparkle

/// Updates come from the appcast on the website (SUFeedURL in Info.plist), through Sparkle.
@MainActor
final class Updater: ObservableObject {
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
