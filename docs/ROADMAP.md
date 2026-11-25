# FocusBar — Factory Roadmap

This is the task-level execution roadmap for the FocusBar software factory. `PLAN.md` remains the milestone and verification history; `AGENTS.md` remains the binding rule set. Do not rewrite `PLAN.md` history to match this file.

- Current status (2026-11-25): FocusBar v1.0.1, M1–M7 implemented. `FB-001` baseline verified: factory validation PASS, Debug build PASS, 105 unit tests with 0 failures. Signed UI smoke NOT RUN (no code-signing identity available).
- Active task: None.
- Next action: `/factory-plan` to refine/promote a `BACKLOG` task, or `/factory-add-task` for new work. Manual gates require the owner on a real desktop.
- Blockers: No code blocker. The signed UI smoke and manual TCC/helper/browser/two-Mac checks need a signed build and/or the owner on a real desktop; see `FU-021` and `FB-002`–`FB-008`.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| `TODO` | Dependency-ready and eligible for `/factory-next`. |
| `IN_PROGRESS` | Started, not yet verified. |
| `BLOCKED` | Cannot proceed without a decision, permission, hardware, or dependency. Record the exact blocker. |
| `BACKLOG` | Captured, not scheduled; not eligible for `/factory-next` until promoted. |
| `DONE` | Every acceptance criterion and required verification passed, with evidence recorded. |
| `MANUAL` | A manual check recorded outside the task status; never claim it passed without a desktop session. |

## Critical path

`FB-001` is complete and establishes the current build/test evidence. Manual gates (`FB-002`–`FB-008`) run before a public release. `FB-009`/`FB-010` are quality/security hardening tasks that can run in parallel with owner-driven manual checks.

## Task queue

### FB-001 — Verify the factory baseline

- Status: DONE
- Priority: P1
- Type: verification
- Dependencies: None
- Owner: OpenCode engineering agent

**Problem / outcome**

The factory was adopted without rebuilding or retesting the app. Establish a trustworthy, current baseline before any feature or release work.

**Scope**

- Run `bash scripts/validate-factory.sh`.
- Confirm the working tree contains only factory/documentation changes (or report the difference).
- Run the Debug build and unit-test suite with `CODE_SIGNING_ALLOWED=NO` exactly as documented in `AGENTS.md`.
- Run the signed `FocusBarUITests` menu-bar smoke test only if a valid Apple Development identity/team is available; otherwise record `NOT RUN` with the reason.
- Record exact commands, environment facts, results, and any failures in `.factory/STATE.md` and `.factory/WORK_LOG.md`.
- Update `docs/FOLLOW_UPS.md`/`docs/ROADMAP.md` if a new gap or blocker is discovered.

**Out of scope**

- Fixing pre-existing product bugs (capture them as new `FB-`/`FU-` entries).
- Manual desktop/permission checks.
- Changing signing, `project.yml`, dependencies, product code, or tests.
- Committing, pushing, tagging, or releasing.

**Acceptance criteria**

- [x] Factory validation PASS, with output captured.
- [x] Debug build result recorded as PASS/FAIL/BLOCKED/NOT RUN with the exact command.
- [x] Unit-test result recorded with test count and failures.
- [x] Signed UI smoke result recorded as PASS/BLOCKED/NOT RUN with the reason.
- [x] No application source, project, dependency, or test changed by this task.
- [x] `.factory/STATE.md` and `.factory/WORK_LOG.md` updated with real evidence.

**Security / privacy / permissions**

No new permissions or data access. Do not print signing identities, team IDs, user data, or absolute home-directory paths in committed logs.

**Performance / accessibility**

Not applicable; this is a verification task.

**Test plan**

```sh
bash scripts/validate-factory.sh
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
# Optional signed smoke test when a valid identity/team is configured:
xcodebuild -project FocusBar.xcodeproj -scheme FocusBarUITests \
  -destination 'platform=macOS' test \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=<team>
```

**Evidence**

- Factory validation: **PASS** — 2026-11-25, `bash scripts/validate-factory.sh`; full output captured locally, not committed.
- Debug build: **PASS** — 2026-11-25, `xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`; `** BUILD SUCCEEDED **`. One benign Xcode AppIntents metadata warning (no AppIntents dependency); no Swift compiler warnings.
- Unit tests: **PASS** — 2026-11-25, `xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO`; **105 tests, 0 failures**; `** TEST SUCCEEDED **`.
- Signed UI smoke: **NOT RUN** — `security find-identity -v -p codesigning` reported 0 code-signing identities in this environment, so the signed `FocusBarUITests` scheme could not be exercised. Tracked as `FU-021`.
- Working tree: clean before and after; `git diff --check` PASS; no application source, project, dependency, or test changes.
- Environment: macOS 27.2 arm64, Xcode 27.2 (27B52), Swift 6.4.2 compiler with Swift 5 language mode, XcodeGen 2.48.0, deployment target macOS 14.0.

