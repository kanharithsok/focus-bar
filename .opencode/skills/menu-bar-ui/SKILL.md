---
name: menu-bar-ui
description: Use when changing the FocusBar popover, session views, settings, menu-bar label, global capture panel, or menu/keyboard interaction.
---

# Menu-Bar UI

FocusBar is a menu-bar-only `MenuBarExtra` `.window` app (`LSUIElement`). It has no Dock icon and limited screen real estate.

## Rules

- Keep the popover compact and predictable: primary action/status first, secondary settings below, no critical action hidden behind an unpredictable fold.
- The menu-bar label should show the most useful state (idle vs remaining time) without flicker or overly verbose text. Use a monospaced-digit style where the timer would otherwise jitter.
- Reuse `RootView`/`Components.swift` patterns. Do not create a parallel design language.
- Views render state and send intents to `AppModel`/stores. No persistence, AppleScript, helper calls, or session rule logic in a view.
- Session transitions must be reflected immediately from `SessionManager` state, not a local view timer.
- Early-end/commit-mode/emergency-stop affordances must remain reachable and honest. Never hide the only exit path.
- Settings changes should apply predictably (immediately or on save, consistently) and never silently fail.
- The global capture panel should take focus, accept input immediately, save on Return, cancel on Escape, and not disturb the foreground app after dismissal.
- Use standard macOS keyboard shortcuts where they exist; avoid collisions with the global shortcut.
- Support light/dark appearance and accessibility labels; do not rely on hover-only affordances.
- Do not add gamification, guilt copy, or dashboard-style clutter.
- Real visual feel requires a desktop check. `FocusBarUITests` proves structure, not polish.

## Testing

- Use the signed UI smoke test for the idle popover and key controls.
- Unit-test view-model/state decisions rather than SwiftUI rendering where possible.
- Manually verify menu-bar-only launch, popover focus, the global shortcut, and settings persistence. Record `NOT RUN` honestly if unavailable.
