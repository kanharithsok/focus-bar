---
name: accessibility
description: Use when auditing or changing VoiceOver, keyboard, focus, contrast, reduced motion, or menu-bar UI accessibility in FocusBar.
---

# Accessibility

FocusBar is a menu-bar-only app with a compact popover and no Dock presence. Accessibility is part of correctness, not polish.

## Review checklist

- Every interactive control has an accessible name and, where useful, a hint/value. Use `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue`, and correct traits.
- Do not rely on color alone for state (blocking active, permission denied, session mode). Pair color with text and/or SF Symbols.
- Timer/status updates: expose the current state to VoiceOver without announcing every second. Prefer a readable remaining-time value and announce meaningful transitions (started, ended, permission changed).
- Keyboard: every action reachable without a mouse, including start/end/emergency stop, capture panel, settings, and history. Check focus order and initial focus in the popover/panel.
- The global capture panel must take focus, accept typing immediately, save on Return, and cancel on Escape.
- Light/dark contrast: verify text, secondary text, disabled controls, warning/error states, and status badges. Avoid low-contrast decorative text.
- Text truncation at the fixed popover width: verify long focus objects, intentions, notes, and localized strings remain understandable (line limits/wrapping, not silent clipping).
- Reduced motion: respect `accessibilityReduceMotion` for nonessential animation; progress/timer motion must remain usable.
- Emergency stop and early-end confirmation must be unmistakable and reachable, including in Commit Mode.
- Do not add tiny fixed font sizes. Prefer system text styles and the existing design tokens.
- Screenshots used in README/tests must not contain personal content.

## Manual evidence

VoiceOver, keyboard-only navigation, and real contrast rendering require a desktop check. Code inspection alone is not a PASS. Record date, macOS version, app build, and observed behavior. Do not claim a VoiceOver pass without running VoiceOver.

## Boundaries

- `menu-bar-ui` owns interaction structure; `design-system` owns visual tokens.
- `testing-strategy` owns test execution. Accessibility fixes still need regression coverage where automatable.
- Do not add a third-party accessibility/UI package without `dependency-management` approval.
