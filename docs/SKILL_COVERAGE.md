# FocusBar — Skill Coverage

The factory ships 17 project skills. Each has a distinct purpose; load the narrowest set that matches the task. `scripts/validate-factory.sh` requires every skill below to have a `SKILL.md` with matching folder/frontmatter name and a non-empty description.

| Skill | Use when | Primary non-overlap |
| --- | --- | --- |
| `accessibility` | Auditing VoiceOver, keyboard, focus, contrast, reduced motion, or menu-bar UI accessibility | UI behavior and audit; visual polish lives in `menu-bar-ui`/`design-system` |
| `architecture-review` | Reviewing object graph, state machines, module boundaries, failure modes, or major changes | Design-level review; implementation workflow lives in `feature-delivery` |
| `browser-automation` | Changing Safari/Chrome active-tab inspection, AppleScript, redirects, or permission handling | Browser-specific behavior; root hosts blocking lives in `privileged-helper-security` |
| `dependency-management` | Adding/upgrading/removing packages or changing XcodeGen/SPM settings | Dependency approval; release verification lives in `release-readiness` |
| `design-system` | Changing visual tokens, components, typography, spacing, or icon usage | Visual language; interaction/accessibility behavior lives in `menu-bar-ui`/`accessibility` |
| `diagnostics-and-logging` | Adding logs, diagnostics, error reporting, or debugging a runtime failure | Local observability; privacy review lives in `privacy-data-lifecycle` |
| `feature-delivery` | Implementing one roadmap task end-to-end | Delivery workflow; specialist skills provide domain rules |
| `macos-permissions` | Changing TCC permissions, notifications, Login Items, `SMAppService`, signing, or entitlements | Permission lifecycle and honesty; XPC hardening lives in `privileged-helper-security` |
| `menu-bar-ui` | Changing the popover, session views, settings, menu-bar label, or keyboard behavior | Interaction structure; visual tokens live in `design-system` |
| `performance-and-energy` | Changing timers, polling, wake handling, memory use, sync frequency, or background work | Runtime cost; browser-specific polling mechanics live in `browser-automation` |
| `persistence-and-sync` | Changing JSON schemas, `PersistenceController`, snapshots, merge rules, tombstones, or folder sync | Data durability and merge; privacy disclosure lives in `privacy-data-lifecycle` |
| `privacy-data-lifecycle` | Reviewing data collection, storage, logging, sync disclosure, deletion, retention, or diagnostics | Privacy impact; security controls live in `security-review` |
| `privileged-helper-security` | Changing the XPC helper, `/etc/hosts` management, helper registration, or lease logic | Root/XPC/hosts hardening; permission UX lives in `macos-permissions` |
| `release-readiness` | Preparing a release, signed build, Homebrew cask, or GO/NO-GO decision | Release gates; dependency/security details come from their own skills |
| `security-review` | Security-sensitive change, auth/permission review, threat modeling, or vulnerability assessment | Broad security review; specialized controls live in the helper/permissions skills |
| `swift-swiftui` | Writing Swift/SwiftUI/AppKit code, concurrency, state, or project structure | Language/framework patterns; UI interaction lives in `menu-bar-ui` |
| `testing-strategy` | Designing/writing/running unit, persistence, sync, helper, or UI tests | Test design and evidence; release decision lives in `release-readiness` |

## Non-overlap rules

- Do not duplicate domain rules across skills; reference the owning skill/document instead.
- `AGENTS.md` is binding. Skills add procedure and review checklists; they do not override product guardrails.
- Manual checks are not "covered" by a skill. They require recorded desktop evidence.
- `/factory-security-audit` loads `security-review` plus the relevant helper/permissions/privacy skills. It does not replace the helper security task (`FB-010`).
- `/factory-release` loads `release-readiness` and checks `docs/RELEASE_CHECKLIST.md`; it never deploys or publishes.
