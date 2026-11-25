---
name: persistence-and-sync
description: Use when changing FocusBar JSON schemas, PersistenceController, session/capture stores, sync snapshots, merge rules, tombstones, or folder sync.
---

# Persistence and Sync

## Local persistence

- All app data goes through the `PersistenceController` actor. Do not write JSON directly from views/services.
- Files use a versioned envelope `{ schemaVersion, payload }`, atomic writes, and corrupt-file quarantine. Never silently overwrite or delete a corrupt file.
- A newer schema is refused/left untouched, not downgraded or truncated.
- Schema changes require a version bump, a compatibility/migration path, and tests for old/corrupt/newer/missing files.
- Do not persist derived totals, streaks, or summaries; `StatsCalculator` derives them.
- Keep focus objects, captures, intentions, ratings, settings, and hostname-level blocked attempts in their existing stores/files unless a task explicitly changes the model.
- Never store full URLs, paths, queries, page content, or secrets.

## Sync

- Sync is off by default and separate from local writes. A missing/unavailable folder must not block or damage local data.
- Each device writes only `devices/device-<UUID>.json`; never delete or overwrite another device's file.
- Snapshots contain sessions, captures, intentions, skipped days, blocked attempts, shared settings, and deletion tombstones.
- Never sync the active session or device-specific settings (helper toggle, Zen/Firefox restart, start-at-login, notification permission, sync configuration).
- Merge by UUID; sessions use `updatedAt`, captures/intentions/attempts use creation timestamps with a deterministic tie-break; shared settings use a timestamped last-writer-wins snapshot.
- Capture/intention deletions must be tombstoned locally and included in snapshots so deleted records do not reappear.
- Treat remote JSON as untrusted: bound size, decode defensively, skip unreadable/newer-schema files, never follow embedded paths, never execute content.
- Use `NSFileCoordinator` and atomic writes. A newer local schema stops export rather than overwriting.
- No network code; the folder provider handles transfer.

## Tests

- Use real persistence pointed at unique temporary directories; clean up after.
- Cover round trips, two-device convergence, tombstones, shared-settings timestamps, corrupt/newer/oversized files, device-specific exclusions, and folder-unavailable behavior.
- Real iCloud Drive materialization, TCC folder access, and two-Mac propagation are manual checks (`FB-006`). Do not claim them from unit tests.

## Privacy

Snapshots include personal text and blocked hostnames and are not end-to-end encrypted. Keep the README/UI disclosure accurate. Do not log snapshot contents or folder paths.
