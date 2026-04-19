---
description: Bootstrap a new project with standard folder structure, CLAUDE.md, security audit infrastructure, and git hooks. Supports DRY_RUN=true for preview and FORCE_UPDATE=true for upgrades.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Project Kickoff

**Working directory:** $ARGUMENTS (use current directory if empty)

Run the following script.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly KICKOFF_VERSION="kickoff-v3.0"
readonly CLAUDE_MD_VERSION="claude-md-v3.0"
readonly SECURITY_AUDIT_VERSION="security-audit-v3.0"
readonly PRE_PR_HOOK_VERSION="pre-pr-hook-v3.0"

TARGET_DIR="${ARGUMENTS:-.}"
DRY_RUN="${DRY_RUN:-false}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"

log()   { echo "[INFO]    $*"; }
ok()    { echo "[OK]      $*"; }
skip()  { echo "[SKIP]    $*"; }
warn()  { echo "[WARN]    $*" >&2; }
drylog(){ echo "[DRY-RUN] $*"; }
err()   { echo "[ERROR]   $*" >&2; exit 1; }

write_file() {
  local path="$1"
  local content
  content="$(cat)"
  if [ "$DRY_RUN" = true ]; then drylog "write_file -> $path"; return 0; fi
  if [ -f "$path" ] && [ "$FORCE_UPDATE" != true ]; then
    skip "$path already exists (use FORCE_UPDATE=true to overwrite)"; return 0
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  ok "$path written"
}

make_dir() {
  local path="$1"
  if [ "$DRY_RUN" = true ]; then drylog "mkdir -p $path"; return 0; fi
  if [ -d "$path" ]; then skip "$path/ already exists"; return 0; fi
  mkdir -p "$path"; ok "$path/ created"
}

append_if_missing() {
  local file="$1" line="$2"
  if [ "$DRY_RUN" = true ]; then drylog "append_if_missing -> $file: '$line'"; return 0; fi
  touch "$file"
  if grep -qxF "$line" "$file" 2>/dev/null; then skip "$file: '$line' already present"; return 0; fi
  printf '%s\n' "$line" >> "$file"; ok "$file <- '$line'"
}

run_git() {
  if [ "$DRY_RUN" = true ]; then drylog "git $*"; return 0; fi
  git "$@"
}

make_executable() {
  local path="$1"
  if [ "$DRY_RUN" = true ]; then drylog "chmod +x $path"; return 0; fi
  chmod +x "$path"
}

extract_version() {
  grep -m1 -oE '[a-z-]+-v[0-9]+\.[0-9]+' "$1" 2>/dev/null | head -1 || echo "unknown"
}

check_version() {
  local file="$1" expected="$2" label="$3"
  [ -f "$file" ] || return 0
  local found; found="$(extract_version "$file")"
  if [ "$found" = "$expected" ]; then skip "$label is up-to-date ($found)"
  else
    warn "$label is OUTDATED ($found -> $expected)"
    warn "  Run with FORCE_UPDATE=true to upgrade, or update manually."
  fi
  return 1
}

register_pre_pr_hook() {
  local settings="$1"
  local hook_entry='{"matcher":"Bash","hooks":[{"type":"command","command":"bash ~/.claude/hooks/pre-pr-audit-check.sh","statusMessage":"Checking security audit status..."}]}'
  if [ "$DRY_RUN" = true ]; then drylog "register_pre_pr_hook -> $settings"; return 0; fi
  if [ ! -f "$settings" ]; then
    mkdir -p "$(dirname "$settings")"
    printf '%s\n' "{\"hooks\":{\"PreToolUse\":[$hook_entry]}}" | python3 -m json.tool > "$settings" 2>/dev/null || printf '%s\n' "{\"hooks\":{\"PreToolUse\":[$hook_entry]}}" > "$settings"
    ok "$settings created with hook"; return 0
  fi
  if grep -q "pre-pr-audit-check.sh" "$settings" 2>/dev/null; then skip "$settings: pre-PR hook already registered"; return 0; fi
  if command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    if jq --argjson entry "$hook_entry" '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [$entry])' "$settings" > "$tmp" && jq empty "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"; ok "$settings: pre-PR hook registered via jq"
    else rm -f "$tmp"; warn "jq merge failed -- manual action required"; fi
  else warn "jq not found -- cannot safely modify $settings. Add pre-PR hook manually."; fi
}

# ── MAIN ──
if [ -n "$TARGET_DIR" ] && [ "$TARGET_DIR" != "." ]; then
  [ -d "$TARGET_DIR" ] || err "Target directory does not exist: $TARGET_DIR"
  cd "$TARGET_DIR"
fi

PROJECT_NAME="$(basename "$(pwd)")"
log "Kickoff $KICKOFF_VERSION | project=$PROJECT_NAME | pwd=$(pwd)"
log "DRY_RUN=$DRY_RUN | FORCE_UPDATE=$FORCE_UPDATE"
echo "---"

log "S1 Directory structure"
make_dir tasks
make_dir docs

log "S2 Task files"
if [ ! -s tasks/todo.md ] || [ "$FORCE_UPDATE" = true ]; then
  write_file tasks/todo.md <<TODOEOF
