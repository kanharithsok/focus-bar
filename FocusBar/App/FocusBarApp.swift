import SwiftUI

@main
struct FocusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

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
