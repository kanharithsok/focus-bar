import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement is set in Info.plist; setting the policy again keeps the
        // behavior correct when launched from Xcode or a debug session.
        NSApp.setActivationPolicy(.accessory)

        // Make the bundled app icon explicit for AppKit surfaces such as the
        // emergency alert. Notification Center normally resolves the bundle
        // icon through LaunchServices, but this also keeps the running app's
        // icon in sync with the asset catalog.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
