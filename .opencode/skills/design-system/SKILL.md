---
name: design-system
description: Use when changing FocusBar visual tokens, reusable components, typography, spacing, icons, colors, or the calm menu-bar visual language.
---

# Design System

FocusBar should feel calm, compact, and native. Visual polish supports attention; it should not compete with it.

## Rules

- Reuse the existing tokens/components in `FocusBar/Views/Components.swift` and the established SwiftUI patterns. Do not introduce a parallel style system.
- Use system fonts, semantic colors, and SF Symbols. Do not add a font or icon package.
- Support light and dark appearance. Verify contrast for body/secondary text, disabled controls, status colors, and warnings.
- Keep the popover compact: clear hierarchy, restrained spacing, no nested scroll traps, and no critical action below an unpredictable fold.
- Use color plus text/symbol for state; never color alone.
- Motion should be purposeful. Respect reduced motion for nonessential animation.
- Standardize spacing, corner radii, and control sizing through the shared components; avoid one-off styling.
- Buttons and labels must describe the action honestly (for example "End early…", "Emergency stop…", "Remove helper").
- Do not add gamified visuals, streak counters, confetti, leaderboards, or guilt copy.
- Do not show a fake "protected" badge when permission/helper status is unknown or denied.
- Screenshots used in README/tests must use sample data only and respect the current appearance.

## Review

- Check the idle, hyperfocus, scatterfocus, review, history, settings, and blocking-status surfaces for consistency.
- Check long strings, custom durations, long focus objects, and error messages at the fixed popover width.
- Confirm the visual change does not add accessibility regressions (`accessibility` skill).
- Confirm no new dependency/asset pipeline was introduced (`dependency-management`).
- Visual feel and real rendering require a desktop check; a UI smoke test proves structure, not polish.
