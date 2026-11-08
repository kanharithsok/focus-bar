import Foundation
import Observation

@MainActor
@Observable
final class SessionManager {
    private(set) var state: SessionState = .idle
    private(set) var now: Date
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored private let statsStore: StatsStore
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored private let automaticallyTicks: Bool
    @ObservationIgnored private var tickerTask: Task<Void, Never>?
    @ObservationIgnored private var didRestore = false

    @ObservationIgnored var onSessionStarted: ((ActiveSession) -> Void)?
    @ObservationIgnored var onSessionEnded: ((SessionRecord) -> Void)?
    @ObservationIgnored var onBlockingSuspensionChanged: ((Bool) -> Void)?

    init(
        persistence: PersistenceController,
        statsStore: StatsStore,
        settingsStore: SettingsStore,
        dateProvider: @escaping () -> Date = { Date() },
        automaticallyTicks: Bool = true
    ) {
        self.persistence = persistence
        self.statsStore = statsStore
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.automaticallyTicks = automaticallyTicks
        self.now = dateProvider()
    }

    // MARK: - Derived state

    var phase: SessionPhase { state.phase }
    var activeSession: ActiveSession? { state.activeSession }
    var pendingReview: SessionRecord? { state.pendingReview }
    var isActive: Bool { activeSession != nil }

    var remainingTime: TimeInterval {
        guard let session = activeSession else { return 0 }
        return SessionTimer.remaining(endDate: session.endDate, now: now)
    }

    var remainingText: String {
        SessionTimer.format(remainingTime)
    }

    var progress: Double {
        guard let session = activeSession else { return 0 }
        return SessionTimer.progress(startDate: session.startDate, endDate: session.endDate, now: now)
    }

    var menuBarTitle: String? {
        guard let session = activeSession else { return nil }
        switch session.kind {
        case .hyperfocus, .scatterfocus: return remainingText
        }
    }

    // MARK: - Starting sessions

    @discardableResult
    func startHyperfocus(
        focusObject: String,
        minutes: Int,
        intention: DailyIntention? = nil,
        preset: BlocklistPreset? = nil
    ) async throws -> ActiveSession {
        guard case .idle = state else { throw SessionError.invalidState }
        let trimmedFocus = focusObject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFocus.isEmpty else { throw SessionError.emptyFocusObject }
        guard (1...480).contains(minutes) else { throw SessionError.invalidDuration }

        let start = dateProvider()
        let duration = TimeInterval(minutes * 60)
        let session = ActiveSession(
            kind: .hyperfocus,
            focusObject: trimmedFocus,
            intentionID: intention?.id,
            intentionText: intention?.text,
            plannedDuration: duration,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            blocklistPresetID: preset?.id,
            blocklistName: preset?.name
        )

        state = .hyperfocus(session)
        now = start
        lastError = nil
        await persistState()
        startTickerIfNeeded()
        onSessionStarted?(session)
        return session
    }

    @discardableResult
    func startScatterfocus(
        mode: ScatterfocusMode,
        minutes: Int = 10,
        question: String? = nil,
        preset: BlocklistPreset? = nil
    ) async throws -> ActiveSession {
        guard case .idle = state else { throw SessionError.invalidState }
        guard (1...480).contains(minutes) else { throw SessionError.invalidDuration }

        let trimmedQuestion = question?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let focusObject: String
        if mode == .problemCrunching, !trimmedQuestion.isEmpty {
            focusObject = trimmedQuestion
        } else {
            focusObject = "Scatterfocus: \(mode.displayName)"
        }

        let start = dateProvider()
        let duration = TimeInterval(minutes * 60)
        let session = ActiveSession(
            kind: .scatterfocus,
            focusObject: focusObject,
            scatterfocusMode: mode,
            problemQuestion: trimmedQuestion.isEmpty ? nil : trimmedQuestion,
            plannedDuration: duration,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            blocklistPresetID: preset?.id,
            blocklistName: preset?.name
        )

        state = .scatterfocus(session)
        now = start
        lastError = nil
        await persistState()
        startTickerIfNeeded()
        onSessionStarted?(session)
        return session
    }

    // MARK: - Ending sessions

