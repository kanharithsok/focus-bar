import Foundation

enum BlockedAttemptKind: String, Codable, Sendable {
    case application
    case website
}

struct BlockedAttempt: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var timestamp: Date
    var sessionID: UUID?
    var kind: BlockedAttemptKind
    /// Bundle identifier for apps, normalized hostname for websites.
    var identifier: String
    var displayName: String
    var browserName: String?
    var actionDetail: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        sessionID: UUID?,
        kind: BlockedAttemptKind,
        identifier: String,
        displayName: String,
        browserName: String? = nil,
        actionDetail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.browserName = browserName
        self.actionDetail = actionDetail
    }
}

/// Suppresses duplicate events from repeated polling/activation notifications.
struct BlockedAttemptDeduplicator {
    private var lastByKey: [String: (value: String, date: Date)] = [:]
    var cooldown: TimeInterval

    init(cooldown: TimeInterval = 30) {
        self.cooldown = cooldown
    }

    mutating func shouldRecord(key: String, value: String, at date: Date) -> Bool {
        if let last = lastByKey[key],
           last.value == value,
           date.timeIntervalSince(last.date) < cooldown {
            return false
        }
        lastByKey[key] = (value, date)
        return true
    }

    mutating func reset(key: String) {
        lastByKey[key] = nil
    }

    mutating func resetAll() {
        lastByKey.removeAll()
    }
}
