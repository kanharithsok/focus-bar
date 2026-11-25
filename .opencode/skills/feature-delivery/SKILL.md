---
name: feature-delivery
description: Use when implementing one FocusBar roadmap task or end-to-end product feature; guides scoped delivery, acceptance criteria, tests and durable progress updates.
---

# Feature Delivery

1. Read the task, acceptance criteria, product scope, relevant decisions, `docs/ARCHITECTURE.md`, and current state.
2. Inspect the code and existing patterns before designing a change. Preserve unrelated work.
3. Define a vertical slice across models, services, persistence, views, and tests as appropriate. Keep scope to one task.
4. Identify TCC permissions, personal data, filesystem/sync paths, helper/XPC impact, signing impact, and network impact (default: none) before coding.
5. Prefer the smallest maintainable design that respects the layer rules. Avoid speculative abstractions and new dependencies.
6. Add tests for normal behavior, boundaries, failure behavior, and permission/helper failure paths. For sensitive features include negative cases (denied TCC, malformed hostname, corrupt JSON, sync conflict, invalid transition).
7. Implement invariants in services, not views. Views only render state and send intents.
8. Update docs/decisions/tests when relevant. Do not add gamification, guilt messaging, or unrelated features.
9. Run the formatter/build/unit tests and relevant broader checks. Inspect actual output.
10. Review `git diff` for accidental scope, secrets, personal content, generated artifacts, and `project.pbxproj` churn.
11. Update task/state/work log only according to observed results. Never mark unverified work done. Manual TCC/helper/browser/two-Mac checks stay `NOT RUN` until performed.
12. Give every remaining issue an `FB-`/`FU-`/release-gate/accepted-limitation disposition.

Do not commit, push, tag, deploy, publish, change signing, register/unregister the helper, or delete user data without explicit owner instruction.
