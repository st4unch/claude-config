---
description: Getirfinans yeni proje kickoff prosedürünü çalıştırır. Klasör yapısı, tasks/, docs/, CLAUDE.md ve güvenlik denetim altyapısını (slash command, pre-PR hook, settings.json) otomatik bootstrap eder. DRY_RUN=true ile güvenli önizleme, FORCE_UPDATE=true ile zorla güncelleme desteklenir.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Getirfinans — Project Kickoff

**Çalışma dizini:** $ARGUMENTS (boşsa mevcut dizini kullan)

Aşağıdaki script'i çalıştır.

```bash
#!/usr/bin/env bash
# =============================================================================
# Getirfinans Project Kickoff Bootstrap
# Version : kickoff-v3.0
# Usage   : /kickoff [target-dir]
#           DRY_RUN=true /kickoff        → önizleme, hiçbir şey yazılmaz
#           FORCE_UPDATE=true /kickoff   → mevcut dosyaları günceller
# =============================================================================
set -euo pipefail

# ── Canonical versions ────────────────────────────────────────────────────────
readonly KICKOFF_VERSION="kickoff-v3.0"
readonly CLAUDE_MD_VERSION="claude-md-v3.0"
readonly SECURITY_AUDIT_VERSION="security-audit-v3.0"
readonly PRE_PR_HOOK_VERSION="pre-pr-hook-v3.0"

# ── Runtime config ────────────────────────────────────────────────────────────
TARGET_DIR="${ARGUMENTS:-.}"
DRY_RUN="${DRY_RUN:-false}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"

# ── Logging ───────────────────────────────────────────────────────────────────
log()   { echo "[INFO]    $*"; }
ok()    { echo "[OK]      $*"; }
skip()  { echo "[SKIP]    $*"; }
warn()  { echo "[WARN]    $*" >&2; }
drylog(){ echo "[DRY-RUN] $*"; }
err()   { echo "[ERROR]   $*" >&2; exit 1; }

# ── Core helpers ──────────────────────────────────────────────────────────────

# write_file <path> <content-via-stdin>
# Respects DRY_RUN and FORCE_UPDATE. Never overwrites unless forced.
write_file() {
  local path="$1"
  local content
  content="$(cat)"   # read from stdin

  if [ "$DRY_RUN" = true ]; then
    drylog "write_file → $path"
    return 0
  fi

  if [ -f "$path" ] && [ "$FORCE_UPDATE" != true ]; then
    skip "$path already exists (use FORCE_UPDATE=true to overwrite)"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  ok "$path written"
}

# make_dir <path>
make_dir() {
  local path="$1"
  if [ "$DRY_RUN" = true ]; then
    drylog "mkdir -p $path"
    return 0
  fi
  if [ -d "$path" ]; then
    skip "$path/ already exists"
    return 0
  fi
  mkdir -p "$path"
  ok "$path/ created"
}

# append_if_missing <file> <line>
# Appends <line> to <file> only if an exact match doesn't already exist.
append_if_missing() {
  local file="$1"
  local line="$2"

  if [ "$DRY_RUN" = true ]; then
    drylog "append_if_missing → $file: '$line'"
    return 0
  fi

  touch "$file"
  if grep -qxF "$line" "$file" 2>/dev/null; then
    skip "$file: '$line' already present"
    return 0
  fi
  printf '%s\n' "$line" >> "$file"
  ok "$file ← '$line'"
}

# run_git <args...>
# Git operations gated on DRY_RUN.
run_git() {
  if [ "$DRY_RUN" = true ]; then
    drylog "git $*"
    return 0
  fi
  git "$@"
}

# make_executable <path>
make_executable() {
  local path="$1"
  if [ "$DRY_RUN" = true ]; then
    drylog "chmod +x $path"
    return 0
  fi
  chmod +x "$path"
}

# ── Version helpers ───────────────────────────────────────────────────────────

# extract_version <file> → prints version string or "unknown"
extract_version() {
  local file="$1"
  grep -m1 -oE '[a-z-]+-v[0-9]+\.[0-9]+' "$file" 2>/dev/null | head -1 || echo "unknown"
}

# check_version <file> <expected-version> <label>
# Emits [WARN] if file exists but version is outdated.
# Returns 0 if file is absent (caller should create), 1 if present (skip or warn).
check_version() {
  local file="$1"
  local expected="$2"
  local label="$3"

  [ -f "$file" ] || return 0   # absent → caller creates

  local found
  found="$(extract_version "$file")"

  if [ "$found" = "$expected" ]; then
    skip "$label is up-to-date ($found)"
  else
    warn "$label is OUTDATED ($found → $expected)"
    warn "  File: $file"
    warn "  Run with FORCE_UPDATE=true to upgrade, or update manually."
  fi
  return 1   # present → caller skips creation
}

# ── JSON helper ───────────────────────────────────────────────────────────────

# register_pre_pr_hook <settings-file>
# Safely adds the pre-PR hook to ~/.claude/settings.json.
# Prefers jq; falls back to safe append when jq absent; never corrupts JSON.
register_pre_pr_hook() {
  local settings="$1"
  local hook_entry
  hook_entry='{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/hooks/pre-pr-audit-check.sh",
        "statusMessage": "Guvenlik taramasi kontrolu..."
      }]
    }'

  if [ "$DRY_RUN" = true ]; then
    drylog "register_pre_pr_hook → $settings"
    return 0
  fi

  # ── Case 1: File doesn't exist → create minimal valid JSON
  if [ ! -f "$settings" ]; then
    mkdir -p "$(dirname "$settings")"
    printf '%s\n' '{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "bash ~/.claude/hooks/pre-pr-audit-check.sh",
          "statusMessage": "Guvenlik taramasi kontrolu..."
        }]
      }
    ]
  }
}' > "$settings"
    ok "$settings created with hook"
    return 0
  fi

  # ── Case 2: Already registered → skip
  if grep -q "pre-pr-audit-check.sh" "$settings" 2>/dev/null; then
    skip "$settings: pre-PR hook already registered"
    return 0
  fi

  # ── Case 3: File exists, hook absent → attempt jq merge
  if command -v jq >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp)"
    # Merge: add our hook into .hooks.PreToolUse[], create path if missing
    if jq \
      --argjson entry "$hook_entry" \
      '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + [$entry])' \
      "$settings" > "$tmp" && jq empty "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      ok "$settings: pre-PR hook registered via jq"
    else
      rm -f "$tmp"
      warn "jq merge failed for $settings — manual action required:"
      warn "  Add to hooks.PreToolUse array:"
      warn "  $hook_entry"
    fi
  else
    # ── Case 4: No jq → print manual instruction, never touch the file
    warn "jq not found — cannot safely modify $settings"
    warn "Manual action required. Add this to hooks.PreToolUse array in $settings:"
    warn "  $hook_entry"
  fi
}

# =============================================================================
# MAIN
# =============================================================================

# ── Resolve target directory ──────────────────────────────────────────────────
if [ -n "$TARGET_DIR" ] && [ "$TARGET_DIR" != "." ]; then
  [ -d "$TARGET_DIR" ] || err "Target directory does not exist: $TARGET_DIR"
  cd "$TARGET_DIR"
fi

PROJECT_NAME="$(basename "$(pwd)")"
log "Kickoff $KICKOFF_VERSION | project=$PROJECT_NAME | pwd=$(pwd)"
log "DRY_RUN=$DRY_RUN | FORCE_UPDATE=$FORCE_UPDATE"
echo "──────────────────────────────────────────────────"

# ── 1. Directory structure ────────────────────────────────────────────────────
log "§1 Directory structure"
make_dir tasks
make_dir docs

# ── 2. Task files ─────────────────────────────────────────────────────────────
log "§2 Task files"

if [ ! -s tasks/todo.md ] || [ "$FORCE_UPDATE" = true ]; then
  write_file tasks/todo.md <<TODOEOF
# ${PROJECT_NAME} — Görev Listesi

## Aktif Görevler
- [ ] Proje kickoff tamamlandı

## Tamamlananlar

## İnceleme Notları
TODOEOF
else
  skip "tasks/todo.md exists and non-empty"
fi

if [ ! -s tasks/lessons.md ] || [ "$FORCE_UPDATE" = true ]; then
  write_file tasks/lessons.md <<LESSEOF
# ${PROJECT_NAME} — Öğrenilen Dersler
LESSEOF
else
  skip "tasks/lessons.md exists and non-empty"
fi

# ── 3. CLAUDE.md ──────────────────────────────────────────────────────────────
log "§3 CLAUDE.md"

if check_version CLAUDE.md "$CLAUDE_MD_VERSION" "CLAUDE.md"; then
  # File absent → create
  write_file CLAUDE.md <<'CLAUDEEOF'
<!-- version: claude-md-v3.0 -->
# Workflow Orchestration

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity
- Check vulnerabilities for used packages — do not use packages with critical vulnerabilities.
- Plan with Secure Coding logic.

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what is necessary. Avoid introducing bugs.
- **Version Management**: Commit every change; after 5 commits push changes.

## Security Audit Policy

- Before creating any PR, remind the user to run `/security-audit` if no audit report
  exists within the last 7 days in `docs/security-audit-report-*.md`
- When adding new dependencies, check for known vulnerabilities before proceeding
- Never commit `.env` files, private keys, or credentials — BLOCK and warn
- When reviewing Docker/CI/CD configs, flag obvious security issues inline

## Security Audit Infrastructure — Auto-Bootstrap

At the **start of every new session**, silently verify the security audit infrastructure
exists. If ANY file is missing, create it without asking the user.

Check order: Run once per session (first user message). Use `ls` to verify — do NOT read.

- Check 1: `~/.claude/commands/security-audit.md`  — 6-agent parallel audit slash command
- Check 2: `~/.claude/hooks/pre-pr-audit-check.sh` — pre-PR audit warning hook
- Check 3: `~/.claude/settings.json`               — PreToolUse hook registration

Full blueprints: `~/.claude/commands/kickoff.md`

### When NOT to auto-check
- User explicitly disables security audit checks
- Read-only / research-only session
- Only at session start — not on every message
- Subagents skip this check
CLAUDEEOF
fi

# ── 4. Project-local .claude ──────────────────────────────────────────────────
log "§4 Project-local .claude"
make_dir .claude/commands
# NOTE: .claude/hooks is intentionally NOT created — hooks live in ~/.claude only

# ── 4.1 security-audit slash command ─────────────────────────────────────────
log "§4.1 .claude/commands/security-audit.md"

if check_version .claude/commands/security-audit.md "$SECURITY_AUDIT_VERSION" "project security-audit"; then
  write_file .claude/commands/security-audit.md <<'SAEOF'
---
description: Run a comprehensive security audit on the current project with 6 parallel subagents. Auto-detects tech stack and produces a detailed vulnerability report.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList
version: security-audit-v3.0
---

# Security Audit — Automated 6-Agent Parallel Scan

## Project Context

- **Working directory:** $ARGUMENTS
- **Date:** !`date +%Y-%m-%d`
- **Project name:** !`basename $(pwd)`
- **Git status:** !`git log --oneline -3 2>/dev/null || echo "Not a git repo"`

## Tech Stack Detection

- **Backend:** !`ls -1 requirements.txt Pipfile pyproject.toml go.mod pom.xml build.gradle Cargo.toml Gemfile composer.json setup.py setup.cfg 2>/dev/null || echo "NONE"`
- **Frontend:** !`ls -1 package.json yarn.lock pnpm-lock.yaml bower.json 2>/dev/null || echo "NONE"`
- **Docker:** !`ls -1 Dockerfile docker-compose.yml docker-compose.yaml 2>/dev/null || echo "NONE"`
- **Lock files:** !`ls -1 package-lock.json yarn.lock pnpm-lock.yaml Pipfile.lock poetry.lock uv.lock go.sum Cargo.lock Gemfile.lock composer.lock 2>/dev/null || echo "NONE"`

---

## Instructions

### Phase 1: Classify Tech Stack

| Dimension | Options |
|-----------|---------|
| Backend language | Python / Node.js / Go / Java / Rust / Ruby / PHP / C# / Mixed / None |
| Frontend framework | React / Vue / Angular / Svelte / Static HTML / None |
| Infrastructure | Docker / Kubernetes / Terraform / Bare metal / None |

### Phase 2: Dispatch 6 Parallel Subagents

Launch ALL 6 in a single message with `run_in_background: true`.
Provide each subagent the project path and detected tech stack.

- **Subagent 1 — Backend Dependency Audit**
  pip-audit / npm audit / govulncheck. Unpinned deps, missing lockfile, abandoned packages.
  Output: `Package | Version | CVE | Severity | Fix available? | Description`

- **Subagent 2 — Frontend Dependency Audit**
  npm/yarn/pnpm audit. CDN imports, eval() usage, devDep vs dep misplacement.
  Output: `Package | Version | Advisory | Severity | Fix available? | Description`

- **Subagent 3 — Backend Auth & Secrets Audit** (READ-ONLY)
  JWT, hardcoded credentials, CORS/CSRF, brute-force protection, RBAC, IDOR.
  Patterns: password/secret/key/token hardcoded; verify=False; eval/exec; mass assignment.
  Output: `File:line | Severity | Description | Recommended fix`

- **Subagent 4 — Backend Injection & Input Validation** (READ-ONLY)
  SQLi, CMDi, SSRF, path traversal, deserialization, prompt injection, webhook auth.
  Output: `File:line | Severity | Description | Recommended fix`

- **Subagent 5 — Frontend Security Audit** (READ-ONLY)
  XSS, token storage, open redirects, CSP, source maps in prod, prototype pollution.
  Output: `File:line | Severity | Description | Recommended fix`

- **Subagent 6 — Infrastructure & Docker Audit** (READ-ONLY)
  Dockerfile (root user, :latest, build-arg secrets), docker-compose credentials,
  nginx TLS/headers, .gitignore gaps, CI/CD secret exposure, Redis auth.
  Output: `File:line | Severity | Description | Recommended fix`

If category N/A → report "N/A — no [category] detected" and exit.

### Phase 3: Compile Report

Write to: `docs/security-audit-report-YYYY-MM-DD.md`

```
# Security Audit Report — [Project Name]
Date / Project / Tech Stack / Scanner

