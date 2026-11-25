#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
check_file() {
  if [[ -f "$1" ]]; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  missing %s\n' "$1"
    failures=$((failures + 1))
  fi
}

check_dir() {
  if [[ -d "$1" ]]; then
    printf 'PASS  %s/\n' "$1"
  else
    printf 'FAIL  missing directory %s/\n' "$1"
    failures=$((failures + 1))
  fi
}

check_file AGENTS.md
check_file README.md
check_file PLAN.md
check_file docs/PRODUCT.md
check_file docs/ARCHITECTURE.md
check_file docs/ROADMAP.md
check_file docs/DECISIONS.md
check_file docs/FOLLOW_UPS.md
check_file docs/SECURITY_AND_PRIVACY.md
check_file docs/THREAT_MODEL.md
check_file docs/QUALITY_AND_TESTING.md
check_file docs/DEPENDENCIES.md
check_file docs/SKILL_COVERAGE.md
check_file docs/RELEASE_CHECKLIST.md
check_file .factory/STATE.md
check_file .factory/WORK_LOG.md
check_file .factory/TASK_TEMPLATE.md
check_dir .opencode/commands
check_dir .opencode/skills

for cmd in factory-start factory-plan factory-add-task factory-next factory-status factory-test factory-review factory-security-audit factory-release factory-help; do
  check_file ".opencode/commands/${cmd}.md"
done

required_skills=(
  accessibility
  architecture-review
  browser-automation
  dependency-management
  design-system
  diagnostics-and-logging
  feature-delivery
  macos-permissions
  menu-bar-ui
  performance-and-energy
  persistence-and-sync
  privacy-data-lifecycle
  privileged-helper-security
  release-readiness
  security-review
  swift-swiftui
  testing-strategy
)

for skill in "${required_skills[@]}"; do
  check_file ".opencode/skills/${skill}/SKILL.md"
  if ! grep -qF "| \`${skill}\` |" docs/SKILL_COVERAGE.md; then
    printf 'FAIL  skill missing from coverage matrix: %s\n' "$skill"
    failures=$((failures + 1))
  fi
done

command_count=$(find .opencode/commands -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
skill_count=0
while IFS= read -r skill_file; do
  skill_count=$((skill_count + 1))
  folder="$(basename "$(dirname "$skill_file")")"
  if ! grep -q "^name: ${folder}$" "$skill_file"; then
    printf 'FAIL  skill name/folder mismatch: %s\n' "$skill_file"
    failures=$((failures + 1))
  else
    printf 'PASS  skill metadata: %s\n' "$skill_file"
  fi
  if ! grep -q '^description: .\{1,\}$' "$skill_file"; then
    printf 'FAIL  missing skill description: %s\n' "$skill_file"
    failures=$((failures + 1))
  fi
done < <(find .opencode/skills -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' | sort)

if [[ "$command_count" -lt 10 ]]; then
  printf 'FAIL  expected at least 10 command files, found %s\n' "$command_count"
  failures=$((failures + 1))
else
  printf 'PASS  %s command files found\n' "$command_count"
fi

if [[ "$skill_count" -lt "${#required_skills[@]}" ]]; then
  printf 'FAIL  expected at least %s skills, found %s\n' "${#required_skills[@]}" "$skill_count"
  failures=$((failures + 1))
else
  printf 'PASS  %s skill files found (required: %s)\n' "$skill_count" "${#required_skills[@]}"
fi

# Check that command files start with valid frontmatter delimiters and declare a description.
for command_file in .opencode/commands/*.md; do
  first_line="$(head -n 1 "$command_file")"
  if [[ "$first_line" != '---' ]]; then
    printf 'FAIL  missing YAML frontmatter: %s\n' "$command_file"
    failures=$((failures + 1))
  elif ! grep -q '^description: .\{1,\}$' "$command_file"; then
    printf 'FAIL  missing command description: %s\n' "$command_file"
    failures=$((failures + 1))
  else
    printf 'PASS  command frontmatter: %s\n' "$command_file"
  fi
done

# The roadmap must use FocusBar task IDs and contain the active baseline task.
if ! grep -q '^### FB-001 ' docs/ROADMAP.md; then
  printf 'FAIL  docs/ROADMAP.md is missing the FB-001 task block\n'
  failures=$((failures + 1))
fi

if ! grep -qE 'FB-[0-9]{3}' docs/ROADMAP.md; then
  printf 'FAIL  docs/ROADMAP.md has no FB-NNN task IDs\n'
  failures=$((failures + 1))
fi

# Guard against copying project-specific names from the source factory.
if grep -rIl -e 'Dak Peak' -e 'DAK-[0-9]' .factory docs .opencode prompts 2>/dev/null | grep -q .; then
  printf 'FAIL  stale source-project terminology found:\n'
  grep -rIl -e 'Dak Peak' -e 'DAK-[0-9]' .factory docs .opencode prompts 2>/dev/null | sed 's/^/      /'
  failures=$((failures + 1))
else
  printf 'PASS  no stale source-project terminology in factory files\n'
fi

# Ensure the canonical instruction file points at the factory workflow.
for marker in '.factory/STATE.md' 'docs/ROADMAP.md' '/factory-next'; do
  if ! grep -qF "$marker" AGENTS.md; then
    printf 'FAIL  AGENTS.md does not reference %s\n' "$marker"
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  printf '\nFactory validation FAILED (%s issue(s)).\n' "$failures"
  exit 1
fi
printf '\nFactory package structure validation PASSED. This does not validate application build/test results or prove OpenCode runtime discovery.\n'
