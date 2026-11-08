# FocusBar — Plan

## 1. Repository findings (2026-11-09)

- Repository: `kanharithsok/focus-bar`, branch `main`, clean working tree.
- Initial commit `fe21f38` contained only a three-line `README.md`.
- **No Xcode project, sources, tests, schemes, `AGENTS.md`, or `CLAUDE.md` existed**, despite the brief expecting an existing project.
- Toolchain available:
  - macOS 27.2 (arm64)
  - Xcode 27.2 (build 27B52)
  - Swift 6.4.2
  - XcodeGen 2.46.0 (`/opt/homebrew/bin/xcodegen`)
  - GitHub CLI authenticated as `kanharithsok`
- No third-party runtime dependencies existed.

### Decision: create the missing Xcode project with XcodeGen

The brief forbids manually editing `project.pbxproj` and regenerating an existing project. Since no project existed, the only viable path was to create one. `project.yml` is the source of truth and `FocusBar.xcodeproj` is generated with XcodeGen. XcodeGen is a local development tool, not a shipped dependency. The generated project is committed so contributors without XcodeGen can open it, but project-file changes must go through `project.yml` + `xcodegen generate`, never hand-edited `project.pbxproj`.

Target: `FocusBar` (macOS app, deployment target 14.0), test target `FocusBarTests`.

## 2. Architecture

```
SwiftUI Views
    ↓ @Environment / @Bindable
AppModel (composition root) + @Observable stores & managers
    ↓
Services: SessionManager, BlockingEngine, CaptureStore, StatsStore,
          IntentionStore, SettingsStore, BlockedAttemptStore
    ↓
PersistenceController (actor, versioned JSON, atomic writes)
```

- `SessionManager`: explicit state machine (`idle`, `hyperfocus`, `scatterfocus`, `review`), absolute end dates, timer recalculation after wake/relaunch, early-end and review flow.
- `BlockingEngine`: owns `AppBlocker` and `BrowserBlocker`; both conform to the `Blocker` protocol; reports best-effort status honestly.
- `StatsStore`: owns session history and derives all statistics on demand. No duplicated totals.
- `CaptureStore` / `IntentionStore` / `BlockedAttemptStore`: JSON-backed `@Observable` stores.
- `PersistenceController`: actor; `~/Library/Application Support/FocusBar/`; versioned envelope; `Data.write(options: .atomic)`; corrupt files quarantined, never silently overwritten.
- Views contain no persistence or business logic.
- Tests use real `PersistenceController` instances pointed at temporary directories plus an injectable clock; no UI launch required.

### Persistence files

| File | Payload |
| --- | --- |
| `settings.json` | `AppSettings` (commit mode, blocklists/presets, blocking switches, notifications) |
| `sessions.json` | `[SessionRecord]` history |
| `activeSession.json` | active session and pending-review ID |
| `captures.json` | `[Capture]` distractions and Scatterfocus notes |
| `intentions.json` | daily intentions and skipped days |
| `blockedAttempts.json` | `[BlockedAttempt]` best-effort blocking history |

All files use `{ "schemaVersion": 1, "payload": ... }`. Statistics are always computed from `sessions.json` + `blockedAttempts.json`.

## 3. Milestones and status

### M1 — Menu-bar foundation and session engine

Status: **implemented, verified by build + unit tests**

- Menu-bar-only `MenuBarExtra(.window)` app, `LSUIElement`.
- Idle/Hyperfocus states; 25/50/90/custom duration; focus object.
- Absolute-end-date countdown; menu-bar remaining time; progress.
- Explicit state machine with invalid-transition rejection.
- Session persistence, relaunch restore, expired-session finalization.
- Tests for transitions, timers, expiration, restore, persistence.

Acceptance:
- [x] App builds as menu-bar-only target (`LSUIElement`).
- [x] 25/50/90/custom sessions.
- [x] Focus object visible during session.
- [x] Remaining time recomputed from end date.
- [x] State correct after simulated sleep/relaunch.
- [x] Invalid transitions rejected.
- [x] Session logic covered by tests.

### M2 — Session experience, intentions, history

Status: **implemented, verified by build + unit tests**

- 20-second early-end countdown + required reason.
- Commit Mode hides normal early end; emergency stop remains available and is labelled honestly.
- Completion review: 1–5 focus rating, optional note, captured-distraction review.
- Daily intentions (max 3, optional, skip for today), optional session link.
- Session history with notes, intentions, status, rating.

Acceptance:
- [x] Complete + rate a session.
- [x] Early-end confirmation flow enforced in logic and UI.
- [x] Intentions can be skipped; session start never blocked.
- [x] Session/intention/capture data survives relaunch.

### M3 — Scatterfocus and quick capture

Status: **implemented, verified by build + unit tests; live shortcut panel needs manual check**

- Scatterfocus state, 10-minute default, Capture / Problem crunching / Habitual modes.
- Habitual mode intentionally has no scratchpad.
- Blocking-during-break setting and explicit per-break suspension.
- Global `⌃⌥Space` capture panel via approved `KeyboardShortcuts` dependency.
- Captures associated with the active session; general captures otherwise.
- Post-session capture review.

Acceptance:
- [x] Start/finish Scatterfocus.
- [x] Correct mode UI (Habitual has no pad).
- [x] Global shortcut registered through `KeyboardShortcuts`.
- [x] Captures persisted and session-associated.
- [ ] Manual: verify panel focus/feel in a live menu-bar session.

