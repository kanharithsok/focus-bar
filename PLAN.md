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
- `SystemBlockingService` / `SystemBlockingClient`: register and talk to the embedded `FocusBarHelper` LaunchDaemon over XPC, heartbeat a 30-second fail-open lease, and report system-wide state honestly.
- `FocusBarHelper` (separate privileged target): validates XPC callers by code-signing requirement, expands/validates hostnames, and atomically manages only its marked `/etc/hosts` section.
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

- Configurable early-end delay (default: none) + required reason.
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
- README.md, AGENTS.md (canonical agent instructions), CLAUDE.md compatibility symlink, PLAN.md.
- No streaks, gamification, or guilt messaging.

Acceptance:
- [x] Statistics derived from saved records.
- [x] Data correct after relaunch (persistence tests).
- [x] No streak/guilt features.
- [x] M1–M5 integrated; build + tests pass.

### M6 — System-wide website blocking

Status: **implemented, opt-in; automated tests and local macOS 27.2 helper/hosts verification pass; cross-browser manual check remains**

- Embedded, signed `FocusBarHelper` LaunchDaemon registered on demand with `SMAppService`; the app must be signed by the same team and installed in `/Applications`.
- `SystemBlockingService` owns registration/approval state. `SystemBlockingClient` owns XPC, the heartbeat task, and live session status.
- The helper validates XPC callers with a code-signing requirement, validates every hostname, and only removes/appends its own marked `/etc/hosts` section.
- Fail-open lease: 30 seconds, heartbeat every 8 seconds; cleanup on session end, lease expiry, helper reinstall, helper restart, or reboot. Writes are atomic and preserve the hosts file's permissions.
- Common subdomains are expanded (`www.`, `m.`, `mobile.`, plus service-specific hosts). `/etc/hosts` has no wildcard syntax, so uncommon subdomains can still slip through.
- DNS is flushed after apply/remove. Blocking is bypassable by VPNs, encrypted DNS/DoH, cached DNS, and IP-literal URLs. System-wide attempts are not counted.
- Optional Zen/Firefox restart at session start/end clears browser-internal DNS/connections. FocusBar sends a normal quit request and reopens the browser; it never force-terminates and does not delete browser profile/cache data. A cached offline shell may still need a reload.
- Off by default; the user enables it in Settings. The helper is not registered at launch or without a user action.

Acceptance:
- [x] Helper target builds, signs, embeds at `Contents/MacOS/FocusBarHelper`, and the LaunchDaemon plist is at `Contents/Library/LaunchDaemons/`.
- [x] `SMAppService` registers the daemon; it runs as root and answers XPC.
- [x] Unsigned/wrong-team XPC clients are rejected.
- [x] Marked hosts section is applied/removed; user content and checksum are restored.
- [x] Lease expiry removes the block without a heartbeat.
- [x] Helper reinstall/launch cleanup removes a stale block; unregister/SIGTERM cleanup removes it immediately.
- [x] Live enable/disable mid-session updates the hosts section.
- [x] Unit tests cover hostname validation, expansion, rendering, file-manager round trips, settings, and blocking-plan decisions.
- [x] Manual: Safari, Chrome, Brave, and Zen (Firefox-based) blocked new navigations during a real session; Firefox/Arc were not installed on this machine.
- [x] Manual: session-end cleanup removed the hosts block; Safari loaded YouTube and normal DNS returned after the session.
- [x] Manual: opt-in Zen restart worked at session start/restore and session end. After the start restart, a normal Zen tab showed the cached YouTube shell as offline with no content; after the end restart, a normal Zen tab loaded the full YouTube homepage without a hard reload.
- [ ] Manual: force-quit lease cleanup and reboot cleanup on a real desktop session.

## 4. Key decisions and assumptions

