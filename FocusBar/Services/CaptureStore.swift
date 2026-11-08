import Foundation
import Observation

@MainActor
@Observable
final class CaptureStore {
    private(set) var captures: [Capture] = []
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController

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
        captures.removeAll { $0.id == capture.id }
        await persist()
    }

    private func persist() async {
        do {
            try await persistence.save(captures, to: "captures.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save captures: \(error.localizedDescription)"
        }
    }
}
