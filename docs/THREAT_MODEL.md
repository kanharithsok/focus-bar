# FocusBar — Threat Model

Scope: the native macOS app, its local data, the optional sync folder, and the privileged `FocusBarHelper` LaunchDaemon. This is a single-user, local-first product with no FocusBar servers or network calls.

## Assets

| Asset | Why it matters |
| --- | --- |
| Session history, focus objects, notes, captures, intentions | Personal attention/work content; sensitive by context |
| Blocked-attempt hostnames and bundle IDs | Reveals browsing/app behavior patterns |
| Sync snapshots in a user-selected folder | Aggregated personal data; may be uploaded by the folder provider |
| `/etc/hosts` integrity | A bug can break name resolution system-wide |
| Root helper process | Compromise or misuse yields root-level file access |
| TCC permissions (Automation, Notifications, folder access, Login Items) | Privacy-sensitive capabilities |
| Code-signing identity and helper registration | Trust boundary for privileged operations |
| User trust in blocking status | False "protected" claims create a false sense of security |

## Trust boundaries

1. **App → helper over XPC.** The app is unprivileged; the helper runs as root. Caller identity must be proven by code signing, and the message surface must stay minimal.
2. **App → browsers over Apple Events.** `osascript` is a subprocess; TCC attributes the Automation grant to the app/signature. Browser scripts return active-tab URLs and are an untrusted input boundary.
3. **App → sync folder.** Snapshots are plain JSON that may be edited, truncated, replaced, or synced from an older/newer device. Treat them as untrusted input.
4. **App → local filesystem.** Application Support JSON and corrupt-file quarantine; user-selected folder access via the standard picker.
5. **User → app.** The user can deny permissions, force-quit, delete the app, or remove the helper; the design must fail open and stay honest.
6. **Build → shipped artifact.** XcodeGen-generated project, SPM dependency resolution, code signing, and the embedded LaunchDaemon.

## Threat scenarios and mitigations

| # | Threat | Impact | Mitigation / expected behavior |
| --- | --- | --- | --- |
| T1 | Local process impersonates FocusBar and calls the helper | Arbitrary hosts modification as root | Helper validates the XPC client with a code-signing requirement; rejects unsigned/wrong-team clients. Never weaken for ad-hoc builds. |
| T2 | Malformed/hostile hostname reaches the helper | Injection, invalid hosts entries, resolution breakage | Validate/normalize hostnames; bound count/length; expand only known common subdomains; reject empty, path, whitespace, wildcard, or non-host input. |
| T3 | Helper overwrites unrelated `/etc/hosts` content | System-wide name-resolution damage | Only remove/append the marked section; refuse malformed markers; atomic write; preserve mode; tests for round trips. |
| T4 | Crash/force-quit leaves a permanent block | User loses connectivity until manual repair | Fail-open lease (30 s) with heartbeat (8 s); cleanup on expire, helper launch, SIGTERM/unregister, reboot; manual force-quit/reboot verification is required. |
| T5 | Malicious or corrupted sync snapshot | Data injection, crash, data loss, downgrade | Decode defensively; skip unreadable/newer-schema files with a warning; never overwrite a newer local snapshot; merge by UUID with deterministic timestamps; cap snapshot size; never write another device's file. |
| T6 | Snapshot overwrite/clobber between Macs | Lost history | One file per device UUID; `NSFileCoordinator` + atomic writes; merge-only imports; tombstones. |
| T7 | Deleted records reappear | Privacy/trust | Tombstones in local `syncState.json`, included in snapshots. |
| T8 | Full URLs, page content, or full file paths leak into persistence/logs/snapshots | Privacy exposure | Store hostname-level blocked attempts only; generic blocked page; no user text in URLs; privacy-aware `Logger` annotations; no telemetry. |
| T9 | Malicious webpage or browser response manipulates AppleScript | App control-flow or data exposure | Static scripts, extracted URL treated as untrusted, hostname normalization, no `do shell script` with page content, no `eval`, off-main execution with timeout. |
| T10 | Automation permission denied/revoked | Blocking silently fails | Detect denial (`-1743`), surface honest status, never claim protection is active, never crash. |
| T11 | App is force-quit | App hiding/tab guard stops; hosts block lingers | Documented limitation; helper lease removes hosts; UI/README stay honest about best-effort behavior. |
| T12 | Helper deleted/unregistered while app still runs | System blocking unavailable | Status reports unavailable; no crash; user can re-register. |
| T13 | App deleted while helper remains registered | Stale root daemon | Helper lease clears the block; user removes the background item; docs explain **Remove helper**. The app cannot clean up after deletion. |
| T14 | Dependency compromise or telemetry | Supply-chain/privacy risk | Only `KeyboardShortcuts` is approved; review provenance/license; no analytics/network SDKs; SPM pin in `Package.resolved`. |
| T15 | Ad-hoc/unsigned Debug build tries to use the helper | False failure or weakened security | UI detects ad-hoc signing and explains the requirement; helper remains strict. |
| T16 | Logs or crash reports expose personal content | Privacy exposure | Unified logging with privacy annotations; no third-party crash upload; never log focus/capture text, full URLs, folder paths, or signing identities. |
| T17 | User misunderstands hosts blocking as guaranteed | Security/trust harm | UI/README disclose VPN, DoH, cached DNS, cached pages, IP literals, no wildcards, and browser cache behavior. |

## Out of scope / accepted residual risks

- A local attacker with the user's account can read local JSON files and the sync folder. FocusBar does not encrypt app data at rest and does not claim to.
- Sync snapshots are not end-to-end encrypted; the folder provider's protections apply.
- `/etc/hosts` blocking is bypassable (VPN, encrypted DNS, cached DNS/connections, IP literals, apps that ignore hosts). It is best effort.
- Cached browser pages/connections may survive a hosts change until reload/restart; FocusBar does not delete browser profile/cache data.
- The app is not sandboxed in v1 because Apple Events and app-bundle inspection require broader access. It is distributed outside the App Store.
- No notarization/release automation in v1; the Homebrew cask uses a development-signed build.
- macOS/TCC behavior can vary by signature and OS version; permission attribution must be verified manually on a signed build.

## Review triggers

Re-review this model when any of the following changes:

- XPC protocol, helper registration, or code-signing requirement;
- `/etc/hosts` rendering/removal, hostname expansion, or lease logic;
- new TCC permission, entitlement, LaunchDaemon, or Network Extension;
- sync snapshot schema/merge/tombstone behavior;
- persistence schema or data-retention behavior;
- a new third-party dependency or any network code;
- release/signing/distribution changes.

Security-sensitive changes must load the `security-review`, `privileged-helper-security`, `macos-permissions`, and/or `privacy-data-lifecycle` skills as relevant.
