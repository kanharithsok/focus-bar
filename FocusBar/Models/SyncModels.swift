import Foundation

/// Settings that make sense on every Mac. Device-specific state such as the
/// privileged helper toggle, browser restart, and sync configuration stays in
/// the local settings file.
struct SharedSettingsSnapshot: Codable, Equatable, Sendable {
    var updatedAt: Date
    var commitMode: Bool
    var blockApps: Bool
    var blockWebsites: Bool
    var blockDuringScatterfocus: Bool
    var notificationsEnabled: Bool
    var appBlockingAction: AppBlockingAction
    var earlyEndDelaySeconds: Int
    var presets: [BlocklistPreset]
    var selectedPresetID: UUID?

    init(settings: AppSettings, updatedAt: Date? = nil) {
        self.updatedAt = updatedAt ?? settings.sharedSettingsUpdatedAt ?? .distantPast
        commitMode = settings.commitMode
        blockApps = settings.blockApps
        blockWebsites = settings.blockWebsites
        blockDuringScatterfocus = settings.blockDuringScatterfocus
        notificationsEnabled = settings.notificationsEnabled
        appBlockingAction = settings.appBlockingAction
        earlyEndDelaySeconds = settings.earlyEndDelaySeconds
        presets = settings.presets
        selectedPresetID = settings.selectedPresetID
    }

    func apply(to settings: inout AppSettings) {
        settings.commitMode = commitMode
        settings.blockApps = blockApps
        settings.blockWebsites = blockWebsites
        settings.blockDuringScatterfocus = blockDuringScatterfocus
        settings.notificationsEnabled = notificationsEnabled
        settings.appBlockingAction = appBlockingAction
        settings.earlyEndDelaySeconds = earlyEndDelaySeconds
        settings.presets = presets
        settings.selectedPresetID = selectedPresetID
        settings.sharedSettingsUpdatedAt = updatedAt
    }
}

/// One device's complete view of the synced data. Each device only writes its
/// own file, so concurrent Macs never overwrite one another.
struct SyncSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    var schemaVersion: Int
    var deviceID: UUID
    var sessions: [SessionRecord]
    var captures: [Capture]
    var intentions: [DailyIntention]
    var skippedDays: [Date]
    var blockedAttempts: [BlockedAttempt]
    var sharedSettings: SharedSettingsSnapshot?
    /// Keys are `capture:<UUID>` or `intention:<UUID>`. Tombstones are kept
    /// indefinitely; they prevent a deleted record from being re-imported from
    /// another Mac's older snapshot.
    var deletions: [String: Date]

    init(
        schemaVersion: Int = SyncSnapshot.schemaVersion,
        deviceID: UUID,
        sessions: [SessionRecord],
        captures: [Capture],
        intentions: [DailyIntention],
        skippedDays: [Date],
        blockedAttempts: [BlockedAttempt],
        sharedSettings: SharedSettingsSnapshot?,
        deletions: [String: Date]
    ) {
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.sessions = sessions
        self.captures = captures
        self.intentions = intentions
        self.skippedDays = skippedDays
        self.blockedAttempts = blockedAttempts
        self.sharedSettings = sharedSettings
        self.deletions = deletions
    }
}

/// Device-local sync bookkeeping. Never written to the shared folder.
struct SyncState: Codable, Equatable, Sendable {
    var deviceID: UUID
    var deletions: [String: Date]
    var lastSyncAt: Date?

    init(
        deviceID: UUID = UUID(),
        deletions: [String: Date] = [:],
        lastSyncAt: Date? = nil
    ) {
        self.deviceID = deviceID
        self.deletions = deletions
        self.lastSyncAt = lastSyncAt
    }

    static func key(kind: String, id: UUID) -> String {
        "\(kind):\(id.uuidString)"
    }
}

struct SyncOutcome: Sendable {
    var snapshot: SyncSnapshot
    var otherDeviceCount: Int
    var warnings: [String]
}
