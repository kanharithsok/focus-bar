# FocusBar Bootstrap Prompt

You are starting or resuming the FocusBar engineering factory. Read `AGENTS.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/QUALITY_AND_TESTING.md`, `docs/DEPENDENCIES.md`, `docs/DECISIONS.md`, and `PLAN.md` before substantial changes. Load the relevant skills from `.opencode/skills/`.

FocusBar is a native macOS 14+ menu-bar attention app. It is local-first: no accounts, FocusBar servers, analytics, telemetry, or app-initiated network calls. Optional multi-Mac sync writes JSON snapshots only to a folder the user selects. System-wide website blocking is opt-in and uses a signed `SMAppService` LaunchDaemon plus a marked `/etc/hosts` section; it is best effort, not guaranteed.

## First run

1. Inspect the repository tree, Git branch/status/diff, existing app sources, tests, and toolchain. Preserve all user work.
2. Run `bash scripts/validate-factory.sh` and report the result.
3. Reconcile `.factory/STATE.md` with repository evidence. Do not mark work done because files exist; inspect and run checks.
4. If the factory was just adopted, run `FB-001` (baseline verification) before feature work: build, unit tests, and the signed UI smoke test when signing is available.
5. If a baseline already exists, identify the next dependency-ready `TODO` in `docs/ROADMAP.md`. `BACKLOG` tasks are not eligible until promoted.
6. Implement at most one task per `/factory-next` call.

## Principles

- Product guardrails: no streaks, leaderboards, achievements, guilt messaging, or unrelated features. Blocking is best effort and must be described honestly.
- `project.yml` is the source of truth. Never hand-edit `project.pbxproj`.
- `KeyboardShortcuts` is the only approved third-party runtime dependency. Do not add others without explicit owner approval.
- The helper must keep a minimal XPC surface, validate callers by code-signing requirement, and only touch its marked `/etc/hosts` section. Never weaken these controls for ad-hoc builds.
- Automated tests cannot prove TCC permission behavior, real browser blocking, helper registration/root operation, or two-Mac sync. Record those as manual checks, not PASS.
- Do not commit, push, tag, deploy, publish, reset data, or unregister the helper without explicit owner instruction.
- Ask the owner only for decisions that block safe progress or change money, privacy/legal obligations, production services, signing/distribution, or irreversible data.

At the end of a bootstrap session, update `.factory/STATE.md` and `.factory/WORK_LOG.md` with actual results and recommend the next exact command.
