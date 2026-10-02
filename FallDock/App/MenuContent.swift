import SwiftUI

/// The 🎃 menu in the menu bar.
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.smashCount == 1 ? "1 pumpkin smashed" : "\(model.smashCount) pumpkins smashed")

        Divider()

        Toggle("Show Pumpkins", isOn: $model.showPumpkins)
        Toggle("Vines", isOn: $model.showVines)
        Toggle("Falling Leaves", isOn: $model.fallingLeaves)
        Toggle("Smash Sound", isOn: $model.sound)

        Picker("Number of Pumpkins", selection: $model.pumpkinCount) {
            Text("A Few (5)").tag(5)
            Text("Plenty (9)").tag(9)
            Text("Overflowing (13)").tag(13)
        }

        Button("Grow New Pumpkins") { model.regrow() }
            .keyboardShortcut("r")

        Divider()

        if !model.hasAccessibility {
            Button("Fit Pumpkins to Dock Exactly…") { model.askForAccessibility() }
        }
        Toggle("Open at Login", isOn: $model.openAtLogin)

        Divider()

        Button("Quit Fall Dock") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
