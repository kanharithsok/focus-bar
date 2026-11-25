---
name: security-review
description: Use for security-sensitive FocusBar changes, permission reviews, threat modeling, helper/XPC reviews, or vulnerability assessment.
---

# Security Review

Apply a risk-based review using `docs/THREAT_MODEL.md` and OWASP-style thinking adapted to a local macOS app.

## Check

- **TCC/permissions:** requested at point of use; denial/timeout handled honestly; no extra Accessibility/Screen Recording/Full Disk Access; no permission bypass.
- **Privileged helper:** XPC caller validation, minimal surface, hostname bounds, marker-scoped `/etc/hosts`, atomic writes, permissions, fail-open lease.
- **Browser automation:** static scripts, untrusted URL handling, no shell injection, off-main timeouts, no tab closing on failure, hostname-only persistence.
- **Persistence/sync:** untrusted JSON decoding, size bounds, corrupt/newer handling, path traversal, device-file ownership, tombstones, no secrets in snapshots.
- **Privacy:** no telemetry/network; no full URLs/paths/page content/focus/capture text in logs or storage; sync disclosure.
- **Signing:** helper requirement not weakened; ad-hoc limitations honest; no unsigned privileged path.
- **Supply chain:** only approved dependencies; SPM pin/provenance; no hidden network/telemetry.
- **Failure behavior:** force-quit/crash/helper loss must not leave a permanent system block or fake "protected" status.
- **Release:** no overclaiming enforcement, notarization, or App Store review.

## Rules

- Audit first. Separate confirmed vulnerabilities from hardening suggestions.
- Do not run destructive penetration tests, access user data, register/unregister the helper, rotate secrets, or change signing settings without explicit authorization.
- A narrowly scoped, high-confidence defect introduced in current work may be fixed if safe and testable; do not make sweeping security changes.
- Never suppress a finding or weaken a control to make tests pass.
- Report Critical/High findings prominently with file/line evidence, impact, reproduction/verification, and remediation.
- Do not disclose secrets, signing identities, personal content, or full URLs in findings.
- If a scanner/manual check is unavailable, state `NOT RUN`; do not imply a clean result.
