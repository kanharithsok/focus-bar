---
name: privileged-helper-security
description: Use when changing FocusBarHelper, the XPC protocol, hosts rendering/removal, SMAppService registration, or the fail-open lease.
---

# Privileged Helper Security

`FocusBarHelper` runs as root. A bug can break name resolution system-wide. Treat every change as security-sensitive.

## XPC surface

- Keep the protocol minimal and typed. No arbitrary paths, file contents, shell commands, or unvalidated dictionaries.
- Validate the caller with the code-signing requirement in `HelperClientRequirement`. Reject unsigned/wrong-team clients. Never relax this for ad-hoc builds.
- Validate every hostname: length bounds, non-empty, no whitespace/paths/wildcards/schemes/ports, valid DNS labels, allowed characters. Bound the list size.
- Do not expose a generic "write hosts" or "run command" operation. Accept only the operation the app needs.
- Reject unexpected message versions/fields; fail closed for authentication, fail open for blocking cleanup.

## `/etc/hosts` management

- Only remove/append the `# >>> FocusBar managed block >>>` section. Preserve all unrelated content byte-for-byte.
- Refuse malformed/duplicate markers rather than overwriting the file.
- Preserve the existing file mode/ownership. Write atomically (temp file + rename) on the same volume.
- Flush DNS after apply/remove; do not run arbitrary shell commands with user input.
- Bound output/memory; do not read the entire file into an unbounded buffer if it can be avoided.
- Log only operation/status, not hostnames tied to a person or file contents.

## Lease and lifecycle

- Lease is 30 seconds; heartbeat every 8 seconds while blocking is active.
- Cleanup on session end, lease expiry, helper launch/stale section, SIGTERM/unregister, reinstall, and reboot.
- Force-quit/crash must not leave a permanent block. The app must not assume the helper succeeded; query status.
- Never leave the helper registered automatically. Registration is user-initiated in Settings.
- Deleting the app does not unregister the daemon; document **Remove helper**/System Settings.

## Testing and review

- Unit-test hostname validation/expansion, marker rendering/removal, malformed markers, permission preservation, and lease/status logic with a temp file-manager seam.
- Real `SMAppService` registration, root daemon launch, XPC rejection, `/etc/hosts` writes, force-quit lease, and reboot cleanup require signed manual verification (`FB-005`).
- Re-review `docs/THREAT_MODEL.md` T1–T5/T12–T15 on every change.
- Do not add a second privileged component or Network Extension without an explicit owner decision.
