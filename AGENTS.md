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
- `BlockingEngine` coordinates `Blocker` implementations. Blocking is best-effort: never claim guaranteed enforcement, never force-terminate, and never silently report blocking as active when permission failed.
- Browser guard: active tab only, Safari + Chrome only, hostname-only persistence, generic bundled blocked page. Apple Events work runs off the main thread with timeouts.
- No `/etc/hosts`, privileged helper, login item, or system-wide network changes. M6 is documented in `PLAN.md` only and requires explicit approval.

## Testing

- Unit tests use real persistence pointed at temp directories and an injectable clock; `automaticallyTicks: false` for deterministic session tests.
- Run the full test command above before claiming success. Distinguish automated tests from manual macOS-permission/browser checks.
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

## Product guardrails

- Do not add streaks, leaderboards, achievements, guilt messaging, or gamification.
- Do not shame users for missed sessions or low ratings.
- Keep scope to attention management; no unrelated features.
- Local-only: no network calls, telemetry, accounts, or cloud sync.
