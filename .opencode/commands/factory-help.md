---
description: Explain the FocusBar factory commands, state files and working rules
---

Explain the FocusBar software factory clearly. User question: $ARGUMENTS

Read `AGENTS.md`, `README.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, and `docs/FOLLOW_UPS.md` if needed. Explain the available commands:
- `/factory-start`: inspect/initialize/resume.
- `/factory-plan`: refine the roadmap without coding.
- `/factory-add-task "description"`: capture a future `BACKLOG` task without implementation.
- `/factory-next [FB-ID]`: one task end-to-end.
- `/factory-status`: read-only progress.
- `/factory-test [scope]`: tests and diagnostics.
- `/factory-review [scope]`: diff review and safe in-scope fixes.
- `/factory-security-audit [scope]`: security/privacy review.
- `/factory-release`: release gates, no deployment.

Explain that command prompts run in the current OpenCode session, skills are loaded on demand, and `.factory/STATE.md` plus `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, and `.factory/WORK_LOG.md` persist progress across sessions. `BACKLOG` tasks are captured but not scheduled; they are not eligible for `/factory-next` until promoted to `TODO` by `/factory-plan` or explicit owner direction. Manual-verification tasks require the owner on a real desktop. State that `PLAN.md` is the milestone/verification history and `AGENTS.md` is binding. Do not modify the repository.