### M4 — Best-effort app and browser blocking

Status: **implemented; unit-tested where headless testing is possible; live macOS permission/browser verification pending**

- `Blocker` protocol + `BlockingEngine`; independent app and browser blockers.
- Editable presets, service catalog (YouTube off by default), app picker resolving bundle IDs.
- `NSWorkspace` launch/activation observation; hide by default, optional normal terminate request; cooldown/dedup.
- Safari + Chrome active-tab AppleScript checks off the main thread with timeouts; immediate check on activation + ~1 s polling only while supported browser is foreground.
- Bundled generic blocked page; no URL paths/queries stored; hostname-only attempt records.
- Permission explanation, denied/timeout handling, redirect-failure notification, duplicate-attempt suppression.
- Other browsers intentionally not added yet.

Acceptance:
- [x] Selected apps detected during sessions (logic).
- [x] Non-destructive action + honest reporting.
- [x] Safari/Chrome scripts implemented.
- [x] Permission denial handled without crash.
- [x] No tab closing on redirect failure.
- [x] Polling dedup logic tested.
- [ ] Manual: grant Automation permission and verify Safari/Chrome redirects.
- [ ] Manual: verify app hiding/termination requests with real apps.

### M5 — Statistics and polish

Status: **implemented, verified by build + unit tests**

- Daily/weekly focus minutes, average rating, blocked-attempt counts.
- History refinements, empty states, error banners, accessibility labels.
- README, CLAUDE.md, PLAN.md.
- No streaks, gamification, or guilt messaging.

Acceptance:
- [x] Statistics derived from saved records.
- [x] Data correct after relaunch (persistence tests).
- [x] No streak/guilt features.
- [x] M1–M5 integrated; build + tests pass.

### M6 — Future system-wide blocking

Status: **not started, explicitly out of v1 scope**

Design notes:
- Requires explicit user approval before any helper/daemon registration or `/etc/hosts` writes.
- Preferred shape: `SMAppService` privileged helper + XPC, fail-open lease, heartbeat expiry, stale-rule recovery on boot, marked FocusBar entries only.
- `/etc/hosts` cannot express wildcards; maintain explicit hostname/subdomain list; flush DNS.
- Hosts blocking is bypassable by VPN/encrypted DNS.
- Do not implement or install anything until authorized.

## 4. Key decisions and assumptions

- **No Xcode project existed.** Generated one with XcodeGen; `project.yml` is authoritative.
- **XcodeGen is a dev tool**, not a shipped dependency. The only app dependency is `KeyboardShortcuts` (1.10.0), as approved.
- **Deployment target 14.0**, Swift 5 language mode for predictable concurrency behavior with AppKit observers; app is Apple Silicon friendly (universal-capable, built arm64 here).
- **No sandbox** for v1: Apple Events to Safari/Chrome and app-bundle inspection require it; app is distributed locally, not via App Store. No network entitlement/use.
- **Absolute `endDate`** is the source of truth. `now` is refreshed on a 1 s tick, on wake, and on relaunch. Sleep does not extend sessions.
- **Completed sessions** ending while the app was closed are finalized at their planned end time. Reviews are offered for sessions that ended within 24 h; older ones are saved without a review prompt.
- **Early-end rules apply to Hyperfocus.** Scatterfocus breaks can be ended immediately (low-stakes breaks), recorded as `endedEarly` without a reason.
- **Statistics attribution:** focus minutes are attributed to the session start day; only Hyperfocus contributes focus minutes. Early-ended sessions contribute actual elapsed time.
- **Blocking is best-effort.** No guarantee, no force-kill, no hosts-file or privileged helper.
- **Browser support is Safari + Chrome only** until other browsers are individually tested.
- **YouTube is present but disabled** in the default social-media preset.
- **No notifications request at launch**; permission is requested when the first session starts if notifications are enabled.
- **App is local-first**: no network code, no analytics, no accounts.

## 5. Technical risks and limitations

- Apple Events/Automation permission is user- and signature-dependent; ad-hoc development builds may prompt again after rebuilds.
- `NSRunningApplication.terminate()` is a request only; apps can refuse. FocusBar never force-terminates.
- Browser guard inspects only the active tab and can miss fast navigations between ~1 s polls.
- `osascript` subprocess is used for Apple Events to keep execution off the main thread and enforce timeouts; TCC attribution should be verified manually on a signed build.
- Menu-bar-only apps have limited affordances for modal emergency UI; emergency stop uses an `NSAlert` and the Session menu.
- App-blocking observers are in-process: if FocusBar is force-quit, blocking stops. This is stated in the UI/docs.
- Corrupt JSON is quarantined with a `.corrupt-<timestamp>` suffix; data is preserved for recovery but not automatically merged.

## 6. Verification commands

```sh
xcodegen generate
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## 7. Current state / next actions

- v1 feature set implemented (M1–M5).
- Automated build and unit tests pass in this environment (results recorded in the milestone report).
- Remaining work is manual, permission-dependent verification:
  1. Launch the app, verify menu-bar-only behavior and popover.
  2. Grant Automation access and test Safari/Chrome active-tab redirect.
  3. Test app hide / terminate-request behavior with a selected app.
  4. Verify the global capture shortcut and panel feel.
- M6 requires explicit approval and is not started.
