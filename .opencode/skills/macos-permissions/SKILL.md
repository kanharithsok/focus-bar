---
name: macos-permissions
description: Use when changing TCC permissions, Automation, notifications, folder access, Login Items, SMAppService registration, code signing, or entitlements.
---

# macOS Permissions

FocusBar must request the minimum capability at the point of use and remain honest when it is unavailable.

## Permission map

| Capability | When | If unavailable |
| --- | --- | --- |
| Automation / Apple Events | Browser guard needs the active tab | Show denied/timeout; leave tab open; never claim active protection |
| Notifications | First session with notifications enabled | Continue without notifications; show honest state |
| Folder access | User chooses a sync folder | Keep local data; show error; do not block local use |
| Login Items (`SMAppService.mainApp`) | User enables Start at login | Report failure; do not silently flip the toggle |
| Privileged helper (`SMAppService` daemon) | User enables system-wide blocking | Show registration/approval state; do not claim blocking active |

## Rules

- No permission request at launch unless the feature is actively used.
- Never add Accessibility, Screen Recording, Full Disk Access, or a Network Extension without an explicit owner decision and a new task.
- Handle denial, revocation, timeout, browser-not-running, and helper-unavailable states distinctly. Do not crash or silently retry forever.
- Do not weaken the helper's code-signing requirement to accommodate ad-hoc builds. The UI should detect ad-hoc signing and explain the setup instead.
- The helper requires a stable Apple Development/Developer ID signature and an app in `/Applications` for real registration. `CODE_SIGNING_ALLOWED=NO` is fine for the unit suite but cannot produce a usable daemon.
- `SMAppService` registration may report an error while still recording the daemon; query the authoritative status rather than assuming the thrown error is final.
- Start at login and the privileged helper are separate. Do not conflate their state.
- Folder access uses the standard picker. Do not attempt to bypass TCC or persist access in an unsupported way.
- Code signing/TCC attribution can change when the signature changes; ad-hoc rebuilds may re-prompt. Record this as a known limitation.
- Never log signing identities, team IDs, or user folder paths.

## Verification

- Unit/logic tests cannot prove TCC behavior. Record a signed-build manual check with date, macOS version, and observed prompt/denial.
- Helper registration/approval, root XPC, and `/etc/hosts` changes are manual checks (`FB-005`).
- If a permission cannot be exercised, record `BLOCKED`/`NOT RUN` with the reason. Do not claim it passed.
