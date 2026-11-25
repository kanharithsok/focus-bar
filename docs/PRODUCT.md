# FocusBar — Product

## What it is

FocusBar is a native macOS menu-bar app for managing attention through two modes inspired by Chris Bailey's *Hyperfocus*:

- **Hyperfocus** — one specific focus object, a fixed time block, and best-effort distraction blocking.
- **Scatterfocus** — an intentional break for capturing thoughts, crunching a problem, or doing something low-demand.

The app is local-first and single-user. There are no accounts, FocusBar servers, analytics, telemetry, or app-initiated network calls. Everything stays on the Mac unless the user explicitly enables optional multi-Mac sync through a folder they choose, such as a folder in iCloud Drive.

## Target user

A Mac user who wants a lightweight, calm attention tool without a productivity dashboard, social features, or cloud account. The app lives in the menu bar, not the Dock.

## Core loop

1. Choose Hyperfocus or Scatterfocus.
2. Optionally link one of up to three daily intentions.
3. Start a session with an absolute end time.
4. Work while FocusBar makes a best-effort attempt to hide selected apps and redirect Safari/Chrome away from selected sites; an opt-in system-wide hosts block extends this to other browsers and apps.
5. End early with a reason, or complete the session and optionally rate focus and review captured distractions.
6. Review derived statistics and session history.

## Product surface (v1, M1–M7)

- Menu-bar-only UI with a compact popover.
- Hyperfocus sessions of 25/50/90 minutes or a custom duration; one focus object.
- Optional Commit Mode with an emergency stop that is recorded honestly.
- Session review with an optional 1–5 focus rating and note.
- Daily intentions (maximum three, optional, skippable).
- Scatterfocus modes: Capture, Problem crunching, Habitual. Habitual intentionally has no scratchpad.
- Global `⌃⌥Space` distraction capture, configurable in Settings.
- Best-effort app hiding/quit requests and a Safari/Chrome active-tab guard.
- Opt-in system-wide website blocking through a signed privileged helper and a marked `/etc/hosts` section.
- Optional Zen/Firefox restart to clear cached DNS/connections.
- Derived statistics from saved session history.
- Optional folder-based multi-Mac sync.
- Local JSON persistence with corruption quarantine and recovery.

## Product guardrails

- **No gamification.** Do not add streaks, leaderboards, achievements, points, badges, or guilt messaging.
- **No shame.** Do not scold users for missed sessions, low ratings, early ends, or skipped intentions.
- **Attention management only.** Do not add unrelated task management, calendars, note-taking suites, AI coaching, social features, or analytics dashboards.
- **Honest blocking.** Blocking is best effort. Never claim guaranteed enforcement, never force-terminate a browser or app, and never report blocking as active when permission or helper registration failed.
- **Local-first.** Do not add accounts, FocusBar servers, analytics, telemetry, crash-upload services, or hidden network calls.
- **User consent for privileged/system changes.** The helper is registered only after an explicit Settings action. Do not add a second privileged component or a Network Extension without owner approval.
- **Calm, compact UI.** Prefer clarity and restraint over decorative density. Respect macOS appearance, accessibility, and keyboard use.

## Non-goals

- iOS/iPadOS companion, App Store distribution, CloudKit/app-container sync, accounts, and notarization/release automation are not in v1.
- Friendly active-tab integration for Firefox/Arc/Edge is not in v1; system-wide hosts blocking covers them at name-resolution level.
- AI features, Network Extension content filtering, per-app network rules, wildcard domain blocking, and attempt telemetry for system-wide blocks are not in v1.
- macOS Focus/Shortcuts integration is optional and not implemented.

## Privacy posture

- Session history, focus objects, captures, intentions, ratings, settings, blocked-attempt hostnames, and sync bookkeeping are local JSON files.
- Browser checks read only the active tab URL and persist only hostname-level blocked attempts. Full URLs, paths, queries, and page content are never stored.
- Optional sync writes plain JSON snapshots to a user-selected folder. The folder provider may upload them under its own terms; FocusBar does not add end-to-end encryption.
- No telemetry or analytics. Diagnostics use Apple's unified logging locally.

## Success and decision-making

Success is a calm, trustworthy tool that helps the user return attention to one thing. It is not measured by engagement, streak length, or time-in-app. Product changes that affect scope, privacy, permissions, money, or distribution require the owner's explicit decision.
