---
description: Show truthful FocusBar project and factory progress without changing code
---

Report FocusBar status. Optional area: $ARGUMENTS

Read `AGENTS.md`, `.factory/STATE.md`, `.factory/WORK_LOG.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/DECISIONS.md`, `docs/QUALITY_AND_TESTING.md`, and `PLAN.md`, and inspect Git status/tree. Do not modify code or task status.

Report:
- current branch and clean/modified/untracked status;
- actual implemented capabilities verified by source/tests, not docs alone;
- completed, in-progress, blocked, backlog, and next dependency-ready task counts/IDs;
- open `docs/FOLLOW_UPS.md` entries, their triggers, and whether any trigger has occurred;
- last verified build/test/UI/manual results and how recent they are;
- known security, privacy, permission, helper/XPC, sync, and release blockers;
- unresolved owner decisions;
- recommended next command.

Distinguish code that exists from code that is tested and from features that are manually verified or production-ready. Never claim completion from roadmap checkboxes or documentation alone. State `NOT RUN` when no current evidence exists.
