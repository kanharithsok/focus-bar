---
description: Perform a focused FocusBar security and privacy audit
---

Perform a security audit of FocusBar. Scope: $ARGUMENTS

Read `AGENTS.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, and load the `security-review`, `privileged-helper-security`, `macos-permissions`, `browser-automation`, and `privacy-data-lifecycle` skills as relevant. Inspect real code, tests, configuration, `project.yml`, the LaunchDaemon plist, and the Git diff.

Assess:
- TCC permissions and honesty (Automation, Notifications, folder access, Login Items, `SMAppService`);
- helper XPC caller validation, input validation, marker-scoped `/etc/hosts` edits, atomic writes, permissions, lease/cleanup;
- AppleScript/browser input handling, off-main execution, timeouts, failure mapping;
- persistence decoding, corrupt/newer files, path handling, sync snapshot trust, tombstones, device-file ownership;
- PII/data leakage in logs, persistence, snapshots, URLs, error messages, and screenshots;
- secrets/signing configuration, dependency provenance, no app-initiated network calls;
- code-signing restrictions and whether any control is weakened for ad-hoc builds;
- release/distribution assumptions (signed helper, `/Applications`, notarization status).

Default to audit-first. You may fix a narrowly scoped, high-confidence defect introduced in current work if the fix is safe and testable. Do not make sweeping security changes, weaken controls, rotate secrets, access user/production data, run destructive tests, register/unregister the helper, or change signing settings. Report Critical/High findings prominently with concrete evidence and a verification plan. If a scanner or manual check is unavailable, say NOT RUN rather than implying a clean result. Do not expose secrets, signing identities, or personal data.