# ${PROJECT_NAME} -- Task List

## Active Tasks
- [ ] Project kickoff complete

## Completed

## Review Notes
TODOEOF
else skip "tasks/todo.md exists and non-empty"; fi

if [ ! -s tasks/lessons.md ] || [ "$FORCE_UPDATE" = true ]; then
  write_file tasks/lessons.md <<LESSEOF
# ${PROJECT_NAME} -- Lessons Learned
LESSEOF
else skip "tasks/lessons.md exists and non-empty"; fi

log "S3 CLAUDE.md"
if check_version CLAUDE.md "$CLAUDE_MD_VERSION" "CLAUDE.md"; then
  write_file CLAUDE.md <<'CLAUDEEOF'
<!-- version: claude-md-v3.0 -->
# Workflow Orchestration

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately
- Write detailed specs upfront to reduce ambiguity
- Check vulnerabilities for used packages
- Plan with Secure Coding logic

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update tasks/lessons.md with the pattern
- Write rules for yourself that prevent the same mistake
- Review lessons at session start

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- Skip this for simple, obvious fixes

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it
- Point at logs, errors, failing tests -- then resolve them

## Task Management
1. Plan First: Write plan to tasks/todo.md with checkable items
2. Verify Plan: Check in before starting implementation
3. Track Progress: Mark items complete as you go
4. Explain Changes: High-level summary at each step
5. Document Results: Add review section to tasks/todo.md
6. Capture Lessons: Update tasks/lessons.md after corrections

## Core Principles
- Simplicity First: Make every change as simple as possible
- No Laziness: Find root causes. No temporary fixes
- Minimal Impact: Changes should only touch what is necessary
- Version Management: Commit every change; after 5 commits push changes

## Security Audit Policy
- Before creating any PR, remind the user to run /security-audit if no audit report exists within the last 7 days in docs/security-audit-report-*.md
- When adding new dependencies, check for known vulnerabilities before proceeding
- Never commit .env files, private keys, or credentials -- BLOCK and warn
CLAUDEEOF
fi

log "S4 Project-local .claude"
make_dir .claude/commands

log "S4.1 .claude/commands/security-audit.md"
if check_version .claude/commands/security-audit.md "$SECURITY_AUDIT_VERSION" "project security-audit"; then
  write_file .claude/commands/security-audit.md <<'SAEOF'
---
description: Run a comprehensive security audit with 6 parallel subagents. Auto-detects tech stack and produces a detailed vulnerability report.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList
version: security-audit-v3.0
---

# Security Audit -- 6-Agent Parallel Scan

## Project Context
- **Working directory:** $ARGUMENTS
- **Date:** !`date +%Y-%m-%d`
- **Project name:** !`basename $(pwd)`
- **Git status:** !`git log --oneline -3 2>/dev/null || echo "Not a git repo"`

## Tech Stack Detection
- **Backend:** !`ls -1 requirements.txt Pipfile pyproject.toml go.mod pom.xml build.gradle Cargo.toml Gemfile composer.json 2>/dev/null || echo "NONE"`
- **Frontend:** !`ls -1 package.json yarn.lock pnpm-lock.yaml 2>/dev/null || echo "NONE"`
- **Docker:** !`ls -1 Dockerfile docker-compose.yml docker-compose.yaml 2>/dev/null || echo "NONE"`
- **Lock files:** !`ls -1 package-lock.json yarn.lock pnpm-lock.yaml Pipfile.lock poetry.lock go.sum Cargo.lock 2>/dev/null || echo "NONE"`

## Instructions

### Phase 1: Classify Tech Stack
| Dimension | Options |
|-----------|---------|
| Backend language | Python / Node.js / Go / Java / Rust / Ruby / PHP / C# / Mixed / None |
| Frontend framework | React / Vue / Angular / Svelte / Static HTML / None |
| Infrastructure | Docker / Kubernetes / Terraform / Bare metal / None |

### Phase 2: Dispatch 6 Parallel Subagents
Launch ALL 6 in a single message with run_in_background: true.

- Subagent 1 -- Backend Dependency Audit: pip-audit/npm audit/govulncheck. Unpinned deps, missing lockfile, abandoned packages. Output: Package | Version | CVE | Severity | Fix available? | Description
- Subagent 2 -- Frontend Dependency Audit: npm/yarn/pnpm audit. CDN imports, eval() usage. Output: Package | Version | Advisory | Severity | Fix available? | Description
- Subagent 3 -- Backend Auth & Secrets Audit (READ-ONLY): JWT, hardcoded credentials, CORS/CSRF, brute-force, RBAC, IDOR. Patterns: password/secret/key/token hardcoded; verify=False; eval/exec; mass assignment. Output: File:line | Severity | Description | Fix
- Subagent 4 -- Backend Injection & Input Validation (READ-ONLY): SQLi, CMDi, SSRF, path traversal, deserialization, prompt injection, webhook auth, template injection. Output: File:line | Severity | Description | Fix
- Subagent 5 -- Frontend Security Audit (READ-ONLY): XSS, token storage, open redirects, CSP, source maps, prototype pollution, WebSocket auth. Output: File:line | Severity | Description | Fix
- Subagent 6 -- Infrastructure & Docker Audit (READ-ONLY): Dockerfile (root, :latest, build-arg secrets), docker-compose, nginx, .gitignore, CI/CD, Redis auth, TLS, CORS. Output: File:line | Severity | Description | Fix

