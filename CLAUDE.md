# CLAUDE.md — FocusBar project guidance

## Project

Native macOS 14+ menu-bar productivity app (`MenuBarExtra` with `.window` style, `LSUIElement`). Swift/SwiftUI, local-first, no accounts/network/analytics.

## Build system

- `project.yml` is the source of truth. `FocusBar.xcodeproj` is generated with XcodeGen 2.46+.
- **Never hand-edit `project.pbxproj`.** Add/remove files or settings in `project.yml`, then run `xcodegen generate`.
- The only approved third-party dependency is `KeyboardShortcuts` (SPM, currently 1.10.x). Do not add others without explicit user approval.
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

## Product guardrails

- Do not add streaks, leaderboards, achievements, guilt messaging, or gamification.
- Do not shame users for missed sessions or low ratings.
- Keep scope to attention management; no unrelated features.
- Local-only: no network calls, telemetry, accounts, or cloud sync.
