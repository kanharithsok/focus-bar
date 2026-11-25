# FocusBar — Quality and Testing

## Test layers

| Layer | Coverage | Command | Notes |
| --- | --- | --- | --- |
| Unit (XCTest) | Session state machine, timing, early end, review, intentions, captures, stats, hostname matching, hosts rendering/removal, helper lease/status logic, settings decoding, sync merge/tombstones | `xcodebuild ... test CODE_SIGNING_ALLOWED=NO` | Real `PersistenceController` pointed at temp directories; injectable clock; `automaticallyTicks: false` |
| UI smoke (XCUITest) | Menu-bar launch, popover, key idle controls, screenshot | Signed `FocusBarUITests` scheme | Requires a valid identity/team; cannot run with `CODE_SIGNING_ALLOWED=NO` |
| Helper/daemon | Real `SMAppService` registration, root daemon, XPC, `/etc/hosts` apply/remove, lease expiry, reboot cleanup | Manual signed build in `/Applications` | Cannot be proven by unit tests |
| Browser guard | Safari/Chrome Automation permission, active-tab redirect, failure behavior | Manual on a real desktop | `osascript`/TCC behavior is signature- and OS-dependent |
| System-wide blocking | Safari/Chrome/Brave/Zen (and Firefox/Arc if installed) name-resolution blocking, cache caveats, cleanup | Manual | Best effort; record browser versions and observed behavior |
| Sync | Two-Mac iCloud Drive propagation, deletions, settings, relaunch access, offline errors | Manual with two Macs | Unit tests cover merge/snapshot logic with temp folders |
| Accessibility | VoiceOver, keyboard, contrast, reduced motion | Manual + code review | Tracked as `FB-009` |

## Baseline commands

```sh
xcodegen generate   # only when project.yml or file membership changed

xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO

# Signed menu-bar/popover smoke test.
xcodebuild -project FocusBar.xcodeproj -scheme FocusBarUITests \
  -destination 'platform=macOS' test \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Do not invent commands, schemes, or flags. If a signing identity is unavailable, record `BLOCKED` or `NOT RUN`, not `PASS`.

## Determinism and test data

- Use real persistence pointed at unique temporary directories; never write tests into `~/Library/Application Support/FocusBar/`.
- Use the injectable clock and `automaticallyTicks: false` for session timing tests.
- Clean up temp directories. Do not delete user data, sync folders, or real `syncState.json`.
- Do not test against a real `/etc/hosts` in unit tests; use the file-manager seam with temp files.
- Use deterministic fakes for browser/AppleScript/helper boundaries. Do not require Safari/Chrome in unit tests.
- Test data must contain no real personal content, tokens, or hostnames tied to a person.

## What must be tested

**Session logic**
- Valid/invalid transitions; start/end/pause/resume/review.
- Absolute `endDate` after sleep/wake/relaunch-style clock jumps.
- Expired-session finalization while closed; 24-hour review window.
- Early-end reason, delay, Commit Mode, emergency stop.
- Scatterfocus modes and break blocking suspension.

**Persistence**
- Versioned envelope round trip; atomic replacement.
- Corrupt-file quarantine; newer-schema refusal; missing file defaults.
- No duplicate derived totals.

**Blocking**
- Hostname normalization and unrelated-domain rejection.
- App activation cooldown/dedup; hide vs quit-request decisions.
- Browser permission mapping (`-1743`, timeout, execution error), redirect failure leaves tab open.
- Blocked-attempt dedup and statistics derivation.

**Helper/hosts**
- Hostname validation/expansion bounds.
- Marker rendering/removal; malformed-marker refusal; unrelated content and permission preservation.
- Lease expiry, heartbeat, stale-launch cleanup, status transitions.
- XPC caller validation logic where testable.

**Sync**
- Snapshot round trips; two-device convergence.
- Merge rules for sessions/captures/intentions/skipped days/blocked attempts/shared settings.
- Tombstones survive re-import from an older snapshot.
- Corrupt/newer/oversized snapshot handling.
- Device-specific settings and active session never included.

## Definition of done

A task is done only when:

- acceptance criteria are met and checked off;
- targeted tests are added/updated and pass;
- the full unit suite and Debug build pass (or a genuine environment blocker is recorded);
- signed/UI/manual checks are recorded as `PASS`, `BLOCKED`, or `NOT RUN` with a reason;
- docs/state/work log are updated;
- every remaining issue has an `FB-`/`FU-`/release-gate disposition;
- no test, security control, or compiler rule was weakened to get green.

## Failure and flake policy

- Never delete a failing test, weaken an assertion, or skip a test to hide a regression.
- Fix the cause, or record a genuine environment blocker with exact evidence.
- A flaky test must be documented with the failing command and reproduction; stabilize it rather than ignoring it.
- `NOT RUN` is not `PASS`. A successful compile is not release evidence.
- Do not commit `build/`, `DerivedData/`, result bundles, screenshots containing personal data, or `.corrupt-*` files.

## Manual verification register

The authoritative register is `docs/FOLLOW_UPS.md`; task-level manual gates are `FB-002`–`FB-008` in `docs/ROADMAP.md`. Record each run with date, macOS version, build/signing class, and observed behavior. Do not include personal data, hostnames tied to a person, or team IDs.
