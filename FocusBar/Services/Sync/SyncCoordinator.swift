import Foundation
import Observation
import AppKit

/// Optional multi-Mac sync through a user-selected folder (for example a
/// folder in iCloud Drive). FocusBar itself makes no network requests; the
/// folder provider syncs the small JSON snapshots.
@MainActor
@Observable
final class SyncCoordinator {
    private(set) var isSyncing = false
    private(set) var lastError: String?
    private(set) var lastWarning: String?
    private(set) var lastSyncAt: Date?
    private(set) var syncDetail: String?

    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let stats: StatsStore
    @ObservationIgnored private let captures: CaptureStore
    @ObservationIgnored private let intentions: IntentionStore
    @ObservationIgnored private let blockedAttempts: BlockedAttemptStore
    @ObservationIgnored private let engine: FolderSyncEngine
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private let canApplySharedSettings: @MainActor () -> Bool

    @ObservationIgnored private var state = SyncState()
    @ObservationIgnored private var didLoadState = false
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var folderURL: URL?
    @ObservationIgnored private var scopedURL: URL?
    @ObservationIgnored private var periodicTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherSync = false
    @ObservationIgnored private var syncGeneration = 0
    @ObservationIgnored private var runningGeneration: Int?

    init(
        persistence: PersistenceController,
        settings: SettingsStore,
        stats: StatsStore,
        captures: CaptureStore,
        intentions: IntentionStore,
        blockedAttempts: BlockedAttemptStore,
        canApplySharedSettings: @escaping @MainActor () -> Bool = { true },
        engine: FolderSyncEngine = FolderSyncEngine(),
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.persistence = persistence
        self.settings = settings
        self.stats = stats
        self.captures = captures
        self.intentions = intentions
        self.blockedAttempts = blockedAttempts
        self.canApplySharedSettings = canApplySharedSettings
        self.engine = engine
        self.dateProvider = dateProvider
    }

    var isEnabled: Bool {
        settings.settings.syncEnabled
    }

    var folderDisplayPath: String {
        settings.settings.syncFolderPath ?? "No folder selected"
    }