If category N/A -> report "N/A" and exit.

### Phase 3: Compile Report
Write to: docs/security-audit-report-YYYY-MM-DD.md
Structure: Executive Summary (severity table + risk level) -> Critical/High/Medium/Low/Info findings -> Dependency CVE tables -> Positive findings -> Remediation Priority Matrix (P0-P3)

### Phase 4: Summary
Print report path + 3-sentence executive summary. Do NOT claim completion without evidence all 6 subagents returned.
SAEOF
fi

log "S4.2 .git/hooks/pre-commit"
if [ -d .git ]; then
  HOOK_FILE=".git/hooks/pre-commit"
  if [ ! -f "$HOOK_FILE" ] || [ "$FORCE_UPDATE" = true ]; then
    write_file "$HOOK_FILE" <<'HOOKEOF'
#!/usr/bin/env bash
# Basic secret heuristic -- NOT a full scanner. Use /security-audit for comprehensive scans.
set -euo pipefail
FOUND=$(grep -rn \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.venv \
  --exclude-dir=__pycache__ --exclude-dir=dist --exclude-dir=build \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.tsx" \
  --include="*.go" --include="*.env" --include="*.yaml" --include="*.yml" \
  --include="*.json" --include="*.toml" \
  -E '(API_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|SECRET_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|PRIVATE_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|password\s*=\s*["'"'"'][^"'"'"']{4,}["'"'"'])' \
  . 2>/dev/null || true)
if [ -n "$FOUND" ]; then
  echo "Potential secret detected -- commit blocked:"
  echo "$FOUND"
  echo "NOTE: Basic pattern scan only. Run /security-audit for full coverage."
  exit 1
fi
echo "Secret heuristic check passed"
HOOKEOF
    make_executable "$HOOK_FILE"
  else skip ".git/hooks/pre-commit exists"; fi
else skip ".git not initialized -- pre-commit hook skipped"; fi

log "S5 Global ~/.claude infrastructure"
GLOBAL_SA="$HOME/.claude/commands/security-audit.md"
if check_version "$GLOBAL_SA" "$SECURITY_AUDIT_VERSION" "global security-audit"; then
  if [ "$DRY_RUN" != true ]; then
    mkdir -p "$HOME/.claude/commands"
    cp .claude/commands/security-audit.md "$GLOBAL_SA"
    ok "$GLOBAL_SA created"
  fi
fi

GLOBAL_HOOK="$HOME/.claude/hooks/pre-pr-audit-check.sh"
if check_version "$GLOBAL_HOOK" "$PRE_PR_HOOK_VERSION" "global pre-PR hook"; then
  write_file "$GLOBAL_HOOK" <<'PREOF'
#!/usr/bin/env bash
# version: pre-pr-hook-v3.0
set -euo pipefail
input=$(cat)
tool_name=$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[[ "$tool_name" == "Bash" ]] || { echo '{}'; exit 0; }
command_input=$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
echo "$command_input" | grep -qE '(gh pr create|git push)' || { echo '{}'; exit 0; }
AUDIT_DIR="docs"
if [[ -d "$AUDIT_DIR" ]]; then
  RECENT=$(find "$AUDIT_DIR" -name "security-audit-report-*.md" -mtime -7 2>/dev/null | head -1)
  [[ -z "$RECENT" ]] || { echo '{}'; exit 0; }
fi
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","systemMessage":"WARNING: No security audit report found in docs/ within the last 7 days. Consider running /security-audit before creating a PR."}}'
exit 0
PREOF
  make_executable "$GLOBAL_HOOK"
fi

log "S5.3 ~/.claude/settings.json"
register_pre_pr_hook "$HOME/.claude/settings.json"

log "S6 .gitignore"
touch .gitignore
for pattern in ".env" "*.key" "*.pem" "secrets/" ".claude/hooks/"; do
  append_if_missing .gitignore "$pattern"
done

log "S7 Git"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  run_git init; ok "git initialized"
else skip "git repo already exists"; fi

log "S8 Initial commit"
if [ "$DRY_RUN" = true ]; then
  drylog "git add + commit"
else
  git add CLAUDE.md tasks/ docs/ .gitignore .claude/commands/ 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    run_git commit -m "chore: project kickoff -- initial structure ($KICKOFF_VERSION)"
    ok "initial commit"
  else skip "nothing new to commit"; fi
fi

echo ""
echo "=== Kickoff complete: $PROJECT_NAME ($KICKOFF_VERSION) ==="
echo ""
echo "Available commands:"
echo "  /kickoff                      -- run this procedure"
echo "  /security-audit               -- 6-agent security scan"
echo "  DRY_RUN=true /kickoff         -- preview mode"
echo "  FORCE_UPDATE=true /kickoff    -- force update all files"
```