    /// Ends a Hyperfocus session early. Commit mode blocks the normal path; emergency
    /// stops are always allowed and are recorded as such.
    func endEarly(reason: String, emergency: Bool) async throws {
        guard let session = activeSession else { throw SessionError.noActiveSession }

        let current = dateProvider()
        if current >= session.endDate {
            await finishSession(status: .completed, actualEndDate: session.endDate, reason: nil)
            return
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if settingsStore.settings.commitMode && !emergency {
            throw SessionError.commitModeActive
        }
        if !emergency && trimmedReason.isEmpty {
            throw SessionError.reasonRequired
        }

        let finalReason = trimmedReason.isEmpty ? "Emergency stop" : trimmedReason
        let status: SessionStatus = emergency ? .emergencyStop : .endedEarly
        await finishSession(status: status, actualEndDate: current, reason: finalReason)
    }

    /// Breaks are low-stakes and can end immediately without a reason.
    func endScatterfocusEarly() async {
        guard case .scatterfocus(let session) = state else { return }
        let current = dateProvider()
        if current >= session.endDate {
            await finishSession(status: .completed, actualEndDate: session.endDate, reason: nil)
        } else {
            await finishSession(status: .endedEarly, actualEndDate: current, reason: nil)
        }
    }

    // MARK: - Review

    func submitReview(
        rating: Int?,
        note: String?,
        startBreakAfter: Bool = false
    ) async throws {
        guard case .review(var record) = state else { throw SessionError.invalidState }
        if let rating, !(1...5).contains(rating) {
            throw SessionError.invalidRating
        }

        record.rating = rating
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        record.note = trimmedNote.isEmpty ? nil : trimmedNote

        await statsStore.upsert(record)
        state = .idle
        now = dateProvider()
        await persistState()

        if startBreakAfter {
            do {
                try await startScatterfocus(
                    mode: .capture,
                    minutes: 10,
                    question: nil,
                    preset: settingsStore.selectedPreset
                )
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func skipReview() async {
        try? await submitReview(rating: nil, note: nil, startBreakAfter: false)
    }

    // MARK: - Break blocking

    func setBlockingSuspended(_ suspended: Bool) async throws {
        guard case .scatterfocus(var session) = state else { throw SessionError.invalidState }
        session.blockingSuspended = suspended
        state = .scatterfocus(session)
        await persistState()
        onBlockingSuspensionChanged?(suspended)
    }

    // MARK: - Timer / restore

    /// Recomputes remaining time from the absolute end date. Safe to call from
    /// the ticker, wake notification, or UI.
    func refresh() async {
        now = dateProvider()
        guard let session = activeSession else { return }
        if now >= session.endDate {
            await finishSession(status: .completed, actualEndDate: session.endDate, reason: nil)
        }
    }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        now = dateProvider()

        guard let file = await persistence.load(ActiveSessionFile.self, from: "activeSession.json") else {
            return
        }

        if let reviewID = file.pendingReviewID, let record = statsStore.record(id: reviewID) {
            state = .review(record)
            return
        }

        guard let session = file.activeSession else {
            await persistState()
            return
        }

        if now >= session.endDate {
            let existing = statsStore.record(id: session.id)
            let record = existing ?? makeRecord(
                from: session,
                status: .completed,
                actualEndDate: session.endDate,
                reason: nil
            )
            if existing == nil {
                await statsStore.upsert(record)
            }

            let endedRecently = now.timeIntervalSince(session.endDate) <= 24 * 60 * 60
            state = endedRecently ? .review(record) : .idle
            await persistState()
            if endedRecently, existing == nil {
                onSessionEnded?(record)
            }
            return
        }

        state = session.kind == .hyperfocus ? .hyperfocus(session) : .scatterfocus(session)
        await persistState()
        startTickerIfNeeded()
        onSessionStarted?(session)
    }

    func noteError(_ message: String) {
        lastError = message
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Private

    private func finishSession(
        status: SessionStatus,
        actualEndDate: Date,
        reason: String?
    ) async {
        guard let session = activeSession else { return }
        let record = makeRecord(
            from: session,
            status: status,
            actualEndDate: actualEndDate,
            reason: reason
        )

        await statsStore.upsert(record)
        state = .review(record)
        now = dateProvider()
        stopTicker()
        await persistState()
        onSessionEnded?(record)
    }

    private func makeRecord(
        from session: ActiveSession,
        status: SessionStatus,
        actualEndDate: Date,
        reason: String?
    ) -> SessionRecord {
        SessionRecord(
            id: session.id,
            kind: session.kind,
            focusObject: session.focusObject,
            intentionID: session.intentionID,
            intentionText: session.intentionText,
            scatterfocusMode: session.scatterfocusMode,
            problemQuestion: session.problemQuestion,
            plannedDuration: session.plannedDuration,
            startDate: session.startDate,
            plannedEndDate: session.endDate,
            actualEndDate: max(actualEndDate, session.startDate),
            status: status,
            earlyEndReason: reason,
            blockingSuspended: session.blockingSuspended,
            blocklistName: session.blocklistName
        )
    }

    private func persistState() async {
        let file = ActiveSessionFile(
            activeSession: state.activeSession,
            pendingReviewID: state.pendingReview?.id
        )
        do {
            try await persistence.save(file, to: "activeSession.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save the active session: \(error.localizedDescription)"
        }
    }

    private func startTickerIfNeeded() {
        guard automaticallyTicks, tickerTask == nil else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    deinit {
        tickerTask?.cancel()
    }
}