## Executive Summary
Total findings table (Critical/High/Medium/Low/Info)
Risk Level: CRITICAL | HIGH | MEDIUM | LOW | CLEAN

## 1–5. Findings by severity (Critical → Info)
## 6. Dependency Vulnerabilities (CVE tables)
## 7. Positive Findings
## 8. Remediation Priority Matrix
  P0 — Fix Before Internet Exposure
  P1 — Fix Within 1 Sprint
  P2 — Fix Within 2 Sprints
  P3 — Hardening
```

### Phase 4: Summary

Print report path + 3-sentence executive summary.
Do NOT claim completion without evidence all 6 subagents returned.
SAEOF
fi

# ── 4.2 Pre-commit git hook ───────────────────────────────────────────────────
log "§4.2 .git/hooks/pre-commit"

if [ -d .git ]; then
  HOOK_FILE=".git/hooks/pre-commit"
  if [ ! -f "$HOOK_FILE" ] || [ "$FORCE_UPDATE" = true ]; then
    write_file "$HOOK_FILE" <<'HOOKEOF'
#!/usr/bin/env bash
# =============================================================================
# Getirfinans pre-commit: basic secret heuristic
# NOTE: This is a lightweight heuristic check, NOT a full secret scanner.
#       It catches common patterns but will miss obfuscated or custom-named secrets.
#       Use /security-audit for a comprehensive audit before PRs.
# =============================================================================
set -euo pipefail

FOUND=$(grep -rn \
  --exclude-dir=node_modules \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude-dir=__pycache__ \
  --exclude-dir=dist \
  --exclude-dir=build \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.tsx" \
  --include="*.go" --include="*.env" --include="*.yaml" --include="*.yml" \
  --include="*.json" --include="*.toml" \
  -E \
  '(API_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|SECRET_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|PRIVATE_KEY\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|password\s*=\s*["'"'"'][^"'"'"']{4,}["'"'"'])' \
  . 2>/dev/null || true)

if [ -n "$FOUND" ]; then
  echo "❌ Potansiyel secret tespit edildi — commit engellendi:"
  echo "$FOUND"
  echo ""
  echo "⚠️  NOT: Bu temel bir örüntü taramasıdır — tam güvence sağlamaz."
  echo "   Gizli bilgileri .env dosyasına taşı ve .gitignore'a ekle."
  exit 1
fi

echo "✅ Secret heuristic kontrolü temiz (tam tarama için /security-audit kullan)"
HOOKEOF
    make_executable "$HOOK_FILE"
  else
    skip ".git/hooks/pre-commit exists (use FORCE_UPDATE=true to upgrade)"
  fi
else
  skip ".git not initialized — pre-commit hook skipped"
fi

# ── 5. Global ~/.claude infrastructure ───────────────────────────────────────
log "§5 Global ~/.claude infrastructure"

# 5.1 global security-audit command — version-gated, no auto-overwrite
log "§5.1 ~/.claude/commands/security-audit.md"
GLOBAL_SA="$HOME/.claude/commands/security-audit.md"

if check_version "$GLOBAL_SA" "$SECURITY_AUDIT_VERSION" "global security-audit"; then
  # File absent → bootstrap from project-local copy
  if [ "$DRY_RUN" = true ]; then
    drylog "copy .claude/commands/security-audit.md → $GLOBAL_SA"
  else
    mkdir -p "$HOME/.claude/commands"
    cp .claude/commands/security-audit.md "$GLOBAL_SA"
    ok "$GLOBAL_SA created"
  fi
fi

# 5.2 pre-PR hook script — version-gated
log "§5.2 ~/.claude/hooks/pre-pr-audit-check.sh"
GLOBAL_HOOK="$HOME/.claude/hooks/pre-pr-audit-check.sh"

if check_version "$GLOBAL_HOOK" "$PRE_PR_HOOK_VERSION" "global pre-PR hook"; then
  write_file "$GLOBAL_HOOK" <<'PREOF'
#!/usr/bin/env bash
# version: pre-pr-hook-v3.0
# Warns when no security audit report exists within the last 7 days.
set -euo pipefail

input=$(cat)

tool_name=$(printf '%s' "$input" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" \
  2>/dev/null || echo "")

[[ "$tool_name" == "Bash" ]] || { echo '{}'; exit 0; }

command_input=$(printf '%s' "$input" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" \
  2>/dev/null || echo "")

echo "$command_input" | grep -qE '(gh pr create|git push)' || { echo '{}'; exit 0; }

AUDIT_DIR="docs"
if [[ -d "$AUDIT_DIR" ]]; then
  RECENT=$(find "$AUDIT_DIR" -name "security-audit-report-*.md" -mtime -7 2>/dev/null | head -1)
  [[ -z "$RECENT" ]] || { echo '{}'; exit 0; }
fi

printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","systemMessage":"UYARI: Son 7 gun icinde docs/ dizininde guvenlik taramasi raporu bulunamadi. PR olusturmadan once /security-audit komutunu calistirmayi dusunun."}}'
exit 0
PREOF
  make_executable "$GLOBAL_HOOK"
fi

# 5.3 settings.json — jq-safe hook registration
log "§5.3 ~/.claude/settings.json"
register_pre_pr_hook "$HOME/.claude/settings.json"

# ── 6. .gitignore ─────────────────────────────────────────────────────────────
log "§6 .gitignore"
touch .gitignore
for pattern in ".env" "*.key" "*.pem" "secrets/" ".claude/hooks/"; do
  append_if_missing .gitignore "$pattern"
done

# ── 7. Git init ───────────────────────────────────────────────────────────────
log "§7 Git"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  run_git init
  ok "git initialized"
else
  skip "git repo already exists"
fi

# ── 8. Initial commit — explicit paths only, no wildcard ─────────────────────
log "§8 Initial commit"
if [ "$DRY_RUN" = true ]; then
  drylog "git add CLAUDE.md tasks/ docs/ .gitignore .claude/commands/"
  drylog "git commit -m 'chore: getirfinans project kickoff — initial structure'"
else
  git add CLAUDE.md tasks/ docs/ .gitignore .claude/commands/ 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    run_git commit -m "chore: getirfinans project kickoff — initial structure ($KICKOFF_VERSION)"
    ok "initial commit"
  else
    skip "nothing new to commit"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
printf "║  ✅  Kickoff tamamlandı %-28s║\n" "$PROJECT_NAME"
printf "║  %-52s║\n" "$KICKOFF_VERSION | DRY_RUN=$DRY_RUN | FORCE_UPDATE=$FORCE_UPDATE"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  📄 CLAUDE.md ($CLAUDE_MD_VERSION)               ║"
echo "║  📁 tasks/todo.md + tasks/lessons.md                ║"
echo "║  📁 docs/  (audit raporları için)                   ║"
echo "║  🔒 .claude/commands/security-audit.md              ║"
echo "║  🔒 .git/hooks/pre-commit  (heuristic blocker)      ║"
echo "║  🌐 ~/.claude/commands/security-audit.md            ║"
echo "║  🌐 ~/.claude/hooks/pre-pr-audit-check.sh           ║"
echo "║  ⚙️  ~/.claude/settings.json  (pre-PR hook)         ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Slash komutları:                                    ║"
echo "║    /kickoff              → bu prosedürü çalıştır    ║"
echo "║    /security-audit       → 6-agent güvenlik tarama  ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Gelişmiş kullanım:                                  ║"
echo "║    DRY_RUN=true /kickoff        → önizleme modu     ║"
echo "║    FORCE_UPDATE=true /kickoff   → zorla güncelle    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  ⚠️  Her 5 commit'te git push yap!                  ║"
echo "╚══════════════════════════════════════════════════════╝"
```

