import XCTest

/// Walks through the app window like a person would, to catch anything a change breaks there.
///
/// The app is started with `-UITesting`, so it keeps its settings in a separate place that starts
/// out empty, counts as activated without touching the real license, and never changes the desktop
/// picture or the login items (see AppEnvironment.swift in the app).
final class DockorateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    @discardableResult
    private func launch(_ arguments: [String] = ["-UITestingSkipWelcome"]) -> XCUIApplication {
        app?.terminate()
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"] + arguments
        app.launch()
        self.app = app
        return app
    }

    // MARK: Helpers

    /// Something in the window, found by its accessibility identifier (a settings row's title, say).
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func open(_ page: String) {
        let row = element("sidebar-\(page)")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no \(page) in the sidebar")
        row.click()
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        switch toggle.value {
        case let number as NSNumber: return number.boolValue
        case let string as String: return string == "1" || string.lowercased() == "on"
        default: return false
        }
    }

    /// Scrolls the page until `element` can be clicked.
    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) isn't there", file: file, line: line)
        let page = app.scrollViews.firstMatch
        for deltaY in [-300.0, 300.0] {
            var tries = 0
            while !element.isHittable && tries < 12 {
                page.scroll(byDeltaX: 0, deltaY: deltaY)
                tries += 1
            }
        }
        XCTAssertTrue(element.isHittable, "can't scroll to \(element)", file: file, line: line)
    }

    private func setSwitch(_ identifier: String, on: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = element(identifier)
        reveal(toggle, file: file, line: line)
        if isOn(toggle) != on { toggle.click() }
        XCTAssertEqual(isOn(toggle), on, "\(identifier) didn't switch", file: file, line: line)
    }

    private func text(_ string: String) -> XCUIElement {
        app.staticTexts[string].firstMatch
    }

    // MARK: Tests

    func testWelcomeShowsOnFirstLaunch() {
        launch([])
        XCTAssertTrue(text("Welcome to Dockorate").waitForExistence(timeout: 10))
        app.buttons["Start the Harvest"].firstMatch.click()
        XCTAssertTrue(text("Welcome to Dockorate").waitForNonExistence(timeout: 5))
    }

    func testEveryPageOpens() {
        launch()
        // Each page, and something only that page has.
        for (page, control) in [("home", "Show on Dock"), ("customize", "Vine"),
                                ("background", "Match my desktop to the Dock"), ("settings", "Sounds")] {
            open(page)
            XCTAssertTrue(element(control).waitForExistence(timeout: 5), "\(page) page didn't open")
        }
    }

    func testShowOnDockSwitch() {
        launch()
        open("home")
        let toggle = element("Show on Dock")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(isOn(toggle))
        toggle.click()
        XCTAssertFalse(isOn(toggle))
        XCTAssertTrue(text("Hidden").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Pause"].exists, "nothing to pause while it's hidden")
        toggle.click()
        XCTAssertTrue(isOn(toggle))
    }

    func testPauseAndResume() {
        launch()
        open("home")
        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.click()
        XCTAssertTrue(text("Paused").waitForExistence(timeout: 5))
        app.buttons["Resume"].firstMatch.click()
        XCTAssertTrue(app.buttons["Pause"].firstMatch.waitForExistence(timeout: 5))
    }

    func testFallingLeavesOptionsShowOnlyWhenOn() {
        launch()
        open("customize")
        setSwitch("Falling leaves", on: true)
        XCTAssertTrue(element("Amount").waitForExistence(timeout: 5))
        XCTAssertTrue(element("Fill the whole screen").exists)
        setSwitch("Falling leaves", on: false)
        XCTAssertTrue(element("Amount").waitForNonExistence(timeout: 5))
    }

    func testCozyExtrasSwitch() {
        launch()
        open("customize")
        setSwitch("Cozy extras", on: false)
        XCTAssertTrue(text("Switch on Cozy extras to pick them.").waitForExistence(timeout: 5))
        setSwitch("Cozy extras", on: true)
        XCTAssertTrue(text("Switch on Cozy extras to pick them.").waitForNonExistence(timeout: 5))
    }

    func testChoicesAreKeptAfterRelaunch() {
        launch()
        open("customize")
        setSwitch("Vine", on: false)
        open("settings")
        setSwitch("Sounds", on: false)

        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("customize")
        XCTAssertTrue(element("Vine").waitForExistence(timeout: 5))
        XCTAssertFalse(isOn(element("Vine")))
        open("settings")
        XCTAssertTrue(element("Sounds").waitForExistence(timeout: 5))
        XCTAssertFalse(isOn(element("Sounds")))
    }

    func testBackgroundIsOffUntilSwitchedOn() {
        launch()
        open("background")
        let match = element("Match my desktop to the Dock")
        let followDock = element("Switch with Light and Dark")
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertFalse(isOn(match), "Background must start switched off")
        XCTAssertFalse(followDock.isEnabled, "nothing to pick until it's switched on")

        setSwitch("Match my desktop to the Dock", on: true)
        XCTAssertTrue(followDock.isEnabled)
        XCTAssertTrue(isOn(followDock), "switches with Light and Dark by default")

        // Picking a picture keeps it, whatever the Dock does.
        let dark = element("wallpaper-dark")
        reveal(dark)
        dark.click()
        XCTAssertFalse(isOn(followDock))
        setSwitch("Switch with Light and Dark", on: true)
    }

    func testResetEverythingAsksFirstAndResets() {
        launch()
        open("customize")
        setSwitch("Vine", on: false)
        open("settings")

        let reset = element("Reset everything")
        reveal(reset)
        reset.click()
        XCTAssertTrue(text("Reset everything?").waitForExistence(timeout: 5))
        app.buttons["Cancel"].firstMatch.click()
        XCTAssertTrue(text("Reset everything?").waitForNonExistence(timeout: 5))
        open("customize")
        XCTAssertFalse(isOn(element("Vine")), "cancelling changes nothing")

        open("settings")
        reveal(reset)
        reset.click()
        XCTAssertTrue(text("Reset everything?").waitForExistence(timeout: 5))
        // The alert's own button, not the one on the page behind it.
        let confirm = app.sheets.buttons["Reset Everything"].exists
            ? app.sheets.buttons["Reset Everything"] : app.dialogs.buttons["Reset Everything"]
        confirm.firstMatch.click()
        open("customize")
        XCTAssertTrue(element("Vine").waitForExistence(timeout: 5))
        XCTAssertTrue(isOn(element("Vine")), "back how it started")
    }

    func testWithoutALicenseTheAppAsksForOne() {
        launch(["-UITestingSkipWelcome", "-UITestingUnlicensed"])
        open("home")
        XCTAssertTrue(text("Enter your license key").waitForExistence(timeout: 5))
        open("customize")
        XCTAssertTrue(text("Enter your license key").waitForExistence(timeout: 5))
        open("background")
        XCTAssertTrue(text("Enter your license key").waitForExistence(timeout: 5))
        open("settings")
        XCTAssertTrue(element("Sounds").waitForExistence(timeout: 5), "Settings still works")
    }
}
