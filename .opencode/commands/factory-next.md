---
description: Implement exactly one next dependency-ready FocusBar roadmap task end-to-end
---

Execute exactly one FocusBar factory task. Optional target task ID or focus: $ARGUMENTS

## Mandatory procedure

1. Read `AGENTS.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/DECISIONS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/QUALITY_AND_TESTING.md`, `docs/DEPENDENCIES.md`, and `docs/RELEASE_CHECKLIST.md`. Load the skills relevant to the task. Inspect Git status/diff and current implementation before editing.
2. If a task ID is supplied, confirm it exists, is not already done, and all dependencies are done. If it is `BACKLOG`, stop and require promotion to `TODO` with scope/dependencies reviewed first. Otherwise select the lowest-numbered dependency-ready `TODO` task from the roadmap; `BACKLOG` and `BLOCKED` tasks are not eligible. Do not bypass blockers or turn a manual-verification task into an agent-only check.
3. Before implementation, summarize the task outcome, acceptance criteria, scope, affected modules/files, security/privacy/permission risks, energy/performance/accessibility considerations, and planned tests. Proceed without asking for routine approval.
4. Implement only that task as a complete vertical slice. Avoid unrelated refactoring and speculative features. Follow the layer rules in `docs/ARCHITECTURE.md` and existing code conventions.
5. Add/update automated tests before or alongside implementation. Include negative/failure cases for permissions, persistence corruption, helper input, hostname validation, sync conflicts, and state transitions where relevant. Use test doubles for browser/AppleScript/helper boundaries; never require real TCC grants in unit tests.
6. Run exact targeted checks and then the relevant broader checks. Inspect test output. Fix failures caused by this task. Never weaken a test, security control, signing requirement, or compiler rule merely to get green.
7. Review the diff for secrets, personal content, accidental files, dependencies, project-file churn, hostname/URL leakage, unsafe file paths, and generated noise.
8. Update documentation, `docs/DECISIONS.md` (only for accepted decisions), task status, `.factory/STATE.md`, and append a concise `.factory/WORK_LOG.md` entry. Give every remaining issue an explicit disposition: an `FB-` task, a `docs/FOLLOW_UPS.md` entry with trigger/owner, a release-checklist gate, or an accepted limitation recorded in the relevant decision. Mark `DONE` only when every acceptance criterion and required verification passed. Otherwise set `IN_PROGRESS` or `BLOCKED` with evidence.
9. Stop after this one task. Do not automatically start the next task.

## Safety

Do not commit/push/tag/deploy/publish, change signing/notarization, register/unregister the helper, delete sync folders, reset user data, or change production settings. Do not output secrets, signing identities, team IDs, or personal content. If an irreversible operation or unresolved product/privacy/distribution decision blocks safe work, stop and record it.

## Final report

State task ID/status; files/modules changed; behavior added; tests/commands with PASS/FAIL/BLOCKED/NOT RUN; security/privacy/permission review; energy/performance/accessibility review; migration/operational notes; remaining issues with their follow-up disposition; exact next dependency-ready task. Be candid about incomplete work. Automated tests do not prove TCC, real browser, root-helper, or two-Mac behavior.
