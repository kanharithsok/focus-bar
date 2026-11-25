---
name: performance-and-energy
description: Use when changing timers, polling, wake handling, sync frequency, memory use, or background work in FocusBar.
---

# Performance and Energy

FocusBar is a continuously running menu-bar app. Wasted wakeups and polling drain battery and erode trust.

## Rules

- A 1-second tick is appropriate only while a session is active or a countdown is visible. Do not run a 1-second timer while idle.
- Recompute from the absolute `endDate`; do not add work simply to animate a counter.
- Browser polling only while a supported browser is foreground, with an immediate check on activation and a sensible interval (~1 s). Do not poll Safari/Chrome in the background.
- Coalesce/debounce blocked-attempt writes and sync triggers. Do not write a JSON file for every poll.
- Sync at launch, on debounced changes, activation, wake, and a low-frequency periodic check while enabled. Do not busy-loop or force frequent full snapshot exports.
- Apple Events and file coordination must be off the main thread. Use timeouts for subprocess work.
- Keep snapshots bounded and skip oversized remote files; do not load/merge unbounded data.
- Avoid retaining large histories in multiple copies. Statistics are derived on demand from stored records.
- Wake/sleep handling should refresh state once, not create duplicate timers/tasks.
- Measure before optimizing. Use Instruments/Energy Log locally when a change is expected to affect cost; there is no telemetry.
- Do not add a background network call, analytics timer, or always-on helper heartbeat outside an active session.
- Verify no leaked observers/tasks after session end, app hide, or sync disable.

## Review questions

- What wakes the CPU while idle? Is it necessary?
- What runs per second, per poll, per file write, or per sync?
- Does the work stop on session end, permission denial, helper failure, and app deactivation?
- Is there a retry/backoff story, or could a failure spin?
- Does the change affect menu-bar responsiveness or popover open time?

Manual energy measurements are evidence only when actually run; otherwise state `NOT RUN`.
