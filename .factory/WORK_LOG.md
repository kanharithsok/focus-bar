# FocusBar Factory Work Log

Append one concise section after each completed or blocked task. Do not delete history. Do not include focus-object text, capture/intention text, hostnames tied to a person, folder paths, secrets, or signing identities.

## Initial state
- Factory instructions installed on 2026-11-25. Product implementation was not changed; status must be determined by inspecting the repository.

## 2026-11-25 — Factory adoption — DONE (process only)
- Added the factory workflow adapted from the `dak-peak` setup: `.factory/` state/log/task template, 10 `/factory-*` OpenCode commands, 17 FocusBar-specific skills, `docs/` operating documents, prompts, and `scripts/validate-factory.sh`.
- Added `docs/ROADMAP.md` as the task-level `FB-NNN` roadmap and `docs/FOLLOW_UPS.md` as the durable register for known manual-verification and limitation entries.
- Updated `AGENTS.md` with the factory workflow and its durable state files. `PLAN.md` remains the milestone/verification history.
- Checks: `bash scripts/validate-factory.sh` PASS. Markdown/fence/link checks PASS. OpenCode discovery for this repository lists all 10 `/factory-*` commands; the running session discovered the 17 skills. No application build or test run during this process-only change; the last recorded baseline is 2026-11-11 (Debug build PASS, 105 unit tests 0 failures, signed UI smoke test PASS) from `PLAN.md` §7.
- No app source, `project.yml`, Xcode project, tests, dependencies, or product behavior changed. No commit, push, tag, deploy, or release was performed.
- Next: `/factory-next FB-001` — verify the factory baseline and record real build/test evidence.
