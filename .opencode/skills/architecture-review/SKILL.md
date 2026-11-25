---
name: architecture-review
description: Use before major implementation, state-machine or persistence changes, new permissions/integrations, or when FocusBar module boundaries and failure modes need review.
---

# Architecture Review

Review the repository, not only diagrams. `docs/ARCHITECTURE.md` is the implementation map; `PLAN.md` §2 is the historical narrative.

## Check

- Layer boundaries: views → `AppModel`/`@Observable` stores → services. No file I/O, AppleScript, or business rules in views. No UI ownership in services.
- Composition: `AppModel` owns long-lived services; coordinators own cross-service sequencing; avoid hidden singletons that bypass test injection.
- Session state machine: explicit states, absolute `endDate`, wake/sleep/relaunch behavior, invalid transitions, early-end/Commit Mode, review window.
- Persistence: `PersistenceController` only; versioned envelope; atomic writes; corrupt quarantine; newer-schema refusal; no persisted derived totals.
- Blocking: `BlockingEngine` coordinates `Blocker` implementations; status must be honest; app hide/quit-request and Safari/Chrome scope; Apple Events off-main with timeouts.
- Helper boundary: minimal XPC, code-signing caller validation, hostname bounds, marker-scoped `/etc/hosts`, atomic writes, fail-open lease. The app must not assume root work succeeded.
- Sync: device-owned snapshot files, merge/tombstone rules, active-session/device-setting exclusions, untrusted remote JSON, folder failure isolation, no network code.
- Threading: main-actor UI, async persistence/helper/file work, no blocking calls on main, no busy polling.
- Failure modes: missing permission, denied TCC, helper unavailable, corrupt JSON, missing sync folder, force-quit. Fail open for blocking; never fake success.
- Build: `project.yml` authority, SPM pin, helper embedding, signing assumptions.
- Maintainability: duplicate logic, speculative abstractions, unnecessary dependencies, stale docs, missing tests.

## Output

For each finding: severity (Critical/High/Medium/Low), concrete file/path/test evidence, impact, options/remediation, and verification. Separate confirmed defects from design concerns. Do not silently reverse an accepted decision; propose a new `D-` entry in `docs/DECISIONS.md`. Do not claim a test or manual check ran unless it did.
