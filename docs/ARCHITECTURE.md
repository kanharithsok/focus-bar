# FocusBar — Architecture

`PLAN.md` §2 holds the milestone-era architecture narrative. This document is the day-to-day implementation map and invariant list for agents. `AGENTS.md` holds the binding rules.

## Runtime topology

```
SwiftUI Views
    ↓ @Environment / @Bindable
AppModel (composition root) + @Observable stores and managers
    ↓
Services
    ├─ SessionManager        state machine + absolute endDate timing
    ├─ SettingsStore         AppSettings persistence
    ├─ StatsStore / StatsCalculator
    ├─ CaptureStore / IntentionStore / BlockedAttemptStore
    ├─ BlockingEngine
    │    ├─ AppBlocker       NSWorkspace observations, hide/quit request
    │    └─ BrowserBlocker   Safari/Chrome active-tab guard via AppleScriptRunner
    ├─ SystemBlockingService registration/approval state
    ├─ SystemBlockingClient  XPC + heartbeat + lease status
    ├─ SyncCoordinator       scheduling/orchestration
    │    ├─ FolderSyncEngine snapshots + NSFileCoordinator
    │    └─ SyncMerge        UUID union + timestamps + tombstones
    ├─ LoginItemManager      SMAppService.mainApp
    └─ NotificationService   optional local notifications
    ↓
PersistenceController (actor, versioned JSON, atomic writes)
    ↓
~/Library/Application Support/FocusBar/

Optional: user-selected sync folder
    └─ devices/device-<UUID>.json

Privileged: FocusBarHelper (SMAppService LaunchDaemon)
    └─ marked /etc/hosts section, fail-open lease
```

## Layer rules

- SwiftUI views render state and send intents. They do not read/write files, run AppleScript, or implement session rules.
- `AppModel` is the composition root. Stores/managers are `@Observable`; long-lived services are owned there.
- Services own behavior and persistence. Cross-service coordination belongs in `AppModel` or a coordinator, not in a view.
- `PersistenceController` is the only file-persistence path for app data.
- The helper is a separate target with a minimal XPC surface. It never imports app UI code.
- `FocusBarShared` holds types shared by the app and helper (XPC protocol, hosts rendering/validation, code-signing info). Keep it free of app-only dependencies.

## Session state machine

- States: `idle`, `hyperfocus`, `scatterfocus`, `review` (see `SessionState`/`SessionManager`).
- The source of truth is the absolute `endDate`, never a decrementing in-memory counter.
- `refresh()` recomputes remaining time from the clock on tick, wake, and restore.
- Expired sessions are finalized at their planned end time; a session that ended while the app was closed does not gain time.
- Wake/sleep clock jumps must not extend or shorten a session incorrectly.
- Invalid transitions are rejected explicitly and covered by tests.
- Early-end rules apply to Hyperfocus; Scatterfocus can end immediately without a reason.
- Reviews are offered for sessions that ended within 24 hours; older sessions save without a prompt.
- `automaticallyTicks: false` is used in tests for deterministic timing.

## Persistence

- Files: `settings.json`, `sessions.json`, `activeSession.json`, `captures.json`, `intentions.json`, `blockedAttempts.json`, `syncState.json`.
- Envelope: `{ "schemaVersion": 1, "payload": ... }`.
- Writes are atomic. Corrupt files are quarantined as `filename.corrupt-<timestamp>`; never delete or silently overwrite them.
- Newer schema versions are left untouched and reported.
- Derived totals, streaks, and statistics are never persisted; `StatsCalculator` derives them from records.
- A schema change needs a version bump, a compatibility/migration path, and tests for old, corrupt, and newer files.
- Focus minutes are attributed to the session start day; only Hyperfocus contributes; early-ended sessions contribute actual elapsed time.
- Blocked attempts store only bundle IDs or normalized hostnames plus browser/session/timestamp/detail. Never full URLs, paths, queries, or page content.

## Blocking stack

