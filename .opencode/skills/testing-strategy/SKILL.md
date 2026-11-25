---
name: testing-strategy
description: Use when designing, writing or running unit, persistence, sync, helper, UI, or regression tests for FocusBar.
---

# Testing Strategy

Use a small, reliable pyramid: many fast unit tests, focused persistence/sync/helper-logic tests, one signed UI smoke test, and explicit manual checks for TCC/root/browser/two-Mac behavior.

## Layers

- **Unit (XCTest):** session state/timing, early end/review, intentions, captures, stats, hostname matching, hosts rendering/removal, blocking decisions, settings decoding, helper lease/status logic, sync merge/tombstones.
- **Persistence:** real `PersistenceController` in unique temp directories; corruption/quarantine; newer-schema refusal; atomic replacement.
- **Sync:** snapshot round trips, two-device convergence, tombstones, shared-settings timestamps, corrupt/newer/oversized files, device-local exclusions.
- **UI smoke (XCUITest):** signed `FocusBarUITests`, temporary data directory, menu-bar/popover, key controls, screenshot.
- **Manual:** TCC prompts/denial, Safari/Chrome redirects, real helper registration/root XPC/hosts writes, force-quit/reboot cleanup, two-Mac sync, accessibility.

## Rules

- Derive tests from acceptance criteria and failure modes, not implementation details.
- Use `automaticallyTicks: false` and the injectable clock for deterministic session tests.
- Use real persistence with temp directories, not mocks that hide file behavior.
- Use deterministic fakes for browser/AppleScript/helper boundaries; do not require TCC grants in unit tests.
- Test negative paths: denied permission, timeout, invalid transition, corrupt JSON, malformed hostname, sync conflict, missing folder, helper unavailable.
- Keep tests isolated; never write to the real Application Support directory or a real sync folder.
- Test data is synthetic; no personal content.
- Run the narrowest suite first, then the full unit suite and Debug build.
- Never weaken assertions, delete failing tests, or silently skip a test. Document a genuine flake and stabilize it.
- Report exact commands and real results. `NOT RUN` is not `PASS`.
- A signed UI/manual check that cannot run is `BLOCKED`/`NOT RUN` with the reason, not inferred from unit tests.

## Commands

```sh
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Use the signed `FocusBarUITests` command from `AGENTS.md` only when signing is available.
