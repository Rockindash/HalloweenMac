import SwiftUI

/// The 🎃 menu in the menu bar.
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.smashCount == 1 ? "1 pumpkin smashed" : "\(model.smashCount) pumpkins smashed")

        Divider()

        Button("Open Fall Dock…") { model.showMainWindow() }
            .keyboardShortcut(",")

        Divider()

        Toggle("Show Pumpkins", isOn: $model.showPumpkins)
        Toggle("Vines", isOn: $model.showVines)
        Toggle("Cozy Extras", isOn: $model.cozyExtras)
        Toggle("Falling Leaves", isOn: $model.fallingLeaves)
        Toggle("Smash Sound", isOn: $model.sound)

        Picker("How Full", selection: $model.fullness) {
            ForEach(Settings.Fullness.allCases, id: \.self) { Text($0.title).tag($0) }
        }

        Button("Grow New Pumpkins") { model.regrow() }
            .keyboardShortcut("r")
        if model.isPaused {
            Button("Resume") { model.resume() }
        } else {
            Button("Pause for 1 Hour") { model.pauseForAnHour() }
        }

        Divider()

        if !model.hasAccessibility {
            Button("Fit Pumpkins to Dock Exactly…") { model.askForAccessibility() }
        }
        Toggle("Open at Login", isOn: $model.openAtLogin)
        Button("Welcome to Fall Dock…") { model.showWelcome() }

        Divider()

        Button("Quit Fall Dock") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
