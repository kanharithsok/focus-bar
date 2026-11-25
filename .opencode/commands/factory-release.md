---
description: Evaluate FocusBar release readiness without deploying or publishing
---

Perform a FocusBar release-readiness assessment. Optional target/version: $ARGUMENTS

Read `AGENTS.md`, `.factory/STATE.md`, `docs/RELEASE_CHECKLIST.md`, `docs/QUALITY_AND_TESTING.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/DEPENDENCIES.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/DECISIONS.md`, `PLAN.md`, and the `release-readiness` skill. Inspect Git state, `project.yml`, the Xcode project, Package.resolved, signing configuration, and test evidence.

Evaluate each gate in `docs/RELEASE_CHECKLIST.md` as PASS/FAIL/BLOCKED/NOT RUN with evidence:
- task/scope completeness and versioning;
- factory validation, build, unit tests, signed UI smoke, diff hygiene;
- signing/team, helper embedding, `/Applications` requirement, ad-hoc limitations;
- helper registration/approval, hosts apply/remove, force-quit lease, reboot/reinstall cleanup;
- TCC permissions and honest denial behavior;
- privacy: no telemetry/network, hostname-only records, logs, sync disclosure;
- data/schema compatibility, corruption handling, sync merge/tombstones;
- browser/system-wide blocking manual matrix and cache caveats;
- accessibility/VoiceOver and menu-bar UX;
- dependency inventory/provenance and any new privileged component;
- Homebrew cask/notarization status and uninstall/rollback guidance.

Audit every open `docs/FOLLOW_UPS.md` entry: confirm its trigger, owner, and disposition are still valid, and block release on any entry that should have been closed or promoted. A green compile is not a release. Never deploy, tag, publish, notarize, commit, update the Homebrew cask, register/unregister the helper, or enable a feature. Do not invent signing, manual-verification, or backup/restore evidence.

Give a GO/NO-GO recommendation and the exact blocking actions.
