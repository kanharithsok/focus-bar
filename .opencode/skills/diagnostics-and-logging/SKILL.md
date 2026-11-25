---
name: diagnostics-and-logging
description: Use when adding logs, debugging runtime failures, reviewing error reporting, or handling helper/browser/sync diagnostics in FocusBar.
---

# Diagnostics and Logging

FocusBar uses Apple's unified logging locally. There is no telemetry, crash upload, or remote diagnostics.

## Rules

- Use `Logger(subsystem: "com.kanharithsok.FocusBar", category: ...)` with a meaningful category (`sync`, `persistence`, `helper`, `blocking`, etc.).
- Log the operation, failure class, and relevant non-sensitive state. Do not log focus objects, capture/intention text, full URLs, paths, queries, page content, sync folder paths, tokens, or signing identities/team IDs.
- Use privacy annotations for uncertain values. Treat user content as private; never make it public in a log message.
- No `print` in app paths. The helper's CLI self-test may print status only.
- Do not add third-party logging, crash reporting, analytics, or remote error collection.
- Never catch an error and log success. If a permission/helper/sync operation fails, surface it in the UI and log the failure honestly.
- Avoid log spam: no per-second timer logs, per-poll browser logs, or per-record sync logs. Log transitions and summarized counts.
- Do not include secrets, tokens, or full file contents in diagnostics.
- A user-visible error should be actionable (for example, open the relevant System Settings pane) without exposing internals.

## Debugging workflow

1. Reproduce with the narrowest scope and inspect the existing log category.
2. Check permission/helper/sync state before assuming a code bug.
3. Use temporary local diagnostics only when needed; remove noisy instrumentation before finishing.
4. For helper/hosts issues, verify whether the app or helper is the failing side; do not weaken XPC/hosts controls to diagnose.
5. Record manual-only checks as manual; a log line is not proof that TCC or root behavior worked.

## Privacy

Follow `privacy-data-lifecycle` and `docs/THREAT_MODEL.md` T8/T16. Unified logs can be collected by the user or support; keep them free of personal content.
