---
name: release-readiness
description: Use before a FocusBar release, signed build, Homebrew cask update, or GO/NO-GO decision.
---

# Release Readiness

Use `docs/RELEASE_CHECKLIST.md` as the gate list. Verify evidence; do not deploy, tag, publish, notarize, or update the Homebrew cask as part of the review.

## Gates

- Scope/versioning: intended work complete; `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` deliberate; README/PLAN/ROADMAP/FOLLOW_UPS accurate.
- Automated: factory validation PASS; Debug build PASS; full unit suite PASS with counts; signed UI smoke PASS or BLOCKED with reason; `git diff --check`; no artifacts/secrets/personal data.
- Signing: identity/team deliberate; helper embedding paths correct; app in `/Applications` for helper testing; ad-hoc limitations stated honestly; notarization/App Store status accurate.
- Helper: registration/approval, hosts apply/remove, mid-session toggle, force-quit lease, reboot/reinstall cleanup, unregister/SIGTERM.
- Permissions: Automation, Notifications, folder access, Login Items, `SMAppService`; denial/timeout honesty.
- Security/privacy: no new network/telemetry; hostname-only records; no full URLs/paths/content in logs/snapshots; threat-model review current; dependencies approved.
- Data: schema compatibility, corruption handling, sync merge/tombstones, no destructive migration.
- Manual: menu-bar/popover, Hyperfocus/Scatterfocus, capture shortcut, blocking in Safari/Chrome/Brave/Zen (and Firefox/Arc if installed), two-Mac sync, accessibility.
- Distribution: Homebrew cask/update process, uninstall/helper-removal guidance, rollback.
- Follow-ups: every open `FU-` entry has a valid trigger/owner/disposition; no known gap is silently shipped.

## Rules

- A green compile is not a release. `NOT RUN` is not `PASS`.
- Do not invent signing, manual, backup/restore, or notarization evidence.
- Do not weaken tests, permissions, or helper controls to reach green.
- P0/P1 gates must be PASS or explicitly accepted by the owner with a recorded limitation.
- End with a GO/NO-GO recommendation and exact blocking actions.