No new gap was found in the automated baseline. `FU-021` covers the missing signed UI evidence.

## Manual verification gates

These tasks require a real macOS desktop session and, for permission/helper checks, a signed build and possibly a second Mac. They are `BACKLOG` so `/factory-next` does not attempt them without the owner present. `FB-001` is now `DONE`, so their dependency is satisfied; promote one to `TODO` only when the owner is available to perform or observe the check.

### FB-002 — Verify app hide and normal quit requests

- Status: BACKLOG
- Priority: P2
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner with agent support

**Scope:** With selected test apps, start a Hyperfocus session and verify hide-by-default; enable the normal quit-request option and verify a cooperative app quits; verify an app that refuses is not force-terminated and the UI reports honestly.

**Out of scope:** Force-killing apps, changing blocking behavior, adding app-specific exceptions.

**Acceptance criteria**

- [ ] Hide behavior works on launch/activation during a session.
- [ ] Normal quit request works where the app honors it.
- [ ] Refusal is reported honestly; no force termination or data loss.
- [ ] Blocking stops or reports accordingly when the session ends.

**Evidence:** Record date, macOS version, app names/versions, and observed behavior (no personal data).

### FB-003 — Verify the global capture shortcut and panel focus

- Status: BACKLOG
- Priority: P2
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner with agent support

**Scope:** With FocusBar in the background, press `⌃⌥Space`, type a capture, press Return; verify the panel takes focus, saves once, and dismisses. Verify Escape cancels, a custom shortcut works, and the panel does not steal focus unexpectedly.

**Acceptance criteria**

- [ ] Default shortcut opens the panel from another app.
- [ ] Return saves exactly one capture and dismisses; Escape cancels.
- [ ] Custom shortcut replaces the default and persists after relaunch.
- [ ] Panel focus/timing feels usable and does not disturb the active app after dismissal.

### FB-004 — Verify notification permission and delivery

- Status: BACKLOG
- Priority: P2
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner with agent support

**Scope:** Verify no permission prompt at launch; the first session with notifications enabled requests permission; a granted notification is delivered; denial is handled without crashing or pretending notifications work; the setting can be changed later.

**Acceptance criteria**

- [ ] No permission request at launch.
- [ ] Prompt appears at the documented point of use.
- [ ] Granted path delivers the expected notification.
- [ ] Denied path is honest and non-blocking.
- [ ] Permission state survives relaunch and matches System Settings.

### FB-005 — Verify helper lifecycle, force-quit lease, and reboot cleanup

- Status: BACKLOG
- Priority: P0
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner with agent support

**Scope:** Using a properly signed build installed in `/Applications`, register/approve the helper, start a session, confirm the marked hosts section, end the session, and confirm exact restoration. Re-verify mid-session enable/disable and unregister/SIGTERM cleanup. Specifically close the documented gaps: force-quit FocusBar during a session and verify the 30-second lease clears the block; reboot with a stale block and verify cleanup on helper launch.

**Acceptance criteria**

- [ ] Helper registers only after explicit Settings action and reports approval honestly.
- [ ] Marked hosts section applies and removes exactly; unrelated content and permissions are preserved.
- [ ] Mid-session enable/disable updates the section.
- [ ] Force-quit removes the block after lease expiry (no permanent block).
- [ ] Reboot/helper launch removes a stale marked section.
- [ ] Unregister/SIGTERM removes the block immediately.
- [ ] Ad-hoc/unsigned clients are rejected and the UI explains the setup requirement.

**Evidence:** Record signing class (not team ID), macOS version, checksums before/after, and observed timing.

### FB-006 — Verify two-Mac folder sync

- Status: BACKLOG
- Priority: P1
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner with two Macs

**Scope:** On two Macs signed into the same Apple Account, choose the same iCloud Drive folder; verify sessions/captures/intentions/blocked attempts/shared settings arrive in both directions; verify a deleted capture/intention does not return; verify the active session and device-specific settings stay local; relaunch both apps and confirm folder access; test an unavailable/offline folder without losing local data.

**Acceptance criteria**

