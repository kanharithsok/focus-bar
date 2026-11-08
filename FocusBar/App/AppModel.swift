import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class AppModel {
    let persistence: PersistenceController
    let settings: SettingsStore
    let stats: StatsStore
    let sessionManager: SessionManager

    private(set) var startupWarning: String?
    private(set) var hasStarted = false

    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init() {
        let persistence = PersistenceController()
        let settings = SettingsStore(persistence: persistence)
        let stats = StatsStore(persistence: persistence)
        let sessionManager = SessionManager(
            persistence: persistence,
            statsStore: stats,
            settingsStore: settings
        )

        self.persistence = persistence
        self.settings = settings
        self.stats = stats
        self.sessionManager = sessionManager

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
        await sessionManager.restore()

        let issues = await persistence.consumeLoadIssues()
        startupWarning = issues.first
    }

    func dismissStartupWarning() {
        startupWarning = nil
    }

    var combinedError: String? {
        startupWarning ?? sessionManager.lastError ?? stats.lastError ?? settings.lastError
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
