# FocusBar

FocusBar is a native macOS menu-bar app for managing attention through two modes inspired by Chris Bailey's *Hyperfocus*:

- **Hyperfocus** — one specific focus object, a fixed time block, and best-effort distraction blocking.
- **Scatterfocus** — an intentional break for capturing thoughts, crunching a problem, or doing something low-demand so the mind can wander.

FocusBar is local-first. There are no accounts, analytics, telemetry, servers, or app-initiated network calls. Everything is stored on your Mac unless you explicitly enable the optional multi-Mac sync through a folder you choose, such as one in iCloud Drive.

## Requirements

- macOS 14.0 or later
- Apple Silicon (the project builds arm64; universal builds are possible)
- Xcode 16 or later to build (verified with Xcode 27.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ only if you want to regenerate the Xcode project
- Optional multi-Mac sync: iCloud Drive (or another synced folder) and the same Apple Account on both Macs. No paid Apple Developer Program membership is needed for folder-based sync.

## Features (v1, M1–M7)

- Menu-bar-only app (`LSUIElement`) with a compact popover.
- Optional **Start at login** via macOS Login Items, using `SMAppService`. The system-wide blocking helper is a separate opt-in component.
- Hyperfocus sessions: 25, 50, 90 minutes, or a custom duration; one specific focus object; optional daily-intention link.
- Absolute end-date timer: sleep, wake, and relaunch are handled by recomputing from the saved end time.
- Explicit session state machine with invalid-transition rejection.
- Early end: a required one-line reason, plus an optional configurable pause (default: none) before the session can be ended.
- Optional **Commit Mode**: hides the normal early-end action; an emergency stop remains available and is recorded as an emergency stop. FocusBar never claims it can prevent force quitting or restarting macOS.
- Session review: optional 1–5 focus-quality rating, optional note, and review of captured distractions.
- Daily intentions: up to three per day, optional, skippable, and linkable to a Hyperfocus session.
- Scatterfocus: 10-minute default, Capture / Problem crunching / Habitual modes. Habitual intentionally has no scratchpad.
- Break blocking: social-media blocking stays on by default during breaks; each break can explicitly suspend blocking.
- Global distraction capture with `⌃⌥Space` (configurable in Settings), using the approved `KeyboardShortcuts` package. Captures are associated with the active session when there is one.
- Editable blocklist presets: X/Twitter, Facebook, Instagram, TikTok, Reddit, LinkedIn, Snapchat, Threads, and YouTube (YouTube off by default). Installed apps can be added by resolving their bundle identifiers.
- Best-effort app blocking via `NSWorkspace` launch/activation notifications. Hide is the default; a normal quit request is optional. FocusBar never force-quits.
- Best-effort Safari and Google Chrome active-tab guard: immediate check on browser activation, then about once per second while a supported browser is foreground. Blocked tabs are redirected to a bundled local page.
- Opt-in **system-wide website blocking** (M6): a signed background helper adds a marked section to `/etc/hosts` while a focus session is active, so the listed hostnames are blocked in all browsers and apps, not just Safari and Chrome. The helper holds a fail-open 30-second lease; if FocusBar stops, it removes the block. It only ever touches FocusBar's own marked section.
- Optional **Zen/Firefox restart** at session start and end: clears those browsers' cached DNS and connections so the system-wide block takes effect immediately and stale blocked pages clear afterward. FocusBar only sends a normal quit request and reopens the browser; tabs may not restore, so save your work first.
- Statistics derived from saved session history: today/week focus minutes, 7-day chart, average focus quality, blocked-attempt counts, and session history grouped by day. Select a session to see its full notes, intentions, and captures.
- Corrupt or missing JSON is handled gracefully; corrupt files are quarantined, not silently overwritten.
- Optional **multi-Mac sync** through a folder you choose, such as `iCloud Drive/FocusBar`. Each Mac writes its own small JSON snapshot; sessions, captures, intentions, blocked-attempt history, and shared settings merge automatically. Active sessions and device-specific settings stay local. No FocusBar account or server is involved.

## Install and run

### Homebrew

```sh
brew tap kanharithsok/tap
brew trust kanharithsok/tap
brew install --cask focusbar
```

The cask removes the download quarantine flag for this development-signed build. After installing, open FocusBar and enable **Settings → System-wide website blocking** if you want the `/etc/hosts` helper; macOS may ask you to approve it under Login Items & Extensions.

Before uninstalling with Homebrew, use **Settings → System-wide website blocking → Remove helper**. Homebrew uninstalling the app does not automatically remove the background helper registration; see [Uninstalling](#uninstalling).

### Xcode

1. Open `FocusBar.xcodeproj`.
2. Select the `FocusBar` scheme and **My Mac**.
3. Build and run.
4. Look for the FocusBar icon in the menu bar. The app does not appear in the Dock.

### Command line

```sh
xcodegen generate   # only needed after changing project.yml or adding files
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Debug \
  -destination 'platform=macOS' build
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar \
  -destination 'platform=macOS' test
```

The project is set up for ad-hoc local signing. If macOS keeps re-prompting for Automation permission or sync-folder access after rebuilds, sign with a stable local Development identity instead of changing ad-hoc signatures.

System-wide website blocking is the one exception: the embedded LaunchDaemon must be signed with the same team as the app and the app must live in `/Applications` for `SMAppService` to register it. For local use, sign with your Apple Development or Developer ID identity:

```sh
xcodebuild -project FocusBar.xcodeproj -scheme FocusBar -configuration Release \
  -destination 'platform=macOS' build \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Then move the built `FocusBar.app` to `/Applications`, open it, and enable **Settings → System-wide website blocking**. The same build command with `CODE_SIGNING_ALLOWED=NO` is still fine for the unit-test suite, which does not exercise the daemon.

Running the Xcode Debug build with the project's default ad-hoc signing cannot use system-wide blocking: the helper intentionally rejects unsigned clients. The app shows a setup warning in that case. Use the signed `/Applications` build, or sign the Debug build with your Apple Development team, when testing this feature.

## Usage

### Hyperfocus

1. Click the FocusBar menu-bar icon.
2. Choose **Hyperfocus**.
3. Enter one specific focus object.
4. Pick 25 / 50 / 90 minutes or a custom duration.
5. Optionally link one of today's intentions.
6. Start.

The focus object and remaining time stay visible in the popover, and the menu bar shows the remaining time.

### Ending early / Commit Mode

- Default: **End early…** asks for a one-line reason, then ends immediately.
- **Settings → Session → Early-end delay** can add an optional 5–30 second pause before **End Session** unlocks.
- Commit Mode: the normal early-end button is hidden. **Emergency stop…** is still available from the session view and the app's **Session** menu. It is recorded as an emergency stop.
- FocusBar cannot stop you from force quitting the app or restarting the Mac.

### Scatterfocus

Choose **Scatterfocus** in the popover, pick Capture / Problem crunching / Habitual, set a length (10 minutes by default), and start. Habitual deliberately provides no scratchpad. Blocking continues by default; use **Keep blocking during this break** to suspend it explicitly for that break.

### Capturing distractions

Press `⌃⌥Space` (default) anywhere. Type one line and press Return. The capture is saved locally and associated with the active session when one exists. Change the shortcut in **Settings → Global shortcut**.

### Syncing across Macs (optional)

1. Make sure iCloud Drive is enabled on both Macs and both are signed into the same Apple Account.
2. Open **Settings → Sync across Macs**.
3. Turn on **Sync through a shared folder** and choose or create `iCloud Drive/FocusBar`.
4. On the second Mac, do the same and choose the same folder.

FocusBar writes one small JSON snapshot per Mac into the folder. Each Mac reads the other snapshots, merges records by their UUID, and writes its own snapshot. The two Macs never write the same file, so one Mac cannot overwrite the other's history.

- **Synced:** session history and reviews, captures, daily intentions, blocked-attempt history, blocklist presets, and shared session/blocking preferences.
- **Not synced:** the active session, the system-wide helper toggle, the Zen/Firefox restart setting, notification permission, start-at-login, and the sync folder configuration itself.
- **Deletions:** deleting a capture or intention records a tombstone, so it does not reappear from the other Mac.
- **Conflicts:** if the same session review or shared setting changes on both Macs before they sync, the newest timestamp wins. FocusBar does not show a merge/conflict dialog.
- **Scheduling:** FocusBar syncs at launch, after local changes (debounced), when the app becomes active or wakes, and about once a minute while running.

Sync is eventually consistent. iCloud Drive may take a few seconds or minutes, and a Mac that is offline keeps its local data and catches up later. If iCloud storage is full or iCloud Drive is disabled, local use continues and the sync error is shown in Settings. The snapshots count against your existing iCloud storage; FocusBar data is only a few megabytes, so the free 5 GB is normally enough.

This is folder-based sync, not CloudKit. It works with a free Apple Developer account and any synced folder. True CloudKit/iCloud-container sync would require the paid Apple Developer Program.

## Permissions

- **Automation (Apple Events)** is needed only when browser protection inspects Safari or Chrome's active tab. FocusBar explains this before asking. If denied, enable FocusBar under **System Settings → Privacy & Security → Automation**. Denial never crashes the app or pretends protection is working.
- **Notifications** are optional. FocusBar asks the first time a session starts if notifications are enabled. Blocking works without them.
- App hiding uses `NSWorkspace` and needs no special permission.
- **Optional sync** asks you to choose the folder with the standard macOS folder picker. macOS may ask you to confirm access to that folder. FocusBar does not need Full Disk Access.
- **System-wide website blocking** installs a signed LaunchDaemon through `SMAppService`; macOS may ask you to approve it under **System Settings → General → Login Items & Extensions**. The helper runs as root only to update the marked `/etc/hosts` section and flush DNS. It does not use Full Disk Access, Accessibility, or Screen Recording.
- FocusBar does **not** use Screen Recording, Accessibility, or Full Disk Access.

## Privacy

- Data lives in `~/Library/Application Support/FocusBar/`. If you enable sync, the shared snapshots live only in the folder you choose.
- Session history, captures, intentions, settings, blocked-attempt history, and sync bookkeeping are JSON files with a versioned envelope and atomic writes.
- Browser checks inspect only the active tab's URL. FocusBar stores only the hostname, browser identifier, session ID, and timestamp for a blocked attempt. It does not store full URLs, paths, query strings, or page content.
- The focus object is never placed in a URL or browser history. The blocked page is generic and local.
- The system-wide helper only writes the hostnames already in your selected preset. It does not read page content, browse history, or inspect network traffic.
- **Optional sync:** no FocusBar account, server, analytics, telemetry, or app-initiated network request is involved. If you enable sync, FocusBar writes the JSON snapshots described above into the folder you chose. Your folder provider (for example iCloud Drive) uploads them under its own terms. The snapshots include session text, captures, intentions, shared settings, blocked hostnames, and bundle IDs. They are not end-to-end encrypted by FocusBar; use a provider or iCloud Advanced Data Protection if you need that.
- Without sync enabled, the sync code does nothing and no data leaves your Mac.

## Blocking limitations

Blocking is **best effort**, never guaranteed:

- App blocking runs inside FocusBar. If FocusBar is force-quit, app hiding and the Safari/Chrome tab guard stop. The system-wide hosts block remains only until its 30-second lease expires, then the helper removes it.
- `NSRunningApplication.terminate()` is a normal quit request; apps can refuse. FocusBar never force-terminates.
- Browser protection is an active-tab guard for **Safari and Google Chrome only**. Background tabs are not continuously inspected, and fast navigations between polls can be missed.
- Browser automation requires permission and a responsive browser. Failures are surfaced; tabs are never closed because a redirect failed.
- Other browsers (Arc, Brave, Edge, Firefox) are not supported by the friendly active-tab guard, but the opt-in system-wide hosts block applies to them at the system resolution level.
- `/etc/hosts` cannot express wildcards. FocusBar explicitly lists the selected hostnames plus common subdomains (`www.`, `m.`, `mobile.`, and selected service-specific hosts), but an uncommon subdomain can still slip through.
- System-wide blocking is bypassable by VPNs, encrypted DNS/DoH, cached DNS, IP-literal URLs, and apps that ignore the system hosts file. It also cannot count blocked attempts or show the FocusBar page for HTTPS; other browsers will typically show a connection error.
- An already-open page, cached DNS, or a reused HTTP connection can keep working after a session starts. This is especially visible in Firefox-based browsers such as Zen: a new tab in an existing window can still load YouTube from cached DNS/connections, while a private window or hard reload (`⌘⇧R`) shows the block. Reload, restart the browser, or use a private window to force a new connection. After a session ends, the same cache can keep an error page or loopback result until a hard reload or browser restart. The optional Zen/Firefox restart handles the DNS/connection part automatically, but a cached offline page/shell may still remain until reloaded.
- Restarting a browser does not clear its persistent HTTP cache, service workers, or offline site data. A hard reload may still be needed to replace a cached offline page with the connection error; FocusBar does not delete browser profile data.
- Hosts blocking is not a network extension or a guarantee of enforcement.

## Uninstalling

1. Open **Settings → System-wide website blocking → Remove helper**.
2. Quit FocusBar and move it to the Trash.

If FocusBar was already deleted, remove its background item under **System Settings → General → Login Items & Extensions**. The helper never leaves a permanent `/etc/hosts` block: if it loses the app, the lease expires after 30 seconds and clears the marked section; a clean helper unregister also removes it immediately. A browser may still show a cached offline/error page until it is reloaded or restarted.

Uninstalling FocusBar does not delete the optional sync folder. If you enabled sync and want to remove the synced copies, delete the shared `FocusBar` folder (for example in iCloud Drive) after removing the app. Other Macs keep their local data.

If you move FocusBar after installing the helper, choose **Remove helper** and then **Install helper** again so the LaunchDaemon points at the new app location.

## Data recovery

If a JSON file is unreadable, FocusBar moves it aside as `filename.corrupt-<timestamp>` and continues with an empty/default value. The app shows a warning rather than silently discarding data. Newer schema versions are left untouched and reported.

## Development

- `project.yml` is the source of truth. `FocusBar.xcodeproj` is generated by XcodeGen. Do not hand-edit `project.pbxproj`.
- Architecture: SwiftUI views → `AppModel` / `@Observable` stores → services (`SessionManager`, `BlockingEngine`, `SystemBlockingService` / `SystemBlockingClient`, `SyncCoordinator`, `FolderSyncEngine`, `SyncMerge`, `MozillaBrowserRestarter`, `CaptureStore`, `StatsStore`, `IntentionStore`, `SettingsStore`, `BlockedAttemptStore`). The privileged side is the separate `FocusBarHelper` target.
- Persistence: `PersistenceController` actor, versioned JSON, atomic writes.
- Sync: each Mac writes only its own `devices/device-<UUID>.json` snapshot in the chosen folder; `SyncMerge` unions records by UUID and resolves same-record edits by timestamp. `syncState.json` holds the local device ID and deletion tombstones.
- The only third-party dependency is `KeyboardShortcuts` 1.17.x.
- Tests use real persistence in temporary directories and an injectable clock; hosts rendering/validation, blocking-plan/system-blocking settings, sync merge rules, snapshot round trips, and two-device convergence are covered. Run the `xcodebuild test` command above.
- Agent guidance: `AGENTS.md` is the canonical, auto-loaded OpenCode instruction file. `CLAUDE.md` is a symlink to it for Claude Code compatibility. `PLAN.md` is the live roadmap; read it for milestone status.

### UI smoke test

`FocusBarUITests` launches the app with a temporary data directory, clicks the menu-bar item, checks the idle popover's key controls, and attaches a screenshot to the test result. It needs a signed Debug build:

```sh
xcodebuild -project FocusBar.xcodeproj -scheme FocusBarUITests \
  -destination 'platform=macOS' test \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

### Manual verification still required

These cannot be fully validated by the automated test suite:

1. Launch and inspect the menu-bar-only behavior and popover layout.
2. Grant Automation permission and verify Safari and Chrome active-tab redirects on a real desktop.
3. Verify app hide / normal-quit-request behavior with selected applications.
4. Verify the global capture shortcut and panel focus feel.
5. Confirm notifications appear (or are gracefully denied).
6. Toggle **Start at login** and verify FocusBar relaunches after logging out and back in.
7. Approve the system helper, verify the marked `/etc/hosts` section appears during a session, and verify it is removed on session end, after a force-quit lease expiry, and after a helper reinstall/reboot.
8. Verify system-wide blocking in Safari, Chrome, Brave, and Zen; verify Firefox/Arc if installed; then check that enabling/disabling the setting mid-session updates the hosts section.
9. On two Macs signed into the same iCloud account, choose the same iCloud Drive folder, verify history/captures/intentions/settings/blocked attempts arrive, confirm a deleted capture does not return, and confirm the active session and system-helper toggle stay local. Re-launch both apps and verify the folder remains accessible.

## Not in v1

- iOS/iPadOS companion, CloudKit/app-container iCloud sync, accounts, App Store distribution, notarization/release automation. Optional folder-based multi-Mac sync is available.
- Firefox/Arc/Edge friendly tab-redirect integration (system-wide hosts blocking covers them, but without a custom blocked page).
- AI features.
- Network Extension content filtering, per-app network rules, wildcard domain blocking, or attempt telemetry for system-wide blocks.
- Optional macOS Focus/Shortcuts integration (`Hyperfocus On` / `Hyperfocus Off`) is not implemented in this build.

## License

MIT — see [LICENSE](LICENSE).