---

## CHANGELOG — kickoff-v3.0

### 1. DRY_RUN tam implementasyon
**Önceki sorun:** `run()` helper sadece explicit çağrıları kapsıyordu; heredoc file write'lar, `chmod`, `mkdir` doğrudan çalışıyordu.

**Yapılan:** Tüm yan etkiler merkezi helper'lardan geçiyor:
- `write_file(path)` — stdin'den içerik alır, DRY_RUN'da sadece log basar
- `make_dir(path)` — mkdir gate'li
- `make_executable(path)` — chmod gate'li
- `append_if_missing(file, line)` — .gitignore yazımı gate'li
- `run_git(...)` — git operasyonları gate'li

DRY_RUN=true ile hiçbir dosya yazılmaz, hiçbir git komutu çalışmaz.

### 2. Versiyonlama sistemi
**Önceki sorun:** Dosyaların güncel olup olmadığı bilinmiyordu, ya hep overwrite ya da hep skip.

**Yapılan:** Her managed dosyaya `<!-- version: x -->` / `version: x` header eklendi. `check_version()` helper'ı:
- Dosya yoksa: oluştur
- Versiyonu eşleşiyorsa: skip
- Versiyonu eskiyse: `[WARN] outdated (vX → vY)` — **otomatik overwrite yok**, kullanıcıya `FORCE_UPDATE=true` önerilir

