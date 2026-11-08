import Foundation

/// The in-flight session. `endDate` is the absolute source of truth for timing.
struct ActiveSession: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: SessionKind
    var focusObject: String
    var intentionID: UUID?
    var intentionText: String?
    var scatterfocusMode: ScatterfocusMode?
    var problemQuestion: String?
    var plannedDuration: TimeInterval
    var startDate: Date
    var endDate: Date
    var blocklistPresetID: UUID?
    var blocklistName: String?
    var blockingSuspended: Bool

    init(
        id: UUID = UUID(),
        kind: SessionKind,
        focusObject: String,
        intentionID: UUID? = nil,
        intentionText: String? = nil,
        scatterfocusMode: ScatterfocusMode? = nil,
        problemQuestion: String? = nil,
        plannedDuration: TimeInterval,
        startDate: Date,
        endDate: Date,
        blocklistPresetID: UUID? = nil,
        blocklistName: String? = nil,
        blockingSuspended: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.focusObject = focusObject
        self.intentionID = intentionID
        self.intentionText = intentionText
        self.scatterfocusMode = scatterfocusMode
        self.problemQuestion = problemQuestion
        self.plannedDuration = plannedDuration
        self.startDate = startDate
        self.endDate = endDate
        self.blocklistPresetID = blocklistPresetID
        self.blocklistName = blocklistName
        self.blockingSuspended = blockingSuspended
    }
}

struct ActiveSessionFile: Codable, Equatable, Sendable {
    var activeSession: ActiveSession?
    var pendingReviewID: UUID?
}
