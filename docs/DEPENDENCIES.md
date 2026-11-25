# FocusBar — Dependencies

## Current inventory

| Dependency | Version | Type | Purpose | Approval |
| --- | --- | --- | --- | --- |
| `KeyboardShortcuts` (`sindresorhus/KeyboardShortcuts`) | 1.17.0 (SPM resolved revision `ac12762853126cf2e7ad63a6a58e1c9f58c6a0ee`) | Runtime | Global `⌃⌥Space` capture shortcut | Approved; the only third-party runtime dependency |
| XcodeGen | 2.48.0 in the verified environment (2.46+ documented) | Development tool | Generates `FocusBar.xcodeproj` from `project.yml` | Approved development tool; not shipped |
| Xcode / Swift toolchain | Xcode 27.2 (27B52), Swift 6.4.2 compiler, Swift 5 language mode | Platform toolchain | Build/test | Environment, not a project dependency |
| macOS SDK | Deployment target 14.0 | Platform | Supported OS | Product requirement |

System frameworks (SwiftUI, AppKit, Foundation, OSLog, ServiceManagement, Security, etc.) are part of macOS and are not third-party dependencies.

`FocusBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` pins the SPM resolution. Preserve and review it.

## Policy

1. **No new runtime dependency without explicit owner approval.** State the concrete problem, why Apple frameworks or a small local implementation cannot solve it, maintenance/license/provenance, transitive size, macOS 14 compatibility, and privacy/security impact.
2. **No analytics, telemetry, crash-reporting, networking, account, UI-kit, or privileged-helper libraries.** FocusBar is local-first and deliberately small.
3. **No duplicate capability.** Check whether an existing service, Apple framework, or a few lines of local code already solve the problem.
4. **Pin it.** Declare an explicit version/revision in `project.yml` (currently `from: 1.17.0`), keep the resolved commit in `Package.resolved`, and review any resolution change. Do not use floating branches or unverified binary blobs.
5. **No new privileged component** (LaunchDaemon, Network Extension, helper tool) without explicit owner approval and a security review.
6. **XcodeGen remains the project source of truth.** Add files/settings in `project.yml`; never hand-edit `project.pbxproj`.
7. **No App Store-only or paid-account-required dependency** unless the owner has approved the distribution change.

## Adding or upgrading a dependency

1. Record the proposal and owner approval in `docs/DECISIONS.md` or the task file.
2. Update `project.yml` with an explicit version/revision and keep `Package.resolved` aligned.
3. Run `xcodegen generate` and inspect the generated project diff (`*.pbxproj` must only reflect the intended change).
4. Resolve and inspect `Package.resolved`.
5. Build and test:

```sh
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

6. Review license/notices, privacy impact, and whether the package phones home or links network code.
7. Update this file, `README.md` if user-visible, and `PLAN.md`/`docs/DECISIONS.md` for material changes.
8. For signing/helper-sensitive changes, run the signed manual checks.

## Verification and scanning

There is no package-manager audit equivalent for this app. Use:

- `xcodebuild -resolvePackageDependencies` to confirm resolution.
- `Package.resolved` review for unexpected revisions.
- `git diff` review of `project.pbxproj` after `xcodegen generate`.
- Xcode's dependency/provenance review and license inspection.
- `git diff --check` and a secret scan before commit (use an approved local scanner; do not add a runtime dependency for it).
- Manual network inspection if a dependency is suspected of networking; FocusBar should have no app-initiated network traffic.

Record `NOT RUN` honestly when a scanner or signed check cannot run.

## Current boundaries

- System-wide blocking is implemented with the system `SMAppService`/hosts mechanism, not a third-party helper library or Network Extension.
- Folder-based sync is implemented with Foundation/`NSFileCoordinator`; CloudKit is not used because the project's free Personal Team cannot use iCloud entitlements.
- No notarization automation or release pipeline is present in v1.
