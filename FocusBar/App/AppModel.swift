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
    let blockedAttempts: BlockedAttemptStore
    let sessionManager: SessionManager
    let blockingEngine: BlockingEngine
    let systemBlockingService: SystemBlockingService
    let systemBlockingClient: SystemBlockingClient
    let mozillaRestarter: MozillaBrowserRestarter
    let capturePanel: CapturePanelController
    let notifications: NotificationService
    let loginItem: LoginItemManager
    let sync: SyncCoordinator

    private(set) var startupWarning: String?
    private(set) var hasStarted = false

    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init() {
        let persistence: PersistenceController
        #if DEBUG
        if let testDirectory = ProcessInfo.processInfo.environment["FOCUSBAR_UI_TEST_DIR"] {
            persistence = PersistenceController(
                directory: URL(fileURLWithPath: testDirectory, isDirectory: true)
            )
        } else {
            persistence = PersistenceController()
        }
        #else
        persistence = PersistenceController()
        #endif
        let settings = SettingsStore(persistence: persistence)
        let stats = StatsStore(persistence: persistence)
        let captures = CaptureStore(persistence: persistence)
        let intentions = IntentionStore(persistence: persistence)
        let blockedAttempts = BlockedAttemptStore(persistence: persistence)
        let notifications = NotificationService()
        let loginItem = LoginItemManager()
        let sessionManager = SessionManager(
            persistence: persistence,
            statsStore: stats,
            settingsStore: settings
        )
        let sync = SyncCoordinator(
            persistence: persistence,
            settings: settings,
            stats: stats,
            captures: captures,
            intentions: intentions,
            blockedAttempts: blockedAttempts,
            canApplySharedSettings: { [weak sessionManager] in
                sessionManager?.activeSession == nil
            }
        )
        let systemBlockingService = SystemBlockingService()
        let systemBlockingClient = SystemBlockingClient(service: systemBlockingService)
        let mozillaRestarter = MozillaBrowserRestarter()
        let blockingEngine = BlockingEngine(
            attemptStore: blockedAttempts,
            notifications: notifications,
            systemBlocking: systemBlockingClient
        )

        self.persistence = persistence
        self.settings = settings
        self.stats = stats
        self.captures = captures
        self.intentions = intentions
        self.blockedAttempts = blockedAttempts
        self.sessionManager = sessionManager
        self.blockingEngine = blockingEngine
        self.systemBlockingService = systemBlockingService
        self.systemBlockingClient = systemBlockingClient
        self.mozillaRestarter = mozillaRestarter
        self.capturePanel = CapturePanelController()
        self.notifications = notifications
        self.loginItem = loginItem
        self.sync = sync

        sessionManager.onSessionStarted = { [weak self] session in
            self?.beginBlocking(for: session)
        }
        sessionManager.onSessionEnded = { [weak self] record in
            self?.endBlocking(record: record)
        }
        sessionManager.onBlockingSuspensionChanged = { [weak self] suspended in
            self?.blockingEngine.setSuspended(suspended)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.sessionManager.refresh()
                await self?.sync.syncNow()
            }
        }

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.sync.syncNow()
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
        await blockedAttempts.load()
        systemBlockingService.refresh()
        await sessionManager.restore()
        await sync.start()
        loginItem.refresh()

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

    func dismissError() {
        startupWarning = nil
        sessionManager.clearError()
        blockingEngine.clearError()
        systemBlockingService.clearError()
        systemBlockingClient.clearError()
        mozillaRestarter.clearError()
        sync.clearError()
        blockedAttempts.clearError()
        stats.clearError()
        captures.clearError()
        intentions.clearError()
        settings.clearError()
    }

    var combinedError: String? {
        let errors: [String?] = [
            startupWarning,
            sessionManager.lastError,
            blockingEngine.lastError,
            systemBlockingService.lastError,
            systemBlockingClient.lastError,
            mozillaRestarter.lastError,
            sync.lastError,
            blockedAttempts.lastError,
            stats.lastError,
            captures.lastError,
            intentions.lastError,
            settings.lastError
        ]
        return errors.compactMap { $0 }.first
    }

    var dataDirectory: URL {
        persistence.directory
    }

    func openAutomationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Shared-folder sync is opt-in. The panel starts in iCloud Drive when it
    /// is available; any folder works, including Dropbox or an external drive.
    func chooseSyncFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder that syncs between your Macs. For iCloud Drive, choose or create a FocusBar folder."
        panel.directoryURL = iCloudDriveURL

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, var url = panel.url else { return }

        // Selecting the iCloud Drive root should not scatter FocusBar's files
        // among the user's documents.
        if url.lastPathComponent == "com~apple~CloudDocs" {
            url = url.appendingPathComponent("FocusBar", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        await sync.enable(folderURL: url)
    }

    func setSyncEnabled(_ enabled: Bool) async {
        if enabled {
            if settings.settings.syncFolderPath != nil {
                await sync.enableStoredFolder()
            } else {
                await chooseSyncFolder()
            }
        } else {
            await sync.disable()
        }
    }

    private var iCloudDriveURL: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func beginBlocking(for session: ActiveSession) {
        notifications.requestAuthorizationIfNeeded(enabled: settings.settings.notificationsEnabled)
        blockingEngine.start(
            session: session,
            preset: settings.preset(id: session.blocklistPresetID),
            settings: settings.settings
        )

        if settings.settings.systemWideWebsiteBlockingEnabled,
           settings.settings.restartMozillaBrowsersOnSessionChange {
            mozillaRestarter.restartWhenBlockStateChanges(expectedBlocked: true)
        }
    }

    private func endBlocking(record: SessionRecord) {
        blockingEngine.stop()

        if settings.settings.systemWideWebsiteBlockingEnabled,
           settings.settings.restartMozillaBrowsersOnSessionChange {
            mozillaRestarter.restartWhenBlockStateChanges(expectedBlocked: false)
        }

        guard settings.settings.notificationsEnabled else { return }
        let title = record.kind == .hyperfocus ? "Hyperfocus ended" : "Break ended"
        let minutes = SessionTimer.roundedMinutes(record.actualDuration)
        notifications.notify(
            title: title,
            body: "\(record.focusObject) · \(minutes) min · \(record.status.displayName)"
        )
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
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }
}
