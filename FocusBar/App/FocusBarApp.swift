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
    }
}
