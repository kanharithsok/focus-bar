import Foundation
import Observation

@MainActor
@Observable
final class CaptureStore {
    private(set) var captures: [Capture] = []
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored var onLocalChange: (() -> Void)?
    @ObservationIgnored var onDelete: ((UUID) async -> Void)?

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func load() async {
        if let loaded = await persistence.load([Capture].self, from: "captures.json") {
            captures = loaded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    @discardableResult
    func add(
        text: String,
        sessionID: UUID?,
        source: CaptureSource,
        at date: Date = Date()
    ) async -> Capture? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let capture = Capture(
            text: trimmed,
            createdAt: date,
            sessionID: sessionID,
            source: source
        )
        captures.insert(capture, at: 0)
        await persist()
        return capture
    }

    func captures(for sessionID: UUID) -> [Capture] {
        captures
            .filter { $0.sessionID == sessionID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func captures(for sessionID: UUID, source: CaptureSource) -> [Capture] {
        captures(for: sessionID).filter { $0.source == source }
    }

    var generalCaptures: [Capture] {
        captures.filter { $0.sessionID == nil }
    }

    func delete(_ capture: Capture) async {
        // Record the tombstone before removing the local copy so another Mac
        // can't re-import it later.
        await onDelete?(capture.id)
        captures.removeAll { $0.id == capture.id }
        await persist()
    }

    /// Replaces captures with the merged multi-Mac result without triggering a
    /// new local-change sync.
    func applySynced(_ records: [Capture]) async {
        let sorted = records.sorted { $0.createdAt > $1.createdAt }
        guard sorted != captures else { return }
        captures = sorted
        do {
            try await persistence.save(captures, to: "captures.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save captures: \(error.localizedDescription)"
        }
    }

    func clearError() {
        lastError = nil
    }

    private func persist() async {
        do {
            try await persistence.save(captures, to: "captures.json")
            lastError = nil
            onLocalChange?()
        } catch {
            lastError = "Couldn't save captures: \(error.localizedDescription)"
        }
    }
}
