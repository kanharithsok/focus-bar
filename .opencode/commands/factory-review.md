---
description: Review current FocusBar changes for correctness, maintainability and regressions
---

Review FocusBar changes. Focus: $ARGUMENTS

Read `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/QUALITY_AND_TESTING.md`, `docs/SECURITY_AND_PRIVACY.md`, relevant skills, and inspect `git diff` (staged and unstaged) plus surrounding code.

Prioritize findings in this order: data loss or file corruption; security/privacy exposure; XPC/helper or `/etc/hosts` damage; broken session state/timing; sync data loss or cross-device clobbering; permission dishonesty or crashes; reliability/concurrency; broken accessibility/menu-bar UX; energy/performance; maintainability/style.

For each issue, give severity, file/line evidence, impact, and a concrete fix. Separate confirmed defects from speculative concerns. Fix only clear, in-scope defects introduced by the current changes; add regression tests and rerun affected checks. Do not make broad refactors or alter unrelated user work. Never expose secrets, signing identities, personal content, or full URLs. Do not commit, push, tag, deploy, or publish.

Finish with findings (or explicitly no findings), files changed during remediation, exact verification results, and remaining risks.
