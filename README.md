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

## Features (v1, M1–M5)

- Menu-bar-only app (`LSUIElement`) with a compact popover.
- Optional **Start at login** via macOS Login Items, using `SMAppService`; no helper or login-item daemon.
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
- Statistics derived from saved session history: today/week focus minutes, 7-day chart, average focus quality, blocked-attempt counts, and full session history.
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
- FocusBar does **not** use Screen Recording, Accessibility, Full Disk Access, a privileged helper, or `/etc/hosts`.

## Privacy

- Data lives in `~/Library/Application Support/FocusBar/`.
- Session history, captures, intentions, settings, and blocked-attempt history are JSON files with a versioned envelope and atomic writes.
- Browser checks inspect only the active tab's URL. FocusBar stores only the hostname, browser identifier, session ID, and timestamp for a blocked attempt. It does not store full URLs, paths, query strings, or page content.
- The focus object is never placed in a URL or browser history. The blocked page is generic and local.
- No network code, accounts, analytics, telemetry, or cloud sync.

## Blocking limitations

Blocking is **best effort**, never guaranteed:

- App blocking runs inside FocusBar. If FocusBar is force-quit, blocking stops.
- `NSRunningApplication.terminate()` is a normal quit request; apps can refuse. FocusBar never force-terminates.
- Browser protection is an active-tab guard for **Safari and Google Chrome only**. Background tabs are not continuously inspected, and fast navigations between polls can be missed.
- Browser automation requires permission and a responsive browser. Failures are surfaced; tabs are never closed because a redirect failed.
- Other browsers (Arc, Brave, Edge, Firefox) are intentionally not supported until individually verified.
- System-wide hosts-file blocking (M6) is **not implemented** and would require explicit approval, a privileged helper, and fail-open lease handling. It is also bypassable by VPNs/encrypted DNS.

## Data recovery

If a JSON file is unreadable, FocusBar moves it aside as `filename.corrupt-<timestamp>` and continues with an empty/default value. The app shows a warning rather than silently discarding data. Newer schema versions are left untouched and reported.

## Development

- `project.yml` is the source of truth. `FocusBar.xcodeproj` is generated by XcodeGen. Do not hand-edit `project.pbxproj`.
- Architecture: SwiftUI views → `AppModel` / `@Observable` stores → services (`SessionManager`, `BlockingEngine`, `CaptureStore`, `StatsStore`, `IntentionStore`, `SettingsStore`, `BlockedAttemptStore`).
- Persistence: `PersistenceController` actor, versioned JSON, atomic writes.
- The only third-party dependency is `KeyboardShortcuts` 1.17.x.
- Tests use real persistence in temporary directories and an injectable clock; run the `xcodebuild test` command above.
- Agent guidance: `AGENTS.md` is the canonical, auto-loaded OpenCode instruction file. `CLAUDE.md` is a symlink to it for Claude Code compatibility. `PLAN.md` is the live roadmap; read it for milestone status.

### Manual verification still required

These cannot be fully validated by the automated test suite:

1. Launch and inspect the menu-bar-only behavior and popover layout.
2. Grant Automation permission and verify Safari and Chrome active-tab redirects on a real desktop.
3. Verify app hide / normal-quit-request behavior with selected applications.
4. Verify the global capture shortcut and panel focus feel.
5. Confirm notifications appear (or are gracefully denied).
6. Toggle **Start at login** and verify FocusBar relaunches after logging out and back in.

## Not in v1

- iOS/iPadOS companion, iCloud sync, accounts, App Store distribution, notarization/release automation.
- Firefox tab integration.
- AI features.
- System-wide hosts-file blocking or privileged helper installation.
- Optional macOS Focus/Shortcuts integration (`Hyperfocus On` / `Hyperfocus Off`) is not implemented in this build.

## License

MIT — see [LICENSE](LICENSE).
