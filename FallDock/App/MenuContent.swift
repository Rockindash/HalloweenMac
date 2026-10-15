import SwiftUI

/// The pumpkin menu in the menu bar. Finer settings live in the app window.
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Open Dockorate…") { model.showMainWindow() }
            .keyboardShortcut(",")

        Divider()

        if !model.license.isActive {
            Button("Enter License Key") { model.showMainWindow() }
            Divider()
        }

        if model.isPaused {
            Button("Resume") { model.resume() }
        } else {
            Button("Pause for 1 Hour") { model.pauseForAnHour() }
        }
        Menu("Theme") {
            Toggle("Change Automatically", isOn: Binding(get: { model.themeChoice == .automatic },
                                                         set: { model.themeChoice = $0 ? .automatic : .keep(model.theme) }))
            ForEach(Settings.Theme.Kind.allCases, id: \.self) { kind in
                Section(kind.title) {
                    ForEach(Settings.Theme.allCases.filter { $0.kind == kind }, id: \.self) { theme in
                        Toggle(theme.title, isOn: Binding(get: { model.themeChoice == .keep(theme) },
                                                          set: { if $0 { model.themeChoice = .keep(theme) } }))
                    }
                }
            }
        }
        if !model.hasAccessibility {
            Button("Fit Pumpkins to Dock Exactly…") { model.askForAccessibility() }
        }
        if model.theme == .fall {
            Toggle("Full-Screen Leaves", isOn: $model.leavesFillScreen)
        }
        Toggle("Open at Login", isOn: $model.openAtLogin)

        Divider()

        if Updater.isAvailable {
            Button("Check for Updates") { model.updater.checkForUpdates() }
        }
        Button("Quit Dockorate") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
