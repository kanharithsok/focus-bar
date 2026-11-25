---
name: browser-automation
description: Use when changing Safari or Chrome active-tab inspection, Apple Events scripts, redirects, polling, timeouts, or Automation permission handling.
---

# Browser Automation

FocusBar's friendly guard is Safari + Google Chrome only, active tab only. Other browsers rely on the opt-in system-wide hosts block.

## Rules

- Run Apple Events through `AppleScriptRunner` off the main thread with a timeout. Never block the UI waiting for a browser.
- Use static scripts. Do not interpolate untrusted page content into AppleScript, `do shell script`, or a shell command.
- Treat the returned URL as untrusted: parse it, extract the hostname, normalize it, and match against the configured blocklist. Reject malformed/oversized values.
- Persist only hostname-level blocked attempts plus browser/session/timestamp/detail. Never store full URLs, paths, queries, page content, or browser history.
- Redirect the active tab to the bundled generic `blocked.html` only after validation. Never close a tab because a redirect failed.
- Map failures distinctly: success, timeout, Automation denied (`-1743`), browser not running, execution error. The UI must not claim protection when permission failed.
- Request/inspect Automation only at the documented point of use, not at launch. Provide a retry path after the user grants permission in System Settings.
- Poll only while a supported browser is foreground; an activation triggers an immediate check. Deduplicate repeated attempts/redirects and keep polling cheap.
- Do not add Firefox/Arc/Edge friendly tab integration without an owner decision and a new task.
- Do not add network code, a content blocker, or a Network Extension.

## Testing

- Unit-test URL parsing, hostname matching, permission mapping, timeout/error handling, dedup, and redirect decisions with fakes.
- Manual signed-build verification is required for real TCC prompts, Safari/Chrome redirects, denied permission, browser-not-running, and timeout behavior.
- Record browser versions and observed behavior; do not claim a manual pass without a desktop check.

## Security

Follow `docs/THREAT_MODEL.md` T9/T10. Do not log full URLs or page content. Do not weaken Automation handling to make a test pass.
