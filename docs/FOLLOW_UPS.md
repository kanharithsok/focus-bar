# FocusBar — Follow-Ups

Durable register for known gaps, accepted limitations, and deferred work. Every entry needs a trigger, an owner, and a disposition. `OPEN` items are reviewed by `/factory-plan` and `/factory-release`; `CLOSED` entries keep their evidence. Do not leave a known gap with no disposition.

| ID | Item | Origin | Trigger | Owner | Status / disposition |
| --- | --- | --- | --- | --- | --- |
| FU-001 | Verify app hide and normal quit-request behavior with real apps | `PLAN.md` M4 manual checks | Before next public release or when blocking code changes | Product owner | OPEN — `FB-002` |
| FU-002 | Verify global `⌃⌥Space` capture panel focus/timing and custom shortcut | `PLAN.md` M3 manual checks | Before next public release or when shortcut/panel code changes | Product owner | OPEN — `FB-003` |
| FU-003 | Verify notification permission prompt timing and delivery/denial | `PLAN.md` M2/M5 manual checks | Before next public release or when notification code changes | Product owner | OPEN — `FB-004` |
| FU-004 | Verify helper force-quit lease cleanup and reboot stale-block cleanup | `PLAN.md` M6 unchecked items | Before next public release and after any helper/lease/hosts change | Product owner | OPEN — `FB-005` |
| FU-005 | Verify two-Mac iCloud Drive sync propagation, deletions, and relaunch access | `PLAN.md` M7 manual checks | Before declaring sync stable or after sync schema/merge changes | Product owner with two Macs | OPEN — `FB-006` |
| FU-006 | Verify system-wide blocking in Firefox/Arc if installed | `PLAN.md` M6 manual checks | When either browser is installed or before a broad release | Product owner | OPEN — `FB-007` |
| FU-007 | Verify Start at login survives logout/login | `PLAN.md`/README manual checklist | Before next public release or when `LoginItemManager` changes | Product owner | OPEN — `FB-008` |
| FU-008 | Accessibility/VoiceOver, keyboard, contrast, reduced-motion audit | Factory adoption | Before next public release | Agent + product owner | OPEN — `FB-009` |
| FU-009 | Re-review privileged helper/XPC/hosts security and add regression tests | Factory adoption | Before next public release, after any helper change, and annually | Agent | OPEN — `FB-010` |
| FU-010 | Verify TCC attributes Automation permission correctly for the `osascript` subprocess on a signed build | `PLAN.md` §5 risk | Whenever the app signature/team or browser automation path changes | Product owner | OPEN — release gate; record signed-build evidence |
| FU-011 | Browser guard can miss background tabs and fast navigations between polls | `PLAN.md` §5 | If users report missed blocks or polling changes | Product owner | OPEN — accepted limitation; documented honestly; revisit only with a product decision |
| FU-012 | Cached DNS/pages/connections can outlive hosts changes; a hard reload/restart may be required | `PLAN.md` §5 / README | If browser behavior changes or restart UX is revisited | Product owner | OPEN — accepted limitation; documented; no browser-profile deletion |
| FU-013 | Sync snapshots are plain JSON and not end-to-end encrypted | `PLAN.md` §5 / README | If sync scope, provider, or privacy requirements change | Product owner | OPEN — accepted limitation; documented; decision needed for E2E encryption |
| FU-014 | Deleting the app does not auto-unregister the LaunchDaemon | `AGENTS.md` / README | If uninstall UX or helper registration changes | Product owner | OPEN — accepted limitation; **Remove helper**/System Settings documented |
| FU-015 | Ad-hoc/unsigned builds cannot use system-wide blocking | `AGENTS.md` / README | If signing/distribution changes | Product owner | OPEN — accepted limitation; UI explains; helper requirement must not be weakened |
| FU-016 | Notarization/release automation and Homebrew cask update process are not implemented | `README.md` Not in v1 / `D-011` | Before broader distribution | Product owner | OPEN — release gate; owner decision |
| FU-017 | Force-quitting FocusBar stops app hiding and the tab guard; only the hosts lease is fail-open | `PLAN.md` §5 / README | If the product claims stronger enforcement | Product owner | OPEN — accepted limitation; documented; do not overclaim |
| FU-018 | Root helper `/etc/hosts` writes cannot be fully validated by automated tests | `AGENTS.md` / `PLAN.md` §5 | Before release and after helper/hosts changes | Agent + product owner | OPEN — `FB-005` + `FB-010`; unit tests plus signed manual checks |
| FU-019 | README screenshots require a manual `xcresulttool` export | README development notes | When screenshots are updated | Agent | OPEN — accepted development workflow; no runtime impact |
| FU-020 | There is no automated TCC/browser/daemon end-to-end test harness | `AGENTS.md` manual-verification list | If CI/desktop automation is introduced | Product owner | OPEN — accepted limitation; manual matrix remains authoritative |
| FU-021 | Signed `FocusBarUITests` menu-bar smoke test was not run on 2026-11-25 because no code-signing identities are installed in the agent environment | `FB-001` baseline | Before next release or whenever a signed build is available | Product owner | OPEN — release gate; run the signed UI smoke and record evidence |

## Review rules

- `/factory-plan` reviews every `OPEN` entry against its trigger and records why it remains deferred or promotes it to `FB-`.
- `/factory-release` blocks on any `OPEN` entry that should have been closed or promoted for the target release.
- Closing an entry requires evidence: a `DONE` task, a signed/manual verification record, or an accepted decision.
- Do not convert a limitation into a guarantee in the UI or README while the entry remains open.