- `BlockingEngine` coordinates independent `AppBlocker` and `BrowserBlocker` implementations and reports status honestly.
- App blocking uses `NSWorkspace` launch/activation observations. Hide is the default; termination is a normal quit request only. Never force-terminate.
- Browser blocking is Safari + Chrome only, active tab only. Apple Events run through `AppleScriptRunner` off the main thread with timeouts. Polling happens only while a supported browser is foreground; activation triggers an immediate check.
- Redirect failures never close the tab. Permission denial, timeout, and browser-not-running states are surfaced distinctly.
- The bundled `blocked.html` page is generic and local. It must not include user text.
- `SystemBlockingService` owns registration/approval; `SystemBlockingClient` owns XPC, heartbeat, and live status.
- System-wide blocking is opt-in and disabled by default. It is not a Network Extension and does not guarantee enforcement.

## Privileged helper

- Registered through `SMAppService` only after an explicit user action in Settings.
- Must be signed by the same team as the app; the app should live in `/Applications` for registration. Ad-hoc Debug builds cannot use it, and the UI must explain that rather than weakening the helper.
- XPC caller validation uses a code-signing requirement; reject anything that does not match.
- Validate every hostname; reject malformed, empty, overlong, or non-host input. No arbitrary paths, shell commands, or unvalidated values cross the boundary.
- Only remove/append the `# >>> FocusBar managed block >>>` section. Preserve unrelated content and file permissions. Refuse malformed markers rather than overwriting the file.
- Writes are atomic. DNS is flushed after apply/remove.
- Lease is fail-open: 30 seconds, heartbeat every 8 seconds. Cleanup happens on session end, lease expiry, helper reinstall, SIGTERM/unregister, and reboot/stale launch.
- Deleting the app does not auto-unregister the daemon; the user must use **Remove helper** or System Settings. Browser caches may outlive cleanup.

## Sync

- Separate from local persistence and off by default.
- Each device writes only `devices/device-<UUID>.json`; never another device's file.
- Snapshots contain sessions, captures, intentions, skipped days, blocked attempts, shared settings, and deletion tombstones.
- The active session and device-specific settings (helper toggle, Zen/Firefox restart, start-at-login, notification permission, sync configuration) are never synced.
- `SyncMerge` unions records by UUID; sessions use `updatedAt`; captures/intentions/attempts use creation timestamps with a deterministic tie-break. Shared settings use a timestamped last-writer-wins snapshot.
- Capture/intention deletions are tombstoned locally and included in snapshots so deleted records do not reappear from an older remote snapshot.
- File operations use `NSFileCoordinator` and atomic writes. Unreadable or newer-schema remote files are skipped with a warning; a newer-schema local snapshot stops export rather than overwriting.
- A missing/unavailable sync folder must leave local data intact and local use unblocked.
- No network code. The folder provider performs any transfer.

## Threading and failure behavior

- UI state is main-actor bound. Persistence and helper I/O are asynchronous.
- Apple Events and file coordination must not block the main thread.
- Timer ticks are cheap and only active when needed; no busy polling while idle.
- Fail open for blocking: a crash, missing permission, unavailable helper, or unreadable sync folder must not leave a permanent system block or break local use.
- Errors are surfaced with actionable messages; never claim success when a permission, helper, or file operation failed.

## Where to change what

| Change | Primary files |
| --- | --- |
| Session rules/timing | `FocusBar/Services/SessionManager.swift`, models, `SessionManagerTests` |
| Persistence/schema | `PersistenceController.swift`, models, `PersistenceTests` |
| App/browser blocking | `FocusBar/Services/Blocking/*`, `BlockingTests`, `HostnameMatcherTests` |
| System helper/hosts | `FocusBarHelper/*`, `FocusBarShared/HostsBlocking.swift`, `SystemBlocking*`, helper tests |
| Sync | `FocusBar/Services/Sync/*`, `SyncModels.swift`, `SyncTests` |
| Settings/UI | `FocusBar/Views/*`, `AppModel.swift`, `SettingsStore` |
| Project settings | `project.yml`, then `xcodegen generate` |

Never hand-edit `project.pbxproj`. Add files/settings in `project.yml`.
