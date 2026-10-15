# Working on Dockorate

## Every feature and fix comes with a test

When you add a feature or fix a bug, add a test for it in the same change, whenever it can be tested:

- **Logic, settings, layout, art, file handling:** a unit test in `DockorateTests/`, next to the tests for the same area. Settings tests subclass `SettingsTestCase` so they never touch real settings.
- **Something people click or see in the app window:** a UI test in `DockorateUITests/DockorateUITests.swift`. Give new controls a `SettingRow` title or an `.accessibilityIdentifier` so the tests can find them. Use the helpers there (`toggle`, `setSwitch`, `reveal`, `open`).
- **A bug fix:** the test should fail before the fix and pass after it.
- **Not testable** (for example, the real desktop picture, the Dock's position on screen, Sparkle, notarization): say so in the commit or PR description, with the reason.

Tests must never touch the person's real settings, license, desktop picture or login items. Unit tests run inside the app with `AppEnvironment.isUnitTesting`. UI tests launch with `-UITesting` (see `FallDock/App/AppEnvironment.swift`).

The tests run on GitHub for every push and pull request (`.github/workflows/tests.yml`). A change isn't done until that run is green. Never skip, disable or weaken an existing test to get it green. If an old test breaks, the new code broke something, or the test needs a real update that you explain.

## Project facts

- The Xcode project, scheme and target are still named `FallDock`; the app is Dockorate (`com.amol.dockorate`).
- The app icon is an Icon Composer file, so building needs Xcode 26 (CI uses `macos-26`).
- See README.md for the file layout, releasing and the test commands.
