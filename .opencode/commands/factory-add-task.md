---
description: Capture a future FocusBar task in the backlog without starting implementation
---

Capture a new FocusBar task for future implementation. User task description: $ARGUMENTS

This is a backlog-capture command only. Do not implement the task, modify application code/tests/dependencies/project settings, run migrations, commit, push, deploy, or start the current active task.

1. Read `AGENTS.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, `docs/FOLLOW_UPS.md`, `.factory/TASK_TEMPLATE.md`, `docs/PRODUCT.md`, and the architecture/security/testing docs needed to classify the request.
2. If `$ARGUMENTS` is empty or too vague to identify an outcome, ask for a concise task description and stop without changing files.
3. Inspect every existing `FB-` task in `docs/ROADMAP.md` (all statuses, including `BACKLOG` and `DONE`) and compare titles, scope, and acceptance criteria with the request. Also check `.factory/WORK_LOG.md` and `docs/FOLLOW_UPS.md` for related work or an existing follow-up.
   - If the request is already covered, report the existing task/follow-up ID and stop. Do not create a duplicate.
   - If it is materially distinct but related, record the related existing ID in the new task.
4. Assign a unique ID:
   - Find all existing `FB-\d+` IDs in the roadmap.
   - Use the next unused integer above the current highest, preserving three digits (for example, the first new task after `FB-010` is `FB-011`).
   - Never reuse or renumber an ID. If a collision is detected, choose the next available integer and report it.
5. Define the task using the roadmap task standard:
   - a concise title that states the outcome;
   - `Status: BACKLOG`;
   - a priority (`P0` data loss/security/permissions/irreversible harm, `P1` release or critical-path prerequisite, `P2` planned product/quality work, `P3` optional improvement) with one sentence of rationale;
   - a type (`feature`, `fix`, `hardening`, `verification`, `docs`, `release`, `security`);
   - dependencies mapped only to existing `FB-` IDs where the relationship is clear; otherwise write `TBD — confirm during refinement` and do not invent dependencies;
   - scope and explicit out-of-scope boundaries;
   - measurable acceptance criteria;
   - security/privacy/permission implications, including TCC permissions, data, code signing, helper/XPC, and network impact (default: none);
   - energy/performance/accessibility implications, or state that none are expected;
   - a test plan with expected commands/failure cases and required manual checks;
   - an evidence line stating that no implementation evidence exists yet.
6. Append the task under `## Backlog — captured, not scheduled` in `docs/ROADMAP.md`. Do not edit existing task blocks or phase ordering.
7. Update factory tracking without changing the active task:
   - append a short backlog-capture note to `.factory/STATE.md` session notes, naming the ID and confirming the current task/status/next action are unchanged;
   - append a concise `.factory/WORK_LOG.md` entry for the capture;
   - do not change the roadmap's current-status line, the active task, task status, or recommended next action.
8. Validate the result:
   - run `bash scripts/validate-factory.sh`;
   - check Markdown links/code fences and `git diff --check` where available;
   - confirm the new task has a unique ID, `Status: BACKLOG`, a priority, a type, dependencies, acceptance criteria, security/performance/testing notes, and no application-code changes.
9. If the request implies an unresolved owner decision (new permission, signing/distribution, new dependency, privacy/data-retention change, irreversible data, or a new privileged component), capture it as a dependency/blocker instead of inventing an answer.

Safety:
- Do not implement, promote, mark `TODO`/`IN_PROGRESS`/`DONE`, or start the task.
- Do not modify application source, tests, `project.yml`, the Xcode project, dependencies, or release settings.
- Do not commit, push, tag, deploy, publish, delete sync folders, or unregister the helper.
- Do not include secrets, signing identities, personal data, or user content in the task text.

Final report: task ID/title/status (`BACKLOG`), priority, type, dependencies, files updated, duplicate-check result, validation result (PASS/FAIL/NOT RUN), and confirmation that the current active task and next action were unchanged.
