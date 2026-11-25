# FocusBar Factory State

> Durable state for OpenCode sessions. Keep this concise and factual. Update only after inspecting the repository and completing verification.

- Last updated: 2026-11-25
- Current phase: Post-v1 maintenance / baseline verified
- Current task: None
- Task status: IDLE
- Last completed factory task: FB-001 — Verify the factory baseline (DONE)
- Last product milestone: M7 — optional multi-Mac sync (implemented; two-Mac propagation remains manual)
- Blockers: No code blocker. The signed UI smoke and manual TCC/helper/browser/two-Mac checks need a signed build and/or the owner on a real desktop; see `FU-021` and `docs/FOLLOW_UPS.md`.
- Last verification: 2026-11-25 — FB-001 baseline: factory validation PASS; Debug build PASS (`CODE_SIGNING_ALLOWED=NO`); 105 unit tests with 0 failures; signed `FocusBarUITests` smoke NOT RUN because `security find-identity` reported zero code-signing identities. Working tree clean before/after; no application source, project, dependency, or test changes.

## Verified foundation

- **Product:** FocusBar v1.0.1 (build 2), native macOS 14+ menu-bar app (`MenuBarExtra` `.window`, `LSUIElement`). Milestones M1–M7 are implemented: session engine, intentions/history, Scatterfocus/capture, best-effort app and Safari/Chrome tab blocking, statistics, opt-in system-wide hosts blocking through a signed `SMAppService` LaunchDaemon, and opt-in folder-based multi-Mac sync.
- **Architecture:** Views → `AppModel` / `@Observable` stores → services. `SessionManager` owns the explicit state machine and absolute `endDate` timing. `BlockingEngine` coordinates `AppBlocker`/`BrowserBlocker`; `SystemBlockingService`/`SystemBlockingClient` own helper registration, XPC, and the fail-open lease. `SyncCoordinator`/`FolderSyncEngine`/`SyncMerge` own optional folder sync.
- **Persistence:** `PersistenceController` actor; versioned JSON envelopes, atomic writes, corrupt-file quarantine, newer-schema refusal. Data lives in `~/Library/Application Support/FocusBar/` unless the user enables sync.
- **Privileged helper:** `FocusBarHelper` validates XPC callers by code-signing requirement, validates/expands hostnames, and atomically manages only its marked `/etc/hosts` section. The lease is fail-open (30 s lease, 8 s heartbeat).
- **Tests:** `FocusBarTests` covers session transitions/expiry/restore, persistence and corruption handling, hostname matching, hosts rendering/removal, blocking-plan decisions, app settings, and sync merge/tombstones/convergence. `FocusBarUITests` is a signed menu-bar/popover smoke test plus a screenshot test. Last recorded run: 105 unit tests, 0 failures (2026-11-25). Signed UI smoke remains NOT RUN in this environment (`FU-021`).
- **Toolchain:** macOS 27.2 (arm64), Xcode 27.2 (27B52), Swift 6.4.2 compiler with Swift 5 language mode, XcodeGen 2.48.0. Deployment target macOS 14.0. Only third-party runtime dependency: `KeyboardShortcuts` 1.17.0 (SPM).
- **Git:** Branch `dev`; latest commit `90572cf` (`chore: add FocusBar software factory workflow`), tracking `origin/dev`. Working tree was clean before and after the FB-001 verification. No commit, push, tag, or release was performed during this task.
- **Factory package:** `bash scripts/validate-factory.sh` PASS on 2026-11-25. It validates required docs/state files, 10 factory commands, 17 required skills, command descriptions, skill folder/frontmatter names, skill descriptions, and coverage-matrix entries. OpenCode discovery for this repository lists all 10 `/factory-*` commands with the expected descriptions; the running session also discovered the 17 skills.
- **Documentation:** `AGENTS.md` remains the canonical agent instruction file; `PLAN.md` remains the milestone/verification history; `docs/ROADMAP.md` is the task-level factory roadmap; `docs/FOLLOW_UPS.md` is the durable register for known gaps.

## Session notes

- The factory was adopted from the `dak-peak` pattern on 2026-11-25 and adapted for a native macOS app. Web/backend/tenant/payment skills were replaced with Swift/SwiftUI, menu-bar UI, macOS permissions, privileged-helper security, browser automation, persistence/sync, accessibility, energy/performance, and diagnostics skills.
- `PLAN.md` remains the source of truth for milestone history and verification evidence. Do not rewrite its historical entries to make factory tasks look complete.
- Task IDs are `FB-NNN`. New work enters through `/factory-add-task` as `BACKLOG`; only `/factory-plan` or explicit owner direction promotes a task to `TODO`.
- No application source, `project.yml`, Xcode project, tests, dependencies, or product behavior changed during factory adoption.
- FB-001 completed (2026-11-25): factory validation PASS; Debug build PASS with `CODE_SIGNING_ALLOWED=NO`; 105 unit tests with 0 failures; signed `FocusBarUITests` smoke NOT RUN because the environment has zero code-signing identities. One benign Xcode AppIntents metadata warning; no Swift compiler warnings. Working tree clean before/after; no source/project/dependency/test changes. `FU-021` tracks the missing signed UI evidence. No dependency-ready `TODO` remains; `/factory-plan` should refine/promote a `BACKLOG` task, or `/factory-add-task` should capture new work.
- Manual verification remains outstanding for app hide/quit behavior, the global capture shortcut, notifications, start-at-login, force-quit/reboot helper cleanup, two-Mac sync, Firefox/Arc system-wide blocking, and a signed Accessibility/VoiceOver pass. These are tracked in `docs/FOLLOW_UPS.md` and `docs/ROADMAP.md`.
- Do not commit, push, tag, deploy, publish, reset data, or unregister the helper without explicit owner instruction.
- Next action: `/factory-plan` (promote a `BACKLOG`/manual gate or refine new work) or `/factory-add-task "description"`.

## Active decisions needing owner input

- Release and distribution path: notarization/release automation and the Homebrew cask update process are not implemented. Determine whether v1 remains development-signed or moves to Developer ID notarization.
- Stable signing identity and team for builds that exercise the M6 helper; ad-hoc builds cannot register a usable daemon.
- Whether to add friendly active-tab protection for Firefox/Arc (currently system-wide hosts blocking only).
- Whether to move optional sync from folder snapshots to CloudKit (requires a paid Apple Developer Program membership and a product/privacy trade-off).
- Whether sync snapshots should gain end-to-end encryption or documented retention/export controls.
- Any new product feature or scope change; the product guardrails in `docs/PRODUCT.md` still apply.
