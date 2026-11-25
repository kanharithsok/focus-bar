# FocusBar — Release Checklist

Evaluate readiness; do not deploy, publish, tag, or notarize as part of the review. Any gate that cannot be evidenced is `BLOCKED` or `NOT RUN`, not `PASS`.

## 1. Scope and versioning

- [ ] Intended scope is complete; no `IN_PROGRESS`/`BLOCKED` task is silently shipped.
- [ ] `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` are intentional.
- [ ] `README.md`, `PLAN.md`, `docs/ROADMAP.md`, and `docs/FOLLOW_UPS.md` reflect reality.
- [ ] No unreleased feature is described as available.
- [ ] `LICENSE` and third-party notices are accurate.

## 2. Automated gates

- [ ] `bash scripts/validate-factory.sh` PASS.
- [ ] `xcodegen generate` produces no unexpected project diff (only if project.yml/file membership changed).
- [ ] Debug build PASS with `CODE_SIGNING_ALLOWED=NO`.
- [ ] Full unit suite PASS with the recorded test count and zero failures.
- [ ] Signed `FocusBarUITests` smoke test PASS (or explicit BLOCKED with reason).
- [ ] `git diff --check` PASS; no build artifacts, result bundles, or corrupt files staged.
- [ ] No secrets, signing identities, team IDs, personal data, or absolute home paths in the diff.

## 3. Signing and distribution

- [ ] Signing identity and team are deliberate for this release.
- [ ] For helper testing: app is signed with a stable Apple Development/Developer ID identity and installed in `/Applications`.
- [ ] Ad-hoc/unsigned builds are not presented as capable of system-wide blocking.
- [ ] `SMAppService` embeds the helper at `Contents/MacOS/FocusBarHelper` and the LaunchDaemon plist at `Contents/Library/LaunchDaemons/`.
- [ ] If distributing via Homebrew, the cask update is prepared separately and the quarantine note remains accurate.
- [ ] Notarization/App Store status is stated honestly (not in v1 unless implemented).

## 4. Security and privacy

- [ ] No new TCC permission, entitlement, LaunchDaemon, or network code was added without review.
- [ ] Helper XPC caller validation and hostname validation are intact.
- [ ] Only the marked `/etc/hosts` section is touched; permissions preserved; writes atomic.
- [ ] Lease cleanup covers session end, expiry, force-quit, unregister/SIGTERM, reinstall, and reboot.
- [ ] No full URLs, paths, queries, page content, focus/capture text, or secrets in persistence, snapshots, or logs.
- [ ] Optional sync remains off by default and writes only the selected folder.
- [ ] Dependency inventory matches `docs/DEPENDENCIES.md`; only approved packages are present.
- [ ] Threat-model review is current for any changed trust boundary.

## 5. Data and migration

- [ ] Any persistence schema change has a version bump, compatibility path, and corrupt/newer-file tests.
- [ ] Sync snapshot changes are backward/forward compatible or explicitly refused with a warning.
- [ ] Existing user data is never silently overwritten; corrupt files remain quarantined.
- [ ] Uninstall/helper-removal guidance is accurate.
- [ ] No test resets or deletes real user data.

## 6. Manual release smoke (owner/desktop required)

Record date, macOS version, browser/app versions, and signing class (not team ID).

- [ ] Menu-bar-only launch; no Dock icon; popover renders correctly.
- [ ] Hyperfocus start/complete/early-end; review saves.
- [ ] Scatterfocus and global capture shortcut work; panel focus is usable.
- [ ] Intentions and history/stats behave; relaunch restores correctly.
- [ ] App hide/normal quit request is honest and non-destructive.
- [ ] Safari/Chrome Automation permission and active-tab redirect work; denial is honest.
- [ ] Notifications request at the documented point and deliver or fail honestly.
- [ ] Start at login survives logout/login.
- [ ] Helper registration/approval, hosts apply/remove, mid-session toggle, force-quit lease, reboot cleanup.
- [ ] System-wide blocking in Safari/Chrome/Brave/Zen; Firefox/Arc if installed; cache caveats documented.
- [ ] Optional two-Mac sync propagates and preserves deletions/device-local state.
- [ ] Accessibility/VoiceOver/keyboard pass recorded (`FB-009`).

## 7. Release decision

- [ ] All P0/P1 gates are PASS or explicitly accepted by the owner with a recorded limitation.
- [ ] Open `FU-` entries have a valid trigger/owner/disposition.
- [ ] A GO/NO-GO decision is recorded with the evidence and remaining risks.
- [ ] Rollback/uninstall steps are documented.
- [ ] No deployment, tag, cask publish, or notarization happened without explicit owner instruction.

## Current known release gates

- `FB-005` helper lifecycle/force-quit/reboot manual verification.
- `FB-006` two-Mac sync manual verification.
- `FB-009` accessibility/VoiceOver audit.
- Stable signing/notarization and Homebrew cask process remain owner decisions.
