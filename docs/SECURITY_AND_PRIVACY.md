# FocusBar — Security and Privacy

This document defines the security/privacy expectations for changes. `docs/THREAT_MODEL.md` covers adversaries and mitigations; `AGENTS.md` is binding.

## Principles

- **Local-first by default.** No FocusBar servers, accounts, analytics, telemetry, crash upload, or app-initiated network calls.
- **Least privilege.** Request TCC permissions at the point of use, only for the feature that needs them. Do not add Accessibility, Screen Recording, or Full Disk Access.
- **Fail open for blocking, fail honest in the UI.** A missing permission, crashed app, unavailable helper, or unreadable sync folder must not leave a permanent system block or break local use. Never report protection as active when it is not.
- **User-initiated privileged work.** The helper is registered only from an explicit Settings action.
- **Minimum data.** Store hostname-level blocked attempts; never full URLs, paths, queries, page content, or browser history.
- **No secrets in the repository or logs.**

## Permission matrix

| Capability | When requested | Failure behavior |
| --- | --- | --- |
| Automation / Apple Events | Only when browser protection inspects Safari/Chrome | Show denied/timeout status; leave tabs open; never crash or claim active protection |
| Notifications | First session start when notifications are enabled | Continue without notifications; show honest state |
| Folder access | When the user chooses a sync folder | Keep local data; show an error; do not block local use |
| Login Items (`SMAppService.mainApp`) | When the user enables Start at login | Report failure; do not change the setting silently |
| Privileged helper (`SMAppService` daemon) | When the user enables system-wide blocking | Show registration/approval state; do not claim blocking is active |
| Network | Never (no app-initiated network code) | Not applicable |

## Data inventory

| Data | Location | Notes |
| --- | --- | --- |
| Settings | `~/Library/Application Support/FocusBar/settings.json` | Blocklists, presets, toggles, shortcut |
| Session history/reviews | `sessions.json` | Focus objects, notes, ratings |
| Active session | `activeSession.json` | Never synced |
| Captures | `captures.json` | Distraction notes; tombstones for deletion in `syncState.json` |
| Intentions | `intentions.json` | Daily intentions and skipped days |
| Blocked attempts | `blockedAttempts.json` | Bundle IDs or normalized hostnames, browser/session/time/detail only |
| Sync bookkeeping | `syncState.json` | Device ID, last sync, tombstones |
| Sync snapshots | User-selected folder `devices/device-<UUID>.json` | Opt-in; plain JSON; no active session or device-specific settings |
| Logs | Apple unified logging | Local diagnostics; privacy annotations; no telemetry |

All app JSON uses a versioned envelope, atomic writes, and corrupt-file quarantine. Newer schemas are not overwritten.

## Logging

- Use `Logger(subsystem: "com.kanharithsok.FocusBar", category: ...)`.
- Mark user content as private; do not interpolate focus objects, capture text, intention text, full URLs, folder paths, tokens, signing identities, or team IDs into public log messages.
- Errors should identify the operation and failure class, not the content.
- No `print` in app paths. The helper's CLI self-test may print status only.
- Diagnostics must stay on-device. Do not add third-party logging, crash reporting, or analytics.

## Privileged helper

- Keep the XPC surface minimal and typed. No arbitrary paths, file contents, shell commands, or unvalidated hostnames.
- Validate callers with the code-signing requirement. Never relax this for ad-hoc builds.
- Only touch the marked `# >>> FocusBar managed block >>>` section; preserve unrelated content and file permissions; write atomically; refuse malformed markers.
- Lease semantics are fail-open; cleanup covers session end, expiry, reinstall, reboot, and stale launch.
- Any helper change is security-sensitive and needs unit tests plus a signed manual check.

## Optional sync

- Off by default; only the user-selected folder is written.
- One snapshot per device; never delete or overwrite another device's file.
- Treat remote JSON as untrusted: bound size, decode defensively, skip unreadable/newer files, never follow embedded paths.
- Snapshots include personal text and blocked hostnames; they are not end-to-end encrypted. The UI/README must say so.
- Sync must never block local writes or leave local data damaged when the folder is missing.

## Dependencies and supply chain

- Only `KeyboardShortcuts` is approved as a runtime dependency. XcodeGen is a development tool.
- No new dependency without explicit owner approval and a `docs/DEPENDENCIES.md` update.
- Do not add analytics, networking, crash-reporting, UI-kit, or privileged-helper libraries.
- Preserve `Package.resolved`; review license/provenance and macOS 14 compatibility.

## Release security

- The helper requires a stable Apple Development/Developer ID signature and an app in `/Applications` for real registration. Ad-hoc builds are test-only for the unit suite.
- Do not disable hardened runtime or code-signing checks to make a local build pass.
- Do not claim notarization, App Store review, or guaranteed enforcement when it has not happened.
- Security findings require severity, evidence, and a disposition. Do not suppress a finding merely to get green tests.

## Reporting and handling

Report suspected vulnerabilities privately to the repository owner. Do not open a public issue containing exploit details or personal data. Do not access production/user data, rotate credentials, or change signing settings during an audit without explicit authorization.
