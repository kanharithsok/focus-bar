import AppKit

@MainActor
final class AppBlocker: Blocker {
    let id = "app"
    let displayName = "Application blocking"

    private(set) var isRunning = false

    private var configuration: BlockerConfiguration?
    private var observers: [NSObjectProtocol] = []
    private var dedup = BlockedAttemptDeduplicator(cooldown: 8)

    var onBlocked: ((BlockedEvent) -> Void)?

    func start(configuration: BlockerConfiguration) {
        stop()
        guard !configuration.appBundleIDs.isEmpty else { return }

        self.configuration = configuration
        // Quit requests are more disruptive than hiding, so retry them less often.
        dedup = BlockedAttemptDeduplicator(
            cooldown: configuration.appAction == .requestTerminate ? 30 : 8
        )
        let center = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didActivateApplicationNotification
        ]

        for name in names {
            let observer = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                Task { @MainActor in
                    self?.handle(app)
                }
            }
            observers.append(observer)
        }

        isRunning = true
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        configuration = nil
        isRunning = false
        dedup.resetAll()
    }

    private func handle(_ app: NSRunningApplication) {
        guard let configuration,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier,
              configuration.appBundleIDs.contains(bundleID)
        else {
            return
        }

        let now = Date()
        guard dedup.shouldRecord(key: bundleID, value: "event", at: now) else {
            return
        }

        let detail: String
        switch configuration.appAction {
        case .hide:
            _ = app.hide()
            detail = app.isHidden
                ? "App hidden."
                : "Hide requested; the app may still be visible."
        case .requestTerminate:
            _ = app.terminate()
            detail = app.isTerminated
                ? "App quit."
                : "Normal quit requested; the app may refuse."
        }

        onBlocked?(
            BlockedEvent(
                kind: .application,
                identifier: bundleID,
                displayName: app.localizedName ?? bundleID,
                browserName: nil,
                detail: detail
            )
        )
    }
}
