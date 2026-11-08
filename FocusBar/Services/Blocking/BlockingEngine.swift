import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class BlockingEngine {
    struct Status: Equatable {
        var isActive = false
        var appBlockingEnabled = false
        var websiteBlockingEnabled = false
        var suspended = false
        var appCount = 0
        var domainCount = 0
        var browserPermission: BrowserAutomationPermission = .unknown
        var browserNames: [String] = []
        var notes: [String] = []
    }

    private(set) var status = Status()
    private(set) var lastError: String?

    @ObservationIgnored private let attemptStore: BlockedAttemptStore
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let appBlocker: AppBlocker
    @ObservationIgnored private let browserBlocker: BrowserBlocker

    @ObservationIgnored private var currentSession: ActiveSession?
    @ObservationIgnored private var currentSettings: AppSettings?
    @ObservationIgnored private var currentPreset: BlocklistPreset?
    @ObservationIgnored private var websiteBlockerConfigured = false

    /// Both blockers share the same protocol and can be replaced independently.
    var registeredBlockers: [any Blocker] {
        [appBlocker, browserBlocker]
    }

    init(attemptStore: BlockedAttemptStore, notifications: NotificationService) {
        self.attemptStore = attemptStore
        self.notifications = notifications
        self.appBlocker = AppBlocker()
        self.browserBlocker = BrowserBlocker()

        appBlocker.onBlocked = { [weak self] event in
            self?.handleBlocked(event)
        }
        browserBlocker.onBlocked = { [weak self] event in
            self?.handleBlocked(event)
        }
        browserBlocker.onPermissionChanged = { [weak self] permission in
            guard let self else { return }
            self.status.browserPermission = permission
            if self.status.isActive, self.websiteBlockerConfigured {
                self.status.websiteBlockingEnabled = permission != .denied && permission != .timedOut
            }
        }
        browserBlocker.onRedirectFailure = { [weak self] message in
            self?.handleBrowserFailure(message)
        }
    }

    func start(
        session: ActiveSession,
        preset: BlocklistPreset?,
        settings: AppSettings
    ) {
        currentSession = session
        currentPreset = preset
        currentSettings = settings
        lastError = nil
        applyConfiguration()
    }

    func stop() {
        appBlocker.stop()
        browserBlocker.stop()
        currentSession = nil
        currentSettings = nil
        currentPreset = nil
        websiteBlockerConfigured = false
        status = Status()
        lastError = nil
    }

    func setSuspended(_ suspended: Bool) {
        guard var session = currentSession else { return }
        session.blockingSuspended = suspended
        currentSession = session
        applyConfiguration()
    }

    func retryBrowserPermission() {
        browserBlocker.retryPermissionCheck()
        status.browserPermission = browserBlocker.permission
    }

    private func applyConfiguration() {
        appBlocker.stop()
        browserBlocker.stop()

        guard let session = currentSession, let settings = currentSettings else {
            status = Status()
            return
        }

        let blockedPageURL = Bundle.main.url(forResource: "blocked", withExtension: "html")
        let plan = BlockingPlan.make(
            session: session,
            preset: currentPreset,
            settings: settings,
            blockedPageAvailable: blockedPageURL != nil
        )

        let domains = currentPreset?.normalizedWebsiteDomains ?? []
        let apps = currentPreset?.apps ?? []

        let configuration = BlockerConfiguration(
            sessionID: session.id,
            websiteDomains: domains,
            appBundleIDs: apps.map(\.bundleID),
            appAction: settings.appBlockingAction,
            blockedPageURL: blockedPageURL
        )

        websiteBlockerConfigured = plan.websiteBlockingEnabled

        if plan.appBlockingEnabled {
            appBlocker.start(configuration: configuration)
        }
        if plan.websiteBlockingEnabled {
            browserBlocker.start(configuration: configuration)
        }

        let permission = browserBlocker.permission
        status = Status(
            isActive: true,
            appBlockingEnabled: plan.appBlockingEnabled,
            websiteBlockingEnabled: plan.websiteBlockingEnabled
                && permission != .denied
                && permission != .timedOut,
            suspended: plan.suspended,
            appCount: plan.appCount,
            domainCount: plan.domainCount,
            browserPermission: permission,
            browserNames: SupportedBrowsers.all.map(\.displayName),
            notes: plan.notes
        )
    }

    private func handleBlocked(_ event: BlockedEvent) {
        guard let session = currentSession else { return }

        let attempt = BlockedAttempt(
            timestamp: Date(),
            sessionID: session.id,
            kind: event.kind,
            identifier: event.identifier,
            displayName: event.displayName,
            browserName: event.browserName,
            actionDetail: event.detail
        )
        Task {
            await attemptStore.record(attempt)
        }

        if event.notify, currentSettings?.notificationsEnabled == true {
            notifications.notify(
                title: "FocusBar blocked an attempt",
                body: event.detail ?? event.displayName
            )
        } else {
            NSSound(named: "Tink")?.play()
        }
    }

    private func handleBrowserFailure(_ message: String) {
        lastError = message
        if currentSettings?.notificationsEnabled == true {
            notifications.notify(title: "FocusBar browser guard", body: message)
        } else {
            NSSound(named: "Basso")?.play()
        }
    }
}
