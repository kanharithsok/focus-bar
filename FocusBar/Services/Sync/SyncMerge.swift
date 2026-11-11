import Foundation

/// Pure merge rules shared by every Mac. The same inputs always produce the
/// same output, so devices converge without a server.
enum SyncMerge {
    static func merge(local: SyncSnapshot, remotes: [SyncSnapshot]) -> SyncSnapshot {
        let snapshots = [local] + remotes

        // Tombstones win over records from any snapshot.
        var deletions: [String: Date] = [:]
        for snapshot in snapshots {
            for (key, date) in snapshot.deletions {
                if let existing = deletions[key], existing >= date { continue }
                deletions[key] = date
            }
        }

        var sessions: [UUID: (record: SessionRecord, device: UUID)] = [:]
        var captures: [UUID: (record: Capture, device: UUID)] = [:]
        var intentions: [UUID: (record: DailyIntention, device: UUID)] = [:]
        var attempts: [UUID: (record: BlockedAttempt, device: UUID)] = [:]
        var skippedDays = Set<Date>()
        var sharedSettings: (settings: SharedSettingsSnapshot, device: UUID)?

        for snapshot in snapshots {
            for record in snapshot.sessions {
                if let existing = sessions[record.id],
                   !preferSession(record, device: snapshot.deviceID, over: existing) {
                    continue
                }
                sessions[record.id] = (record, snapshot.deviceID)
            }

            for record in snapshot.captures where deletions[SyncState.key(kind: "capture", id: record.id)] == nil {
                if let existing = captures[record.id],
                   !preferCapture(record, device: snapshot.deviceID, over: existing) {
                    continue
                }
                captures[record.id] = (record, snapshot.deviceID)
            }

            for record in snapshot.intentions where deletions[SyncState.key(kind: "intention", id: record.id)] == nil {
                if let existing = intentions[record.id],
                   !preferIntention(record, device: snapshot.deviceID, over: existing) {
                    continue
                }
                intentions[record.id] = (record, snapshot.deviceID)
            }

            for record in snapshot.blockedAttempts {
                if let existing = attempts[record.id],
                   !preferAttempt(record, device: snapshot.deviceID, over: existing) {
                    continue
                }
                attempts[record.id] = (record, snapshot.deviceID)
            }

            skippedDays.formUnion(snapshot.skippedDays)

            if let candidate = snapshot.sharedSettings {
                if let existing = sharedSettings,
                   !preferSettings(candidate, device: snapshot.deviceID, over: existing) {
                    continue
                }
                sharedSettings = (candidate, snapshot.deviceID)
            }
        }

        let mergedSessions = sessions.values
            .map { $0.record }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate > $1.startDate }
                return $0.id.uuidString < $1.id.uuidString
            }

        let mergedCaptures = captures.values
            .map { $0.record }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }

        let mergedIntentions = intentions.values
            .map { $0.record }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }

        let mergedAttempts = attempts.values
            .map { $0.record }
            .sorted {
                if $0.timestamp != $1.timestamp { return $0.timestamp > $1.timestamp }
                return $0.id.uuidString < $1.id.uuidString
            }
            .prefix(BlockedAttemptStore.maximumCount)

        return SyncSnapshot(
            schemaVersion: SyncSnapshot.schemaVersion,
            deviceID: local.deviceID,
            sessions: mergedSessions,
            captures: mergedCaptures,
            intentions: mergedIntentions,
            skippedDays: skippedDays.sorted(),
            blockedAttempts: Array(mergedAttempts),
            sharedSettings: sharedSettings?.settings,
            deletions: deletions
        )
    }

    private static func preferSession(
        _ candidate: SessionRecord,
        device: UUID,
        over existing: (record: SessionRecord, device: UUID)
    ) -> Bool {
        let candidateDate = candidate.updatedAt ?? candidate.actualEndDate
        let existingDate = existing.record.updatedAt ?? existing.record.actualEndDate
        if candidateDate != existingDate { return candidateDate > existingDate }
        return preferOnTie(candidate, device: device, over: existing.record, existingDevice: existing.device)
    }

    private static func preferCapture(
        _ candidate: Capture,
        device: UUID,
        over existing: (record: Capture, device: UUID)
    ) -> Bool {
        if candidate.createdAt != existing.record.createdAt {
            return candidate.createdAt > existing.record.createdAt
        }
        return preferOnTie(candidate, device: device, over: existing.record, existingDevice: existing.device)
    }

    private static func preferIntention(
        _ candidate: DailyIntention,
        device: UUID,
        over existing: (record: DailyIntention, device: UUID)
    ) -> Bool {
        if candidate.createdAt != existing.record.createdAt {
            return candidate.createdAt > existing.record.createdAt
        }
        return preferOnTie(candidate, device: device, over: existing.record, existingDevice: existing.device)
    }

    private static func preferAttempt(
        _ candidate: BlockedAttempt,
        device: UUID,
        over existing: (record: BlockedAttempt, device: UUID)
    ) -> Bool {
        if candidate.timestamp != existing.record.timestamp {
            return candidate.timestamp > existing.record.timestamp
        }
        return preferOnTie(candidate, device: device, over: existing.record, existingDevice: existing.device)
    }

    private static func preferSettings(
        _ candidate: SharedSettingsSnapshot,
        device: UUID,
        over existing: (settings: SharedSettingsSnapshot, device: UUID)
    ) -> Bool {
        if candidate.updatedAt != existing.settings.updatedAt {
            return candidate.updatedAt > existing.settings.updatedAt
        }
        return preferOnTie(candidate, device: device, over: existing.settings, existingDevice: existing.device)
    }

    /// Timestamps are the primary rule. If two clocks agree exactly, use a
    /// stable device/content comparison so every Mac picks the same winner.
    private static func preferOnTie<T: Encodable>(
        _ candidate: T,
        device: UUID,
        over existing: T,
        existingDevice: UUID
    ) -> Bool {
        if device != existingDevice { return device.uuidString > existingDevice.uuidString }
        return stableKey(candidate) > stableKey(existing)
    }

    private static func stableKey<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(value) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