- **No Xcode project existed.** Generated one with XcodeGen; `project.yml` is authoritative.
- **XcodeGen is a dev tool**, not a shipped dependency. The only app dependency is `KeyboardShortcuts` (1.17.0), as approved.
- **Deployment target 14.0**, Swift 5 language mode for predictable concurrency behavior with AppKit observers; app is Apple Silicon friendly (universal-capable, built arm64 here).
- **No sandbox** for v1: Apple Events to Safari/Chrome and app-bundle inspection require it; app is distributed locally, not via App Store. No network entitlement/use.
- **Absolute `endDate`** is the source of truth. `now` is refreshed on a 1 s tick, on wake, and on relaunch. Sleep does not extend sessions.
- **Completed sessions** ending while the app was closed are finalized at their planned end time. Reviews are offered for sessions that ended within 24 h; older ones are saved without a review prompt.
- **Early-end rules apply to Hyperfocus.** Scatterfocus breaks can be ended immediately (low-stakes breaks), recorded as `endedEarly` without a reason.
- **Statistics attribution:** focus minutes are attributed to the session start day; only Hyperfocus contributes focus minutes. Early-ended sessions contribute actual elapsed time.
- **Blocking is best-effort.** No guarantee, no force-kill. M6 adds opt-in system-wide hosts blocking through a signed privileged helper; it is not a Network Extension and can be bypassed.
- **M6 helper registration is user-initiated.** Enabling system-wide blocking in Settings is the consent point. The app does not register the daemon at launch.
- **M6 hosts management is marker-scoped.** The helper removes/appends only its own section, refuses malformed existing markers instead of overwriting, writes atomically, preserves the existing mode, and flushes DNS.
- **M6 leases are fail-open.** A 30-second lease with an 8-second heartbeat means a crashed/force-quit app cannot leave a permanent block. The helper also clears stale sections on launch/reboot.
- **M6 requires a signed app in `/Applications`.** Ad-hoc builds are fine for tests but cannot register a usable daemon. The helper's XPC listener validates callers by code-signing requirement.
- **M6 hosts has no wildcards.** Presets are expanded to common exact hostnames; uncommon subdomains remain out of scope. VPN/encrypted DNS/cached DNS/IP-literal limitations are surfaced in the UI and README.
- **Browser support is Safari + Chrome only** until other browsers are individually tested.
- **YouTube is present but disabled** in the default social-media preset.
- **No notifications request at launch**; permission is requested when the first session starts if notifications are enabled.
- **App is local-first**: no network code, no analytics, no accounts.
- **Start at login** uses `SMAppService.mainApp` and is user-toggleable in Settings. It is separate from the M6 system-blocking daemon.

## 5. Technical risks and limitations

- Apple Events/Automation permission is user- and signature-dependent; ad-hoc development builds may prompt again after rebuilds.
- `NSRunningApplication.terminate()` is a request only; apps can refuse. FocusBar never force-terminates.
- Browser guard inspects only the active tab and can miss fast navigations between ~1 s polls.
- `osascript` subprocess is used for Apple Events to keep execution off the main thread and enforce timeouts; TCC attribution should be verified manually on a signed build.
- Menu-bar-only apps have limited affordances for modal emergency UI; emergency stop uses an `NSAlert` and the Session menu.
- App-blocking observers are in-process: if FocusBar is force-quit, app hiding and the browser guard stop. The system-wide hosts block is removed after its 30-second lease expires. This is stated in the UI/docs.
- Corrupt JSON is quarantined with a `.corrupt-<timestamp>` suffix; data is preserved for recovery but not automatically merged.
- M6 requires a properly signed app in `/Applications`; ad-hoc and unsigned Debug builds cannot register the daemon and are rejected by its XPC code-signing check. The UI detects ad-hoc signing and explains the setup instead of showing a generic XPC error. Registration can throw `EPERM` on current macOS even when the daemon was recorded successfully, so status is authoritative rather than the thrown error.
- Deleting FocusBar while a session is active does not leave a permanent hosts block: the helper's lease expires after 30 seconds. Deleting the app does not automatically unregister the LaunchDaemon; before deletion, use **Remove helper**, or remove the stale background item in System Settings afterward. Browser-cached offline/error pages can outlive the helper cleanup until the browser is reloaded or restarted.
- M6 is a root daemon. Its XPC surface must stay minimal, validate callers by code-signing requirement, and only touch the marked hosts section. A bug here can break name resolution, so writes are atomic and fail-open.
- `/etc/hosts` cannot express wildcards and is bypassable by VPN/encrypted DNS/cached DNS/IP literals. It cannot count blocked attempts or serve a custom HTTPS page for other browsers.

## 6. Verification commands