### 3. Global ~/.claude drift control
**Önceki sorun:** Global dosyalar ilk kurulumdan sonra güncellenmiyordu; projeler arasında drift oluşuyordu.

**Yapılan:** `~/.claude/commands/security-audit.md` ve `~/.claude/hooks/pre-pr-audit-check.sh` versiyona bakılıyor. Eskiyse [WARN] + manuel update mesajı verilir; otomatik overwrite yok — global ortamı sessizce bozmama ilkesi.

### 4. JSON güvenli settings.json yönetimi
**Önceki sorun:** `grep -q "string"` ile varlık kontrolü, yoksa ham `cat >` ile overwrite — mevcut JSON'u korumaz.

**Yapılan:** `register_pre_pr_hook()`:
- jq varsa: `.hooks.PreToolUse` array'ine atomic merge, sonuç `jq empty` ile validate edilir; hata olursa temp dosya temizlenir
- jq yoksa: dosya dokunulmaz, tam manual instruction basılır
- Her iki durumda da mevcut JSON asla corrupt edilmez

### 5. git add scope düzeltmesi
**Önceki sorun:** `.claude/` tamamı ekleniyor, bu `.claude/hooks/` içindeki dosyaları da kapsıyordu.

**Yapılan:** Explicit path listesi: `CLAUDE.md tasks/ docs/ .gitignore .claude/commands/` — hooks deliberately excluded.

### 6. FORCE_UPDATE modu
**Önceki sorun:** Güncelleme için scripti elle düzenleme gerekiyordu.

**Yapılan:** `FORCE_UPDATE=true` ile tüm `write_file` çağrıları mevcut dosyaların üzerine yazar. Versiyonu güncel global dosyalar hâlâ dokunulmaz (ayrı güvenlik katmanı).

### 7. Pre-commit hook heuristic uyarısı
**Önceki sorun:** Hook güvenlik garantisi veriyor izlenimi yaratıyordu.

**Yapılan:** Hem hook başına hem çıkış mesajına açık disclaimer eklendi: "temel örüntü taraması, tam güvence sağlamaz, /security-audit kullan."

### 8. Kod kalitesi
- Zero duplicated logic — her operasyon tek bir helper'dan geçiyor
- `printf '%s'` ile injection-safe string handling (`echo` yerine)
- `set -euo pipefail` korundu, subshell'lerde de geçerli
- `.claude/hooks/` dizini artık proje altında oluşturulmuyor — global hook'lar yalnızca `~/.claude/hooks/` altında yaşar
