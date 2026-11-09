# AGENTS.md — FocusBar project guidance

This is the canonical project instruction file for OpenCode and other agents.
`CLAUDE.md` is a symlink to this file for Claude Code compatibility.
`PLAN.md` is the live roadmap/status document; `README.md` is user-facing
documentation. Read those when the task needs milestone context or product
behavior.

## Project

Native macOS 14+ menu-bar productivity app (`MenuBarExtra` with `.window` style, `LSUIElement`). Swift/SwiftUI, local-first, no accounts/network/analytics.

## Build system

- `project.yml` is the source of truth. `FocusBar.xcodeproj` is generated with XcodeGen 2.46+.
- **Never hand-edit `project.pbxproj`.** Add/remove files or settings in `project.yml`, then run `xcodegen generate`.
- The only approved third-party dependency is `KeyboardShortcuts` (SPM, currently 1.17.x). Do not add others without explicit user approval.
- Deployment target: macOS 14.0. Swift 5 language mode.
- The embedded `FocusBarHelper` LaunchDaemon is signed with the app and registered through `SMAppService`. The app must be signed with a stable Apple Development/Developer ID identity and live in `/Applications` when exercising M6. `CODE_SIGNING_ALLOWED=NO` is fine for the unit-test suite but cannot produce a usable daemon. The default ad-hoc Xcode Debug build cannot satisfy the helper's code-signing check; the UI explains this. Never weaken the helper's client requirement to accommodate ad-hoc builds.

## Commands

```sh
xcodegen generate
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

## Architecture rules

- Views → `AppModel` / `@Observable` stores → services. No persistence or AppleScript in views.
- `SessionManager` owns the explicit state machine and absolute `endDate` timing. Never use a decrementing in-memory counter as the source of truth. `refresh()` recomputes from the clock and is called on tick, wake, and restore.
- Persistence goes through the `PersistenceController` actor. JSON files use a versioned envelope, atomic writes, and corrupt-file quarantine. Data lives in `~/Library/Application Support/FocusBar/`.
- Statistics are derived from `[SessionRecord]`; never persist duplicate totals.
- `BlockingEngine` coordinates `Blocker` implementations and the system-wide client. Blocking is best-effort: never claim guaranteed enforcement, never force-terminate, and never silently report blocking as active when permission failed.
- Browser guard: active tab only, Safari + Chrome only, hostname-only persistence, generic bundled blocked page. Apple Events work runs off the main thread with timeouts.
- System-wide website blocking (M6) is opt-in and implemented as a signed `SMAppService` LaunchDaemon (`FocusBarHelper`) plus a marked `/etc/hosts` section. The app side is `SystemBlockingService` / `SystemBlockingClient`; the helper is `HostsBlockingService`.
- Keep the helper's XPC surface minimal and validate callers with a code-signing requirement. Never accept arbitrary paths, shell commands, or unvalidated hostnames.
- The helper only removes/appends its own `# >>> FocusBar managed block >>>` section. Never overwrite unrelated `/etc/hosts` content. Writes must stay atomic and preserve permissions.
- Lease semantics are fail-open: the app heartbeats; the helper removes the block on session end, expiry, reinstall, reboot, or stale helper launch. Never leave a permanent block behind.
- Domain expansion is explicit because `/etc/hosts` has no wildcards. Keep common-subdomain expansion and the UI's best-effort wording honest.
- Do not register the helper automatically, add a Network Extension, write arbitrary system network configuration, or add a second privileged component without explicit user approval.
- The opt-in Mozilla browser restart uses `NSRunningApplication.terminate()` only (a normal quit request) and reopens the browser with `NSWorkspace`. Never force-terminate a browser or delete its profile/cache. It exists only to clear browser-internal DNS/connections for the hosts block; a cached offline page may still need a reload.
- Uninstall/lifecycle edge cases: an app quit/crash/delete leaves the helper's fail-open lease to clear hosts; a helper unregister/SIGTERM cleans immediately; a reboot/helper launch clears stale sections. Deleting the app does **not** auto-unregister the LaunchDaemon; document/use **Remove helper** or System Settings → Login Items & Extensions. Browser caches may outlive hosts cleanup. Do not assume the app can remove a block after it has been deleted.

## Testing

- Unit tests use real persistence pointed at temp directories and an injectable clock; `automaticallyTicks: false` for deterministic session tests.
- Run the full test command above before claiming success. Distinguish automated tests from manual macOS-permission/browser checks.
- Hosts rendering/validation, lease/status logic, settings decoding, and blocking-plan decisions are unit-tested. The privileged daemon, XPC connection, `/etc/hosts` writes, registration approval, and cross-browser behavior require manual verification on a real desktop session.
- Browser/app blocking, Apple Events permission, menu-bar rendering, and the global shortcut panel require manual verification on a real desktop session.

## Data and statistics

- Files: `settings.json`, `sessions.json`, `activeSession.json`, `captures.json`, `intentions.json`, `blockedAttempts.json`.
- `StatsCalculator` is the single source for focus minutes/ratings. Never persist totals, streaks, or derived summaries.
- Focus minutes are attributed to the session's start day. Only Hyperfocus contributes; early-ended sessions contribute actual elapsed time.
- Blocked attempts store only bundle IDs or normalized hostnames plus browser/session/timestamp/detail. Never store full URLs, paths, queries, or page content.

## Manual verification still required

Automated tests cannot validate these; do not claim they passed without a real desktop check:
- Menu-bar-only launch and popover layout.
- Safari/Chrome Automation permission and active-tab redirect to `blocked.html`.
- Real app hide / normal quit-request behavior.
- Global `⌃⌥Space` panel focus and timing.
- Notification permission/display.
- System helper registration/approval, daemon launch as root, XPC code-signing rejection, marked `/etc/hosts` apply/remove, force-quit lease expiry, helper reinstall/reboot cleanup, system-wide blocking in Safari/Chrome/Brave (and Firefox/Arc if installed) plus non-browser clients, and the opt-in Zen/Firefox restart at session start/end.

## Product guardrails

- Do not add streaks, leaderboards, achievements, guilt messaging, or gamification.
- Do not shame users for missed sessions or low ratings.
- Keep scope to attention management; no unrelated features.
- System-wide blocking is still best effort. Do not describe hosts blocking as guaranteed, and do not hide VPN/encrypted-DNS/wildcard limitations. Browsers can reuse cached DNS, cached pages, or existing connections; hosts changes do not invalidate browser-internal caches, so hard reload/browser restart guidance is required.
- Local-only: no network calls, telemetry, accounts, or cloud sync.
