---
name: dependency-management
description: Use when adding, removing, upgrading, or approving a runtime or build dependency, SPM resolution, XcodeGen setting, or third-party package.
---

# Dependency Management

The approved inventory is in `docs/DEPENDENCIES.md`. This skill is the approval procedure.

## Before adding

1. State the concrete problem and why Apple frameworks, existing code, or a small local implementation cannot solve it.
2. Search the repository for an existing equivalent. Do not add duplicate UI kits, shortcut managers, persistence wrappers, networking, logging, or analytics.
3. Check maintenance, release cadence, license, transitive size, macOS 14 compatibility, sandbox/entitlement impact, and whether the package networks, phones home, or includes native code.
4. Treat a new privileged helper, LaunchDaemon, Network Extension, or signing dependency as an owner decision, not a routine package change.
5. `KeyboardShortcuts` is the only approved runtime dependency. Do not add another without explicit owner approval.

## Change procedure

- Add the exact version/revision to `project.yml`; never hand-edit `project.pbxproj`.
- Run `xcodegen generate` and inspect the generated project diff.
- Preserve/review `FocusBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- Run `xcodebuild -resolvePackageDependencies`, the Debug build, and the full unit suite.
- Review license/notices and user-visible docs.
- Update `docs/DEPENDENCIES.md` and `docs/DECISIONS.md` for material changes.
- For signing/helper changes, run the signed manual checks.

## Policy

- No floating branches, unverified binaries, or automatic update mechanisms.
- No analytics, telemetry, crash-reporting, account, ad-network, or hidden network SDKs.
- Do not add a dependency solely to avoid writing a few lines of local code.
- Do not disable signing, hardened runtime, or SPM verification to work around a download/build issue.
- A security patch may move within the approved major version when builds/tests pass; a new architectural dependency needs an owner decision.
- Record `NOT RUN` honestly when a check cannot run.

## Verification

```sh
xcodegen generate
xcodebuild -resolvePackageDependencies -project FocusBar.xcodeproj -scheme FocusBar
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Inspect the `project.pbxproj` diff after regeneration; it should reflect only the intended change. Never commit generated build artifacts or `DerivedData/`.
