# Architecture Review Prompt — FocusBar

Read `AGENTS.md`, `.factory/STATE.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/QUALITY_AND_TESTING.md`, `docs/DECISIONS.md`, and `PLAN.md`. Inspect current code, tests, `project.yml`, and the Git diff. Perform a structured review; do not implement broad changes during assessment.

1. Product boundary: is the work still attention management, local-first, and free of gamification/guilt/unrelated scope?
2. Layer boundaries: views → `AppModel`/stores → services; no persistence or AppleScript in views; services do not own UI.
3. Session state machine: absolute `endDate`, wake/sleep/relaunch behavior, invalid transitions, early-end/Commit Mode, review window.
4. Persistence: versioned envelope, atomic writes, corruption quarantine, newer-schema refusal, derived-vs-stored data.
5. Blocking: `BlockingEngine` honesty, hide vs quit request, Safari/Chrome active-tab scope, off-main Apple Events/timeouts, hostname-only records.
6. Privileged helper: caller code-signing validation, minimal XPC, hostname bounds, marker-scoped hosts editing, atomic writes/permission preservation, fail-open lease, registration UX.
7. Sync: device-owned snapshots, merge/tombstones, device-specific/active-session exclusions, untrusted remote JSON, folder errors, no network code.
8. Permissions: TCC prompts at point of use, denial/timeout honesty, no extra Accessibility/Screen Recording/Full Disk Access, signing/`SMAppService` constraints.
9. Privacy: no URLs/page content, no telemetry, privacy-aware logs, sync disclosure.
10. Reliability/performance: timers/polling only when needed, memory/energy, main-thread work, failure cleanup.
11. Accessibility/UI: VoiceOver/keyboard/contrast/reduced motion, menu-bar-only affordances, compact layout.
12. Build/release: `project.yml` authority, SPM pin, XcodeGen diff, signing, helper embedding, Homebrew/notarization state.
13. Maintainability: unnecessary abstractions/packages, duplicated logic, stale docs, test gaps.

For each finding provide severity (Critical/High/Medium/Low), evidence (file/path/test), impact, remediation, and verification. Separate confirmed defects from design concerns. Do not claim a test ran unless it did. Do not expose secrets, signing identities, or personal data. Update `docs/DECISIONS.md` only after an accepted decision.