    var statusText: String {
        if !isEnabled { return "Off" }
        if isSyncing { return "Syncing…" }
        if lastError != nil { return "Couldn't sync" }
        guard let lastSyncAt else { return "Waiting for first sync" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Synced \(formatter.localizedString(for: lastSyncAt, relativeTo: dateProvider()))"
    }

    func start() async {
        guard !didStart else { return }
        didStart = true

        await loadState()
        wireCallbacks()

        guard settings.settings.syncEnabled else { return }

        // Keep retrying if iCloud Drive is temporarily unavailable. If no
        // folder has ever been chosen, there is nothing to retry.
        if settings.settings.syncFolderPath != nil || settings.settings.syncFolderBookmark != nil {
            startPeriodicSync()
        }

        guard resolveFolder() else { return }
        await settings.ensureSharedSettingsTimestamp()
        await syncNow()
    }

    /// Called when the user picks a folder. Enabling is explicit consent to
    /// write the sync snapshots into that folder.
    func enable(folderURL: URL) async {
        let standardized = folderURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              FileManager.default.isWritableFile(atPath: standardized.path) else {
            lastError = "That folder isn't writable. Choose another folder."
            return
        }

        stopScopedAccess()
        syncGeneration += 1
        let bookmark = makeBookmark(for: standardized)

        await settings.update {
            $0.syncEnabled = true
            $0.syncFolderPath = standardized.path
            $0.syncFolderBookmark = bookmark
        }
        await settings.ensureSharedSettingsTimestamp()

        self.folderURL = standardized
        if standardized.startAccessingSecurityScopedResource() {
            scopedURL = standardized
        }

        lastError = nil
        lastWarning = nil
        startPeriodicSync()
        await syncNow()
    }

    /// Re-enables using the folder already stored in settings.
    func enableStoredFolder() async {
        syncGeneration += 1
        guard resolveFolder() else { return }
        await settings.update { $0.syncEnabled = true }
        await settings.ensureSharedSettingsTimestamp()
        lastError = nil
        lastWarning = nil
        startPeriodicSync()
        await syncNow()
    }

    func disable() async {
        syncGeneration += 1
        await settings.update { $0.syncEnabled = false }
        scheduledTask?.cancel()
        scheduledTask = nil
        periodicTask?.cancel()
        periodicTask = nil
        stopScopedAccess()
        folderURL = nil
        needsAnotherSync = false
        isSyncing = false
        runningGeneration = nil
        lastError = nil
        lastWarning = nil
        syncDetail = nil
    }

    func syncNow() async {
        guard didStart, settings.settings.syncEnabled else { return }

        if folderURL == nil {
            guard resolveFolder() else { return }
        }
        guard let folderURL else { return }

        if isSyncing {
            needsAnotherSync = true
            return
        }

        isSyncing = true
        needsAnotherSync = false
        lastError = nil
        lastWarning = nil
        let generation = syncGeneration
        runningGeneration = generation

        do {
            let local = makeSnapshot()
            let outcome = try await engine.sync(local: local, folderURL: folderURL)

            // The user may have disabled sync or switched folders while the
            // engine was working. Do not apply stale results.
            guard generation == syncGeneration, settings.settings.syncEnabled else {
                finishStaleSync(generation)
                return
            }

            await apply(outcome)

            state.deletions = outcome.snapshot.deletions
            state.lastSyncAt = dateProvider()
            await saveState()

            lastSyncAt = state.lastSyncAt
            lastWarning = outcome.warnings.first
            syncDetail = outcome.otherDeviceCount == 0
                ? "Only this Mac so far"
                : "\(outcome.otherDeviceCount) other Mac\(outcome.otherDeviceCount == 1 ? "" : "s")"
        } catch {
            guard generation == syncGeneration else {
                finishStaleSync(generation)
                return
            }
            lastError = error.localizedDescription
            syncDetail = nil
        }

        if runningGeneration == generation {
            isSyncing = false
            runningGeneration = nil
        }
        if needsAnotherSync {
            scheduleSync(delay: 1)
        }
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Deletions

    func recordDeletion(kind: String, id: UUID) async {
        let key = SyncState.key(kind: kind, id: id)
        let now = dateProvider()
        state.deletions[key] = max(state.deletions[key] ?? .distantPast, now)
        await saveState()
        scheduleSync(delay: 2)
    }

    // MARK: - Private

    private func wireCallbacks() {
        stats.onLocalChange = { [weak self] in
            self?.scheduleSync(delay: 3)
        }
        captures.onLocalChange = { [weak self] in
            self?.scheduleSync(delay: 3)
        }
        intentions.onLocalChange = { [weak self] in
            self?.scheduleSync(delay: 3)
        }
        blockedAttempts.onLocalChange = { [weak self] in
            // Blocking history changes frequently during a session. Coalesce
            // these writes so iCloud Drive isn't asked to upload constantly.
            self?.scheduleSync(delay: 30)
        }
        settings.onLocalChange = { [weak self] in
            self?.scheduleSync(delay: 3)
        }
        captures.onDelete = { [weak self] id in
            await self?.recordDeletion(kind: "capture", id: id)
        }
        intentions.onDelete = { [weak self] id in
            await self?.recordDeletion(kind: "intention", id: id)
        }
    }

    private func makeSnapshot() -> SyncSnapshot {
        SyncSnapshot(
            schemaVersion: SyncSnapshot.schemaVersion,
            deviceID: state.deviceID,
            sessions: stats.sessions,
            captures: captures.captures,
            intentions: intentions.intentions,
            skippedDays: intentions.skippedDays.sorted(),
            blockedAttempts: blockedAttempts.attempts,
            sharedSettings: settings.sharedSettingsSnapshot,
            deletions: state.deletions
        )
    }

    private func apply(_ outcome: SyncOutcome) async {
        let merged = outcome.snapshot
        await stats.applySynced(merged.sessions)
        await captures.applySynced(merged.captures)
        await intentions.applySynced(
            intentions: merged.intentions,
            skippedDays: Set(merged.skippedDays)
        )
        await blockedAttempts.applySynced(merged.blockedAttempts)

        if let shared = merged.sharedSettings,
           shared.updatedAt > (settings.settings.sharedSettingsUpdatedAt ?? .distantPast),
           canApplySharedSettings() {
            await settings.applySharedSettings(shared)
        }
        // If a session is active, the newer shared settings stay in the
        // synced snapshot and are applied after the session ends.
    }

    private func loadState() async {
        guard !didLoadState else { return }
        didLoadState = true

        if let loaded = await persistence.load(SyncState.self, from: "syncState.json") {
            state = loaded
        } else {
            state = SyncState()
            await saveState()
        }
        lastSyncAt = state.lastSyncAt
    }

    private func saveState() async {
        do {
            try await persistence.save(state, to: "syncState.json")
        } catch {
            lastError = "Couldn't save sync bookkeeping: \(error.localizedDescription)"
        }
    }

    private func resolveFolder() -> Bool {
        stopScopedAccess()
        folderURL = nil

        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let bookmark = settings.settings.syncFolderBookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                candidates.append(url)
            } else if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                candidates.append(url)
            }
        }

        if let path = settings.settings.syncFolderPath {
            candidates.append(URL(fileURLWithPath: path, isDirectory: true))
        }

        for candidate in candidates {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  fileManager.isWritableFile(atPath: candidate.path) else {
                continue
            }
            folderURL = candidate
            if candidate.startAccessingSecurityScopedResource() {
                scopedURL = candidate
            }
            return true
        }

        lastError = "Choose the sync folder again. It may have moved or iCloud Drive may be unavailable."
        return false
    }

    private func makeBookmark(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }
        return try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func finishStaleSync(_ generation: Int) {
        guard runningGeneration == generation else { return }
        isSyncing = false
        runningGeneration = nil
        if needsAnotherSync {
            scheduleSync(delay: 1)
        }
    }

    private func stopScopedAccess() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private func startPeriodicSync() {
        periodicTask?.cancel()
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.syncNow()
            }
        }
    }

    private func scheduleSync(delay: TimeInterval) {
        guard settings.settings.syncEnabled else { return }
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    deinit {
        scheduledTask?.cancel()
        periodicTask?.cancel()
        scopedURL?.stopAccessingSecurityScopedResource()
    }
}
