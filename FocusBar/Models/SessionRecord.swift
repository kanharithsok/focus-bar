import Foundation

/// A finished session in local history.
struct SessionRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: SessionKind
    var focusObject: String
    var intentionID: UUID?
    var intentionText: String?
    var scatterfocusMode: ScatterfocusMode?
    var problemQuestion: String?
    var plannedDuration: TimeInterval
    var startDate: Date
    var plannedEndDate: Date
    var actualEndDate: Date
    var status: SessionStatus
    var rating: Int?
    var note: String?
    var earlyEndReason: String?
    var blockingSuspended: Bool
    var blocklistName: String?

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
        plannedEndDate: Date,
        actualEndDate: Date,
        status: SessionStatus,
        rating: Int? = nil,
        note: String? = nil,
        earlyEndReason: String? = nil,
        blockingSuspended: Bool = false,
        blocklistName: String? = nil
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
        self.plannedEndDate = plannedEndDate
        self.actualEndDate = actualEndDate
        self.status = status
        self.rating = rating
        self.note = note
        self.earlyEndReason = earlyEndReason
        self.blockingSuspended = blockingSuspended
        self.blocklistName = blocklistName
    }

    var actualDuration: TimeInterval {
        max(0, actualEndDate.timeIntervalSince(startDate))
    }

    var isHyperfocus: Bool { kind == .hyperfocus }
}