```sh
xcodegen generate
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO

# Signed build required to exercise M6's helper. Use your own team ID and
# install the resulting app in /Applications.
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Release \
  -destination 'platform=macOS' build \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

## 7. Verification log

| Date | Check | Result |
| --- | --- | --- |
| 2026-11-09 | `xcodebuild ... build` (Debug, macOS) | **BUILD SUCCEEDED** |
| 2026-11-09 | `xcodebuild ... test` (macOS) | **83 tests, 0 failures** |
| 2026-11-09 | Built `Info.plist` | `LSUIElement = true`, `NSAppleEventsUsageDescription` present |
| 2026-11-09 | Built resources | `blocked.html` present in app bundle |
| 2026-11-09 | `AppleScriptRunner` tests | success, timeout, permission (-1743), execution error all mapped correctly |
| 2026-11-09 | Session/persistence/statistics tests | state transitions, relaunch restore, expiry, review, intentions, captures, hostname matching, dedup, stats all pass |
| 2026-11-09 | Launch smoke test | process launched, LaunchServices type `UIElement`, default `settings.json` written at launch |
| 2026-11-09 | Signed Release build + helper layout | **BUILD SUCCEEDED**; helper at `Contents/MacOS/FocusBarHelper`, plist at `Contents/Library/LaunchDaemons/`; deep code-sign verification passes with matching team |
| 2026-11-09 | `SMAppService` registration | daemon enabled/allowed in `sfltool dumpbtm`; running as root; XPC replies |
| 2026-11-09 | Hosts apply/remove | marked section added; `example.com` resolved to loopback and HTTPS failed; `end` restored the exact original checksum |
| 2026-11-09 | Lease expiry | block removed after 30 s without heartbeat |
| 2026-11-09 | Helper reinstall cleanup | stale marked section removed on helper relaunch |
| 2026-11-09 | Unregister/SIGTERM cleanup | active marked section removed immediately when the daemon was unregistered |
| 2026-11-09 | Session integration | active session reported 45 expanded hostnames; mid-session disable removed the block, re-enable restored it, session end removed it |
| 2026-11-09 | XPC caller validation | unsigned/teamless client rejected by the helper |
| 2026-11-09 | Safari real-browser test | `example.com` loaded as control; `youtube.com`, `www.youtube.com`, and `x.com` redirected to the bundled blocked page during a session; `youtube.com` loaded normally after session end |
| 2026-11-09 | Chrome real-browser test | `example.com` loaded as control; `youtube.com` redirected to the blocked page; headless Chrome returned `ERR_CONNECTION_REFUSED` for `youtube.com`, `www.youtube.com`, and `youtu.be` |
| 2026-11-09 | Brave real-browser test | `example.com` loaded as control; `youtube.com` showed `ERR_CONNECTION_REFUSED` during the session |
| 2026-11-09 | Zen real-browser test | During an active 57-hostname block, a new normal-window tab loaded the full YouTube homepage from Zen’s cached DNS/connection pool; a fresh private window showed “Unable to connect — Zen can’t connect to the server at www.youtube.com.” Confirms browser cache/connection reuse, not a hosts bypass |
| 2026-11-09 | Session-end cleanup | 57-hostname block removed automatically at the planned session end; DNS returned to public addresses and `curl https://youtube.com` returned HTTP 301 |
| 2026-11-09 | Zen restart setting | After app restore with an active session, Zen’s PID changed (quit/reopen) and a normal tab showed the cached YouTube shell as offline; at session end Zen restarted again and a normal tab loaded the full YouTube homepage without a hard reload |

Automated coverage includes:
- session transitions, validation, expiration, sleep/relaunch-style clock jumps;
- early-end reason/commit-mode/emergency rules;
- review persistence and intention/capture association;
- versioned persistence, atomic replacement, corrupt-file quarantine, newer-schema rejection;
- hostname normalization/subdomain matching and unrelated-domain rejection;
- hostname validation, common-subdomain expansion, hosts marker rendering/removal, malformed-block rejection, file-manager round trips, and permission preservation;
- system-wide settings decoding and blocking-plan decisions;
- blocked-attempt dedup and statistics derivation;
- AppleScript timeout/permission mapping.

## 8. Current state / next actions

- v1 feature set implemented (M1–M6); M6 is opt-in from Settings.
- Automated build and unit tests pass in this environment; helper registration, hosts apply/remove, lease expiry, reinstall cleanup, and live session toggling were verified locally on macOS 27.2. See the verification log above.
- Remaining work is manual, permission-dependent verification:
  1. Launch the app, verify menu-bar-only behavior and popover layout.
  2. Grant Automation access and test Safari/Chrome active-tab redirect.
  3. Test app hide / terminate-request behavior with a selected app.
  4. Verify the global capture shortcut and panel feel.
  5. Confirm notification permission behavior.
  6. Register FocusBar as a login item and verify it launches after logging out and back in.
  7. Enable system-wide blocking and verify blocked domains in Safari, Chrome, and Brave (verified locally); verify Firefox/Arc if installed; force-quit FocusBar and confirm lease cleanup; reboot and confirm stale-block cleanup.
- Optional macOS Focus/Shortcuts integration is not implemented; it was marked optional in the brief.
