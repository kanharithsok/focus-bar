---
name: privacy-data-lifecycle
description: Use when reviewing data collection, storage, logging, sync disclosure, deletion, retention, or diagnostics in FocusBar.
---

# Privacy and Data Lifecycle

FocusBar is local-first and has no accounts, analytics, telemetry, or app-initiated network calls. Privacy is a product feature, not a compliance afterthought.

## Data map

- Local: `settings.json`, `sessions.json`, `activeSession.json`, `captures.json`, `intentions.json`, `blockedAttempts.json`, `syncState.json` in `~/Library/Application Support/FocusBar/`.
- Optional sync: `devices/device-<UUID>.json` in the user-selected folder. Includes session/capture/intention text, blocked hostnames, shared settings, and tombstones. Not end-to-end encrypted.
- Logs: Apple unified logging, local only; no third-party crash/analytics upload.
- Clipboard/screenshots: do not capture personal content into README/test artifacts.

## Rules

- Collect the minimum: hostname-level blocked attempts, not full URLs/paths/queries/page content.
- Do not add telemetry, analytics, remote logging, crash upload, or hidden network calls.
- Sync stays off until the user enables it and writes only to the chosen folder. No automatic cloud upload.
- Disclose that sync snapshots contain personal text and are protected only by the folder provider. Do not claim E2E encryption.
- Do not log focus/capture/intention text, full URLs, folder paths, tokens, or signing identities. Use privacy annotations.
- Corrupt files are quarantined, not silently discarded. Newer schemas are left untouched.
- There is no automatic retention purge in v1; local data persists until the user deletes it. Do not describe an automatic deletion guarantee.
- Uninstalling the app leaves local Application Support data and the optional sync folder; document this. The helper registration must be removed separately.
- Deleting a capture/intention uses a tombstone so it does not return from an older snapshot. Do not break this when changing sync.
- Test data must be synthetic. Never use a real user's session/capture content or sync folder in tests/screenshots.
- If a privacy behavior changes, update `README.md` Privacy, `docs/PRODUCT.md`, and `docs/SECURITY_AND_PRIVACY.md`.

## Review questions

- What new data is created, where does it live, and who can read it?
- Is it necessary for the feature, and is it minimized?
- Does it enter logs, snapshots, URLs, notifications, or screenshots?
- Can the user delete it? What happens on uninstall?
- Does the change create a hidden network or third-party data flow?
- Is the UI/README honest about the limitation?
