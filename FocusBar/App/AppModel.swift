import Foundation
import Observation
import AppKit
import KeyboardShortcuts

@MainActor
@Observable
final class AppModel {
    let persistence: PersistenceController
    let settings: SettingsStore
    let stats: StatsStore
    let captures: CaptureStore
    let intentions: IntentionStore
    let sessionManager: SessionManager
    let capturePanel: CapturePanelController

    private(set) var startupWarning: String?
    private(set) var hasStarted = false

    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init() {
        let persistence = PersistenceController()
        let settings = SettingsStore(persistence: persistence)
        let stats = StatsStore(persistence: persistence)
        let captures = CaptureStore(persistence: persistence)
        let intentions = IntentionStore(persistence: persistence)
        let sessionManager = SessionManager(
            persistence: persistence,
            statsStore: stats,
            settingsStore: settings
        )

        self.persistence = persistence
        self.settings = settings
        self.stats = stats
        self.captures = captures
        self.intentions = intentions
        self.sessionManager = sessionManager
        self.capturePanel = CapturePanelController()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.sessionManager.refresh()
            }
        }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        await settings.load()
        await stats.load()
        await captures.load()
        await intentions.load()
        await sessionManager.restore()

        let issues = await persistence.consumeLoadIssues()
        startupWarning = issues.first

        KeyboardShortcuts.onKeyUp(for: .captureDistraction) { [weak self] in
            Task { @MainActor in
                self?.showCapturePanel()
            }
        }
    }

    func showCapturePanel() {
        let active = sessionManager.activeSession
        capturePanel.show(focusObject: active?.focusObject) { [weak self] text in
            guard let self else { return }
            let sessionID = self.sessionManager.activeSession?.id
            Task {
                await self.captures.add(
                    text: text,
                    sessionID: sessionID,
                    source: .distraction
                )
            }
        }
    }

    func dismissStartupWarning() {
        startupWarning = nil
    }

    var combinedError: String? {
        startupWarning
            ?? sessionManager.lastError
            ?? stats.lastError
            ?? captures.lastError
            ?? intentions.lastError
            ?? settings.lastError
    }

    /// Emergency escape. Requires confirmation but bypasses Commit Mode's normal
    /// early-end path. FocusBar cannot prevent force quitting or restarting macOS.
    func emergencyStop() async {
        guard let session = sessionManager.activeSession else { return }

        let alert = NSAlert()
        alert.messageText = "End this session immediately?"
        alert.informativeText = """
        "\(session.focusObject)" will be recorded as an emergency stop.

        FocusBar cannot prevent you from force quitting the app or restarting your Mac.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "End Session")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try await sessionManager.endEarly(reason: "Emergency stop", emergency: true)
        } catch {
            sessionManager.noteError(error.localizedDescription)
        }
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
