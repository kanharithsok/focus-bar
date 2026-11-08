import Foundation

enum SessionPhase: Equatable, Sendable {
    case idle
    case hyperfocus
    case scatterfocus
    case review
}

enum SessionState: Equatable, Sendable {
    case idle
    case hyperfocus(ActiveSession)
    case scatterfocus(ActiveSession)
    case review(SessionRecord)

    var activeSession: ActiveSession? {
        switch self {
        case .hyperfocus(let session), .scatterfocus(let session): return session
        case .idle, .review: return nil
        }
    }

    var pendingReview: SessionRecord? {
        if case .review(let record) = self { return record }
        return nil
    }

    var phase: SessionPhase {
        switch self {
        case .idle: return .idle
        case .hyperfocus: return .hyperfocus
        case .scatterfocus: return .scatterfocus
        case .review: return .review
        }
    }
}

enum SessionTimer {
    /// Remaining time is always recomputed from the absolute end date.
    static func remaining(endDate: Date, now: Date) -> TimeInterval {
        max(0, endDate.timeIntervalSince(now))
    }

    static func progress(startDate: Date, endDate: Date, now: Date) -> Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(startDate)
        return min(1, max(0, elapsed / total))
    }

    /// `mm:ss`, rounded up so a fresh 25-minute session shows 25:00.
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.up)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func roundedMinutes(_ interval: TimeInterval) -> Int {
        max(0, Int((interval / 60).rounded()))
    }
}

enum SessionError: LocalizedError, Equatable {
    case invalidState
    case emptyFocusObject
    case invalidDuration
    case reasonRequired
    case commitModeActive
    case noActiveSession
    case invalidRating

    var errorDescription: String? {
        switch self {
        case .invalidState:
            return "That action isn't available right now."
        case .emptyFocusObject:
            return "Name one specific thing to focus on."
        case .invalidDuration:
            return "Choose a duration between 1 and 480 minutes."
        case .reasonRequired:
            return "Add a one-line reason before ending the session."
        case .commitModeActive:
            return "Commit mode is on. Use the emergency stop if you must end now."
        case .noActiveSession:
            return "There is no active session."
        case .invalidRating:
            return "Focus quality must be between 1 and 5."
        }
    }
}
