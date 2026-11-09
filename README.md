# FocusBar

FocusBar is a native macOS menu-bar app for managing attention through two modes inspired by Chris Bailey's *Hyperfocus*:

- **Hyperfocus** — one specific focus object, a fixed time block, and best-effort distraction blocking.
- **Scatterfocus** — an intentional break for capturing thoughts, crunching a problem, or doing something low-demand so the mind can wander.

FocusBar is local-first. There are no accounts, analytics, telemetry, cloud sync, or network calls. Everything is stored on your Mac.

## Requirements

- macOS 14.0 or later
- Apple Silicon (the project builds arm64; universal builds are possible)
- Xcode 16 or later to build (verified with Xcode 27.2)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ only if you want to regenerate the Xcode project

## Features (v1, M1–M6)

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

## Install and run

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

The project is set up for ad-hoc local signing. If macOS keeps re-prompting for Automation permission after rebuilds, sign with a stable local Development identity instead of changing ad-hoc signatures.

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

## Permissions

- **Automation (Apple Events)** is needed only when browser protection inspects Safari or Chrome's active tab. FocusBar explains this before asking. If denied, enable FocusBar under **System Settings → Privacy & Security → Automation**. Denial never crashes the app or pretends protection is working.
- **Notifications** are optional. FocusBar asks the first time a session starts if notifications are enabled. Blocking works without them.
- App hiding uses `NSWorkspace` and needs no special permission.
- **System-wide website blocking** installs a signed LaunchDaemon through `SMAppService`; macOS may ask you to approve it under **System Settings → General → Login Items & Extensions**. The helper runs as root only to update the marked `/etc/hosts` section and flush DNS. It does not use Full Disk Access, Accessibility, or Screen Recording.
- FocusBar does **not** use Screen Recording, Accessibility, or Full Disk Access.

## Privacy

- Data lives in `~/Library/Application Support/FocusBar/`.
- Session history, captures, intentions, settings, and blocked-attempt history are JSON files with a versioned envelope and atomic writes.
- Browser checks inspect only the active tab's URL. FocusBar stores only the hostname, browser identifier, session ID, and timestamp for a blocked attempt. It does not store full URLs, paths, query strings, or page content.
- The focus object is never placed in a URL or browser history. The blocked page is generic and local.
- The system-wide helper only writes the hostnames already in your selected preset. It does not read page content, browse history, or inspect network traffic.
- No network code, accounts, analytics, telemetry, or cloud sync.

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

If you move FocusBar after installing the helper, choose **Remove helper** and then **Install helper** again so the LaunchDaemon points at the new app location.

## Data recovery

If a JSON file is unreadable, FocusBar moves it aside as `filename.corrupt-<timestamp>` and continues with an empty/default value. The app shows a warning rather than silently discarding data. Newer schema versions are left untouched and reported.

## Development

- `project.yml` is the source of truth. `FocusBar.xcodeproj` is generated by XcodeGen. Do not hand-edit `project.pbxproj`.
- Architecture: SwiftUI views → `AppModel` / `@Observable` stores → services (`SessionManager`, `BlockingEngine`, `SystemBlockingService` / `SystemBlockingClient`, `MozillaBrowserRestarter`, `CaptureStore`, `StatsStore`, `IntentionStore`, `SettingsStore`, `BlockedAttemptStore`). The privileged side is the separate `FocusBarHelper` target.
- Persistence: `PersistenceController` actor, versioned JSON, atomic writes.
- The only third-party dependency is `KeyboardShortcuts` 1.17.x.
- Tests use real persistence in temporary directories and an injectable clock; hosts rendering/validation and blocking-plan/system-blocking settings are covered. Run the `xcodebuild test` command above.
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

## Not in v1

- iOS/iPadOS companion, iCloud sync, accounts, App Store distribution, notarization/release automation.
- Firefox/Arc/Edge friendly tab-redirect integration (system-wide hosts blocking covers them, but without a custom blocked page).
- AI features.
- Network Extension content filtering, per-app network rules, wildcard domain blocking, or attempt telemetry for system-wide blocks.
- Optional macOS Focus/Shortcuts integration (`Hyperfocus On` / `Hyperfocus Off`) is not implemented in this build.

## License

MIT — see [LICENSE](LICENSE).