- [ ] Both devices write only their own snapshot file.
- [ ] Records and shared settings converge in both directions.
- [ ] Tombstones prevent deleted records from reappearing.
- [ ] Active session and device-specific settings never sync.
- [ ] Relaunch retains folder access; provider errors leave local use intact.
- [ ] No full URLs, page content, or secrets appear in snapshots.

### FB-007 — Verify system-wide blocking in Firefox/Arc if installed

- Status: BACKLOG
- Priority: P2
- Type: manual-verification
- Dependencies: FB-001, FB-005
- Owner: Product owner

**Scope:** If Firefox and/or Arc are installed, verify selected hostnames are blocked during a session and recover after session end. Record the known cached-DNS/connection behavior and hard-reload/browser-restart caveat. If neither is installed, record `NOT RUN` and close with that evidence.

**Acceptance criteria**

- [ ] New navigation in each installed browser hits the hosts-level block during a session.
- [ ] Access recovers after cleanup (subject to browser cache caveats).
- [ ] Findings are recorded without claiming friendly tab-redirect support.

### FB-008 — Verify Start at login

- Status: BACKLOG
- Priority: P2
- Type: manual-verification
- Dependencies: FB-001
- Owner: Product owner

**Scope:** Toggle **Start at login**, log out and back in, verify FocusBar relaunches as a menu-bar app; toggle off and verify it no longer launches. Confirm the Login Items state matches the setting.

**Acceptance criteria**

- [ ] Enabling registers the main app login item and survives logout/login.
- [ ] Disabling removes it.
- [ ] The setting matches System Settings → Login Items.
- [ ] The privileged helper is not registered or affected by this setting.

## Quality and hardening

### FB-009 — Accessibility and VoiceOver audit

- Status: BACKLOG
- Priority: P2
- Type: hardening
- Dependencies: FB-001
- Owner: OpenCode engineering agent + product owner for VoiceOver

**Scope:** Review the popover, session views, settings, history, and emergency stop for VoiceOver labels/hints, keyboard reachability, focus order, color contrast in light/dark mode, reduced motion, and text truncation at the fixed popover width. Fix clear, in-scope accessibility defects and add a manual verification note.

**Acceptance criteria**

- [ ] Every interactive control has an accessible name and useful hint.
- [ ] Timer/status changes are exposed without overwhelming announcements.
- [ ] Full keyboard navigation works; emergency stop is reachable.
- [ ] Light/dark contrast and non-color status cues are acceptable.
- [ ] Findings and any accepted limitations are recorded.

### FB-010 — Privileged helper security review

- Status: BACKLOG
- Priority: P0
- Type: security
- Dependencies: FB-001, FB-005
- Owner: OpenCode engineering agent

**Scope:** Re-review `FocusBarHelper`, `FocusBarShared/HostsBlocking.swift`, `HelperClientRequirement`, `SystemBlockingClient`, and the LaunchDaemon plist against `docs/THREAT_MODEL.md`. Verify caller code-signing validation, minimal XPC surface, hostname validation/expansion bounds, marker-scoped hosts editing, atomic writes/permission preservation, fail-open lease, and log hygiene. Add regression tests for any uncovered logic; do not weaken controls.

**Acceptance criteria**

- [ ] Every XPC entry point validates caller and input; no arbitrary paths/commands/hostnames.
- [ ] Hosts editing only touches the marked section and refuses malformed markers.
- [ ] Lease/heartbeat/cleanup logic has tests for expiry, stale launch, and removal.
- [ ] Logs contain no user content, secrets, or full URLs.
- [ ] Findings have severity, evidence, and a disposition; no control is weakened to pass a test.

## Backlog — captured, not scheduled

No additional tasks are captured. Add future work with `/factory-add-task`; do not insert speculative features directly here. `BACKLOG` tasks are not eligible for `/factory-next` until `/factory-plan` or the owner promotes them to `TODO`.

## Completed tasks

- **FB-001 — Verify the factory baseline** — DONE 2026-11-25. Factory validation PASS; Debug build PASS; 105 unit tests, 0 failures; signed UI smoke NOT RUN (no code-signing identity); no source/project/test changes. Evidence in the task block above and `.factory/WORK_LOG.md`.

Product milestones and their verification evidence live in `PLAN.md` §3 and §7.

## Task ID rules

- IDs are `FB-` plus a three-digit integer (`FB-001`).
- Never reuse or renumber an ID. Choose the next unused integer above the current highest.
- One task per `/factory-next` call.
- A task is `DONE` only when every acceptance criterion and required verification passed and the evidence is recorded.
