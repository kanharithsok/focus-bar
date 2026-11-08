import Foundation

enum CaptureSource: String, Codable, Sendable {
    case distraction
    case scatterfocus
    case problemCrunching
}

struct Capture: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var text: String
    var createdAt: Date
    var sessionID: UUID?
    var source: CaptureSource

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date,
        sessionID: UUID?,
        source: CaptureSource
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.sessionID = sessionID
        self.source = source
    }
}

struct DailyIntention: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var text: String
    var day: Date
    var createdAt: Date

    init(id: UUID = UUID(), text: String, day: Date, createdAt: Date) {
        self.id = id
        self.text = text
        self.day = day
        self.createdAt = createdAt
    }
}

enum IntentionError: LocalizedError, Equatable {
    case emptyText
    case limitReached

    var errorDescription: String? {
        switch self {
        case .emptyText: return "Write a short intention first."
        case .limitReached: return "You can set up to three intentions per day."
        }
    }
}

struct IntentionFile: Codable, Equatable, Sendable {
    var intentions: [DailyIntention]
    var skippedDays: [Date]
}
