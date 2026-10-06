import SwiftUI

/// The pumpkin menu in the menu bar. Finer settings live in the app window.
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Open Dockorate…") { model.showMainWindow() }
            .keyboardShortcut(",")

        Divider()

        if model.isPaused {
            Button("Resume") { model.resume() }
        } else {
            Button("Pause for 1 Hour") { model.pauseForAnHour() }
        }
        if !model.hasAccessibility {
            Button("Fit Pumpkins to Dock Exactly…") { model.askForAccessibility() }
        }
        Toggle("Full-Screen Leaves", isOn: $model.leavesFillScreen)
        Toggle("Open at Login", isOn: $model.openAtLogin)

        Divider()

        Button("Quit Dockorate") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
