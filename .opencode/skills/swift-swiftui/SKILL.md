---
name: swift-swiftui
description: Use when writing or reviewing Swift, SwiftUI, AppKit interop, concurrency, observable state, or project structure in FocusBar.
---

# Swift and SwiftUI

## Project constraints

- Deployment target macOS 14.0; Swift 5 language mode; `SWIFT_STRICT_CONCURRENCY: minimal`.
- Prefer SwiftUI. Use AppKit only for what SwiftUI cannot do cleanly (menu-bar/window control, `NSWorkspace`, `NSAlert`, `NSFileCoordinator`, `SMAppService`).
- `project.yml` is the source of truth. Add files/settings there, run `xcodegen generate`, and never hand-edit `project.pbxproj`.

## State and concurrency

- Use `@Observable` stores and `@MainActor` for UI-facing state. Follow the existing ownership/composition in `AppModel`; do not add hidden singletons.
- Views must not perform persistence, AppleScript, or helper I/O. Send intents to stores/services.
- Use structured concurrency (`Task`, async/await) and cancel tasks on teardown. Do not block the main thread with file, process, or XPC work.
- AppKit notifications/observers run on the main actor where UI is touched; remove observers and cancel tasks when the owner is deallocated or the feature is disabled.
- Avoid detached tasks unless isolation is intentional and documented.
- Use `Clock`/injectable time in session logic so tests can control time.

## Correctness

- No force unwraps, `try!`, or `fatalError` on user-driven paths. Surface recoverable errors.
- Prefer value types for models; keep `Sendable` boundaries explicit.
- Make invalid states unrepresentable where practical; reject invalid state transitions explicitly.
- Absolute times (`Date`) over decrementing counters for session timing.
- Handle `nil`/corrupt/partial data defensively; never silently discard user content.
- Use `Logger` with privacy annotations, not `print`, in app code.
- Avoid retain cycles in closures/observers; use `[weak self]` where ownership warrants it.

## UI

- Reuse `Components.swift` and existing tokens. Do not introduce a UI kit.
- Respect light/dark appearance, accessibility labels, and reduced motion.
- Keep the menu-bar popover responsive; long work belongs off-main.

## Testing

- Unit-test logic with XCTest, real persistence in temp directories, and injectable time.
- UI smoke tests use the signed scheme and a temporary data directory.
- Prefer small testable services over testing SwiftUI rendering details.

Do not change the deployment target, language mode, or signing assumptions without an owner decision.
