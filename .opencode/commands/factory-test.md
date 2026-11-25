---
description: Run the right FocusBar test and quality checks for a scope
---

Test FocusBar. Requested scope: $ARGUMENTS

Read `AGENTS.md`, `docs/QUALITY_AND_TESTING.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, and relevant skills. Inspect the schemes, scripts, and changed files; never invent schemes, targets, or flags.

1. Identify changed modules and risk (session logic, persistence/schema, blocking/AppleScript, helper/hosts, sync, UI/settings, project settings).
2. Run the narrowest relevant unit tests first, then the full suite as appropriate:
   - `xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`
3. Run the Debug build:
   - `xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
4. Run the signed `FocusBarUITests` menu-bar/popover smoke test only when a valid Apple Development identity/team is available. If not, record `BLOCKED`/`NOT RUN` with the reason; do not weaken the signed scheme.
5. For helper/hosts changes, run the helper unit tests and state that real `SMAppService` registration, root XPC, `/etc/hosts` writes, lease expiry, and reboot cleanup require manual signed verification.
6. For browser changes, run the applicable unit tests and state that Safari/Chrome Automation permission, redirects, timeouts, and denial require manual desktop verification.
7. For sync changes, run snapshot/merge/tombstone/convergence tests and state that real iCloud Drive/TCC/two-Mac propagation requires manual verification.
8. Run `bash scripts/validate-factory.sh`, `git diff --check`, and relevant Markdown/fence checks for documentation changes.
9. Report exact commands and PASS/FAIL/BLOCKED/NOT RUN. Diagnose failures and fix only when clearly caused by the current changes; otherwise report separately. Never suppress or rewrite a failing test just to pass.

Do not commit, push, tag, deploy, publish, delete user data, reset sync folders, register/unregister the helper, or modify production/signing settings. Do not mark roadmap tasks done unless the acceptance criteria and required evidence are verified.
