---
description: Inspect, initialize or resume the FocusBar software factory
---

You are executing `/factory-start` for FocusBar. Optional user context: $ARGUMENTS

1. Read `AGENTS.md`, `.factory/STATE.md`, `docs/ROADMAP.md`, `docs/FOLLOW_UPS.md`, `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/SECURITY_AND_PRIVACY.md`, `docs/THREAT_MODEL.md`, `docs/QUALITY_AND_TESTING.md`, `docs/DEPENDENCIES.md`, and `PLAN.md`. Load skills relevant to any work you perform.
2. Inspect the repository tree, Git branch, `git status`, staged/unstaged/untracked changes, the Xcode project, `project.yml`, tests, and available toolchain (`xcodegen --version`, `xcodebuild -version`, `swift --version`). Preserve all existing user work. Never assume the repository is empty or that the docs are current.
3. Run `bash scripts/validate-factory.sh` and report its output.
4. Reconcile `.factory/STATE.md` with evidence in the repository, `PLAN.md`, and `docs/ROADMAP.md`. Do not mark work done just because files exist; inspect and run checks.
5. If the factory baseline has not been verified, identify `FB-001` as the next step: factory validation, Debug build, unit tests, and the signed UI smoke test when a signing identity is available. Do not modify product code during baseline verification.
6. If a verified baseline exists, identify the lowest-numbered dependency-ready `TODO` task in `docs/ROADMAP.md`. `BACKLOG` tasks are captured but not eligible until promoted. Manual-verification tasks require the owner on a real desktop; do not promote them blindly.
7. Do not implement more than one roadmap task in this command. Report the recommended `/factory-next` task instead of starting it, unless the task is `FB-001` and the command's scope explicitly covers it.
8. Ask the owner only for a decision that blocks safe progress or changes money, privacy/legal obligations, production services, signing/distribution, or irreversible data. Use documented safe defaults for routine decisions.
9. Do not commit, push, tag, deploy, publish, reset data, delete sync folders, or unregister the helper.

Return: repository summary, Git safety status, toolchain/signing availability without exposing identities, verified foundation, blockers/owner decisions, checks run with PASS/FAIL/BLOCKED/NOT RUN, state-file updates, and the next exact command. Keep the result evidence-based.
