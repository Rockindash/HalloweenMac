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

    func testChangeAutomaticallyIsKept() {
        launch()
        open("themes")
        XCTAssertFalse(isOn(toggle("Change automatically")), "Fall stays on until something else is picked")
        setSwitch("Change automatically", on: true)
        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("themes")
        XCTAssertTrue(isOn(toggle("Change automatically")))
        // Switching it off keeps the theme that's on, and brings back the themes to pick from.
        setSwitch("Change automatically", on: false)
        let halloween = app.buttons["theme-halloween"].firstMatch
        XCTAssertTrue(halloween.waitForExistence(timeout: 5))
        reveal(halloween)
        halloween.click()
        open("customize")
        XCTAssertTrue(element("Graveyard dirt").waitForExistence(timeout: 5), "the picked theme is on the Dock")
    }

    func testPickAThemeShowsOnlyWhenChangeAutomaticallyIsOff() {
        launch()
        open("themes")
        XCTAssertFalse(isOn(toggle("Change automatically")))
        XCTAssertTrue(element("pick-a-theme").waitForExistence(timeout: 5), "themes to pick from while it's off")
        XCTAssertTrue(app.buttons["theme-fall"].firstMatch.exists)

        setSwitch("Change automatically", on: true)
        let gone = NSPredicate { _, _ in !self.element("pick-a-theme").exists && !self.app.buttons["theme-fall"].firstMatch.exists }
        wait(for: [expectation(for: gone, evaluatedWith: nil)], timeout: 5)

        setSwitch("Change automatically", on: false)
        XCTAssertTrue(element("pick-a-theme").waitForExistence(timeout: 5), "back once it's off again")
    }

    func testThemesPageShowsChangeAutomaticallyFirstAndThemesTwoToARow() {
        launch()
        open("themes")
        let automatic = toggle("Change automatically")
        let fall = app.buttons["theme-fall"].firstMatch, halloween = app.buttons["theme-halloween"].firstMatch
        XCTAssertTrue(fall.waitForExistence(timeout: 5))
        XCTAssertLessThan(automatic.frame.minY, fall.frame.minY, "Change Automatically comes before the themes")
        XCTAssertEqual(fall.frame.minY, halloween.frame.minY, accuracy: 2, "side by side")
        XCTAssertLessThan(fall.frame.maxX, halloween.frame.minX)
        XCTAssertLessThan(fall.frame.width, app.windows.firstMatch.frame.width / 2, "about half the page each")
    }

    func testChangeAutomaticallyShowsTheYearAndTheRotationOnlyWhenOn() {
        launch()
        open("themes")
        XCTAssertFalse(isOn(toggle("Change automatically")))
        XCTAssertFalse(element("theme-year").exists, "nothing about changing automatically while it's off")
        XCTAssertFalse(app.switches["rotation-halloween"].exists)

        setSwitch("Change automatically", on: true)
        XCTAssertTrue(element("theme-year").waitForExistence(timeout: 5), "the year at a glance")
        XCTAssertTrue(text("THEMES IT SWITCHES BETWEEN").waitForExistence(timeout: 5), "the rotation says plainly what it is")
        let fall = toggle("rotation-fall"), halloween = toggle("rotation-halloween")
        XCTAssertTrue(isOn(fall))
        XCTAssertTrue(isOn(halloween), "every theme starts out in the rotation")
        XCTAssertFalse(fall.isEnabled, "the only season stays in")

        // Leaving Halloween out is kept.
        setSwitch("rotation-halloween", on: false)
        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("themes")
        XCTAssertFalse(isOn(toggle("rotation-halloween")))

        // Switched off, it all goes away again.
        setSwitch("Change automatically", on: false)
        let gone = NSPredicate { _, _ in !self.element("theme-year").exists }
        wait(for: [expectation(for: gone, evaluatedWith: nil)], timeout: 5)
    }

    func testTheYearRunsFromJanuaryThroughDecember() {
        launch()
        open("themes")
        setSwitch("Change automatically", on: true)
        let year = element("theme-year"), ribbon = element("theme-ribbon")
        XCTAssertTrue(ribbon.waitForExistence(timeout: 5), "the ribbon of the year's themes")
        XCTAssertGreaterThan(year.frame.width, 100)
        XCTAssertEqual(ribbon.frame.minX, year.frame.minX, accuracy: 2, "January 1st at the left edge: \(ribbon.frame) in \(year.frame)")
        XCTAssertEqual(ribbon.frame.maxX, year.frame.maxX, accuracy: 2, "December 31st at the right edge: \(ribbon.frame) in \(year.frame)")
    }

    func testFestivalsCanShowUpEarlier() {
        launch()
        open("themes")
        setSwitch("Change automatically", on: true)
        // Halloween's days, as the app writes them: "Oct 24 to Oct 31".
        let halloween = { (from: Int) -> String in
            let day = { (day: Int) in
                Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day))!
                    .formatted(.dateTime.month(.abbreviated).day())
            }
            return "\(day(from)) to \(day(31))"
        }
        XCTAssertTrue(text(halloween(24)).waitForExistence(timeout: 5), "a week before its day to start with")

        let twoWeeks = app.buttons["festival-lead-14"].firstMatch
        reveal(twoWeeks)
        twoWeeks.click()
        XCTAssertTrue(text(halloween(17)).waitForExistence(timeout: 5), "two weeks before")
        XCTAssertFalse(text(halloween(24)).exists)

        // And it's kept.
        launch(["-UITestingSkipWelcome", "-UITestingKeepSettings"])
        open("themes")
        XCTAssertTrue(text(halloween(17)).waitForExistence(timeout: 5), "still two weeks before after a relaunch")
    }

    func testAFestivalsDetailsShowOnlyWhenPointedAtOrClicked() {
        launch()
        open("themes")
        setSwitch("Change automatically", on: true)
        let halloween = element("festival-halloween")
        reveal(halloween)
        let tip = element("festival-tip")
        XCTAssertFalse(tip.exists, "Halloween's week is picked out, with no details until asked")

        halloween.hover()
        XCTAssertTrue(tip.waitForExistence(timeout: 3), "pointing at Halloween's week shows its details")
        toggle("Change automatically").hover()
        let gone = NSPredicate { _, _ in !tip.exists }
        wait(for: [expectation(for: gone, evaluatedWith: nil)], timeout: 3)

        halloween.click()
        XCTAssertTrue(tip.waitForExistence(timeout: 3))
        toggle("Change automatically").hover()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(tip.exists, "after a click they stay until clicked again")
    }

    func testCustomizeHasAThemeMenu() {
        launch()
        open("customize")
        let menu = app.popUpButtons["customize-theme"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "a drop-down menu of themes")
        XCTAssertTrue((menu.value as? String)?.contains("Fall") == true, "showing the theme on the Dock: \(menu.debugDescription)")
        // It follows the theme on the Dock. (XCUITest can't open the menu itself on the CI Mac: its
        // click waits for a menu-open notification that never arrives there.)
        open("themes")
        let halloween = app.buttons["theme-halloween"].firstMatch
        reveal(halloween)
        halloween.click()
        open("customize")
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        let showsHalloween = NSPredicate { _, _ in (menu.value as? String)?.contains("Halloween") == true }
        wait(for: [expectation(for: showsHalloween, evaluatedWith: nil)], timeout: 5)
        XCTAssertTrue(element("Graveyard dirt").exists)
        XCTAssertTrue(element("Bats").exists)
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
