import SwiftUI

@main
struct FocusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        // Restore an active session and start blocking at launch, even before
        // the user opens the menu-bar popover.
        Task { @MainActor in
            await model.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environment(model)
                .task { await model.start() }
        } label: {
            MenuBarLabel(sessionManager: model.sessionManager)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandMenu("Session") {
                Button("Emergency Stop…") {
                    Task { await model.emergencyStop() }
                }
                .disabled(model.sessionManager.activeSession == nil)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
