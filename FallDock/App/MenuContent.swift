import SwiftUI

/// The 🎃 menu in the menu bar.
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text(model.smashCount == 1 ? "1 pumpkin smashed" : "\(model.smashCount) pumpkins smashed")
        if model.goldenCount > 0 {
            Text(model.goldenCount == 1 ? "✨ 1 golden pumpkin found" : "✨ \(model.goldenCount) golden pumpkins found")
        }

        Divider()

        Toggle("Show Pumpkins", isOn: $model.showPumpkins)
        Toggle("Vines", isOn: $model.showVines)
        Toggle("Cozy Extras", isOn: $model.cozyExtras)
        Toggle("Falling Leaves", isOn: $model.fallingLeaves)
        Toggle("Sounds", isOn: $model.sound)

        Picker("Jack-o'-Lanterns", selection: $model.jackOLanterns) {
            ForEach(Settings.JackOLanterns.allCases, id: \.self) { Text($0.title).tag($0) }
        }

        Picker("How Full", selection: $model.fullness) {
            ForEach(Settings.Fullness.allCases, id: \.self) { Text($0.title).tag($0) }
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
