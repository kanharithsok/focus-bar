import Foundation

enum SessionKind: String, Codable, CaseIterable, Sendable {
    case hyperfocus
    case scatterfocus

    var displayName: String {
        switch self {
        case .hyperfocus: return "Hyperfocus"
        case .scatterfocus: return "Scatterfocus"
        }
    }
}

enum ScatterfocusMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case capture
    case problemCrunching
    case habitual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .capture: return "Capture"
        case .problemCrunching: return "Problem crunching"
        case .habitual: return "Habitual"
        }
    }

    var shortName: String {
        switch self {
        case .capture: return "Capture"
        case .problemCrunching: return "Problem"
        case .habitual: return "Habitual"
        }
    }

    var icon: String {
        switch self {
        case .capture: return "tray.and.arrow.down"
        case .problemCrunching: return "puzzlepiece"
        case .habitual: return "figure.walk"
        }
    }

    var guidance: String {
        switch self {
        case .capture:
            return "Let thoughts land here. No organizing required."
        case .problemCrunching:
            return "Hold one question loosely and jot whatever surfaces."
        case .habitual:
            return "Choose something low-demand and let your mind wander."
        }
    }
}

enum SessionStatus: String, Codable, Sendable {
    case completed
    case endedEarly
    case emergencyStop

    var displayName: String {
        switch self {
        case .completed: return "Completed"
        case .endedEarly: return "Ended early"
        case .emergencyStop: return "Emergency stop"
        }
    }

    var isCompleted: Bool { self == .completed }
}
