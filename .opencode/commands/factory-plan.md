---
description: Inspect and refine the dependency-aware FocusBar roadmap without implementing code
---

Plan FocusBar work. Optional focus: $ARGUMENTS

Read `AGENTS.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/DECISIONS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/QUALITY_AND_TESTING.md`, `docs/DEPENDENCIES.md`, `docs/RELEASE_CHECKLIST.md`, and `PLAN.md`. Inspect the repository, Git status, and current implementation.

Produce or refine `FB-` tasks with unique IDs, dependencies, type, concise scope, out-of-scope notes, measurable acceptance criteria, security/privacy/permission implications, energy/performance/accessibility notes, a test plan, and a manual-verification plan. Preserve completed task history. Do not mark unverified tasks complete. Do not rewrite accepted decisions silently; propose a new `D-` entry in `docs/DECISIONS.md` when a decision changes.

Backlog tasks created by `/factory-add-task` are captured but not scheduled. Review their scope and dependencies before promoting them to `TODO`; do not silently promote or implement them in this command. Manual-verification tasks require the owner and a real desktop; leave them `BACKLOG` unless the owner is available.

Review open entries in `docs/FOLLOW_UPS.md` against their triggers. Refine and promote triggered entries to `BACKLOG`/`TODO`, or record why they remain deferred. Mark resolved entries `CLOSED` with evidence. Do not leave a known gap with no disposition.

This is a planning-only command: do not implement application code, alter `project.yml`/the Xcode project, change dependencies, run destructive commands, or perform manual TCC/helper/browser tests. Update roadmap/state only when the change is a clear planning improvement.

Report the recommended next task, dependency/critical-path notes, and unresolved owner decisions.
