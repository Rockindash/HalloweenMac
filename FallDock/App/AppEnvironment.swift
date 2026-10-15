import Foundation

/// How the app was started: normally, or by the tests.
///
/// Unit tests run inside the app, so while they run the app does nothing by itself (no harvest, no
/// windows). UI tests start the app with `-UITesting`: it then keeps its settings in a separate,
/// fresh place, counts as activated, and never changes the desktop picture or the login items, so a
/// test run can't touch the real settings, license or desktop.
enum AppEnvironment {
    /// Whether this is the Mac App Store build (the "Dockorate App Store" target). It's paid for on the
    /// App Store, so it has no license key, and the App Store updates it, so it has no Sparkle.
    #if APP_STORE
    static let isAppStore = true
    #else
    static let isAppStore = false
    #endif

    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

    static let isUnitTesting = !isUITesting && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// The settings for a UI test run. Emptied at launch unless the test asks to keep them (with
    /// `-UITestingKeepSettings`), to check that a choice is still there after a relaunch.
    static func uiTestDefaults() -> UserDefaults {
        let name = "com.amol.dockorate.uitests"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        let arguments = ProcessInfo.processInfo.arguments
        if !arguments.contains("-UITestingKeepSettings") {
            defaults.removePersistentDomain(forName: name)
        }
        // Most tests start at the app window rather than the welcome.
        if arguments.contains("-UITestingSkipWelcome") {
            defaults.set(true, forKey: "hasSeenWelcome")
        }
        return defaults
    }
}
