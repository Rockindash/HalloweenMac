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

    /// A switch, found by its accessibility identifier. (Other things in its row, like its label,
    /// can carry the same identifier, so only switches and checkboxes count.)
    private func toggle(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let switchElement = app.switches[identifier].firstMatch
        let checkBox = app.checkBoxes[identifier].firstMatch
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if switchElement.exists { return switchElement }
            if checkBox.exists { return checkBox }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("no switch called \(identifier)", file: file, line: line)
        return switchElement
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
        // The page's own scroll view (the sidebar is one too).
        let page = app.scrollViews.containing(NSPredicate(format: "identifier == %@", element.identifier)).firstMatch
        for deltaY in [-300.0, 300.0] {
            var tries = 0
            while !element.isHittable && tries < 12 {
                page.scroll(byDeltaX: 0, deltaY: deltaY)
                tries += 1
            }
        }
        XCTAssertTrue(element.isHittable, "can't scroll to \(element)", file: file, line: line)
        // Hittable can mean only an edge shows; bring all of it into the window.
        let window = app.windows.firstMatch.frame
        var deltaY = -120.0
        for _ in 0..<12 where element.frame.maxY > window.maxY - 12 {
            let before = element.frame.maxY
            page.scroll(byDeltaX: 0, deltaY: deltaY)
            if element.frame.maxY >= before { deltaY = -deltaY }
        }
    }

    private func setSwitch(_ identifier: String, on: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let control = toggle(identifier, file: file, line: line)
        reveal(control, file: file, line: line)
        if isOn(control) != on { control.click() }
        // SwiftUI can take a moment to update the switch.
        let deadline = Date().addingTimeInterval(3)
        while isOn(control) != on && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(isOn(control), on, "\(identifier) didn't switch: \(control.debugDescription)", file: file, line: line)
    }

    /// A button in an alert. (The Touch Bar can show the same button, which can't be clicked.)
    private func alertButton(_ title: String) -> XCUIElement {
        for container in [app.sheets, app.dialogs, app.windows] {
            let button = container.buttons[title].firstMatch
            if button.exists { return button }
        }
        return app.windows.buttons[title].firstMatch
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
        let showOnDock = toggle("Show on Dock")
        XCTAssertTrue(isOn(showOnDock))
        showOnDock.click()
        XCTAssertFalse(isOn(showOnDock))
        XCTAssertTrue(text("Hidden").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Pause"].exists, "nothing to pause while it's hidden")
        showOnDock.click()
        XCTAssertTrue(isOn(showOnDock))
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
        XCTAssertFalse(isOn(toggle("Vine")))
        open("settings")
        XCTAssertTrue(element("Sounds").waitForExistence(timeout: 5))
        XCTAssertFalse(isOn(toggle("Sounds")))
    }

    func testPickingHalloweenChangesWhatCustomizeShows() {
        launch()
        open("themes")
        XCTAssertTrue(element("theme-fall").waitForExistence(timeout: 5), "Fall is on the Themes page")
        let halloween = app.buttons["theme-halloween"].firstMatch
        reveal(halloween)
        halloween.click()
        open("customize")
        XCTAssertTrue(element("Graveyard dirt").waitForExistence(timeout: 5), "Customize shows Halloween's options")
        XCTAssertTrue(element("Bats").exists)

        // Still Halloween after a relaunch.
        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("customize")
        XCTAssertTrue(element("Graveyard dirt").waitForExistence(timeout: 5))

        // And back to Fall, the original.
        open("themes")
        let fall = app.buttons["theme-fall"].firstMatch
        reveal(fall)
        fall.click()
        open("customize")
        XCTAssertTrue(element("Vine").waitForExistence(timeout: 5), "Customize shows Fall's options again")
        XCTAssertTrue(element("Falling leaves").exists)
    }

    func testChangeWithTheCalendarIsKept() {
        launch()
        open("themes")
        XCTAssertFalse(isOn(toggle("Change with the calendar")), "Fall stays on until something else is picked")
        setSwitch("Change with the calendar", on: true)
        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("themes")
        XCTAssertTrue(isOn(toggle("Change with the calendar")))
        setSwitch("Change with the calendar", on: false)
    }

    func testBackgroundIsOffUntilSwitchedOn() {
        launch()
        open("background")
        let match = toggle("Match my desktop to the Dock")
        let followDock = toggle("Switch with Light and Dark")
        XCTAssertFalse(isOn(match), "Background must start switched off")
        XCTAssertFalse(followDock.isEnabled, "nothing to pick until it's switched on: \(followDock.debugDescription)")

        setSwitch("Match my desktop to the Dock", on: true)
        XCTAssertTrue(followDock.isEnabled, "can pick once it's on")
        XCTAssertTrue(isOn(followDock), "switches with Light and Dark by default")

        // Picking a picture keeps it, whatever the Dock does.
        let dark = app.buttons["wallpaper-dark"].firstMatch
        reveal(dark)
        dark.click()
        let kept = NSPredicate { _, _ in !self.isOn(followDock) }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: kept, object: nil)], timeout: 3), .completed,
                       "picking the dark picture keeps it: \(dark.debugDescription)")
        setSwitch("Switch with Light and Dark", on: true)
    }

    func testResetEverythingAsksFirstAndResets() {
        launch()
        open("customize")
        setSwitch("Vine", on: false)
        open("settings")

        let reset = app.buttons["Reset everything"].firstMatch
        reveal(reset)
        reset.click()
        XCTAssertTrue(text("Reset everything?").waitForExistence(timeout: 5))
        alertButton("Cancel").click()
        XCTAssertTrue(text("Reset everything?").waitForNonExistence(timeout: 5))
        open("customize")
        XCTAssertFalse(isOn(toggle("Vine")), "cancelling changes nothing")

        open("settings")
        reveal(reset)
        reset.click()
        XCTAssertTrue(text("Reset everything?").waitForExistence(timeout: 5))
        // The alert's own button, not the one on the page behind it.
        alertButton("Reset Everything").click()
        open("customize")
        XCTAssertTrue(element("Vine").waitForExistence(timeout: 5))
        XCTAssertTrue(isOn(toggle("Vine")), "back how it started")
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
