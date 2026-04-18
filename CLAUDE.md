# Golden Rule

**Yapabiliyorsan sorma, yap.** Kullanıcıya onay sorma — doğrudan uygula ve sonucu bildir. Onay sadece geri dönüşü olmayan destructive işlemlerde (DB silme, prod force push) gerekli. Karar noktalarında en mantıklı olanı seç, uygula, sonra açıkla.

# Workflow Orchestration

### 1. Plan Node Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity
- Check vulnerabilities for used packages do not use packages that has critical vulnerabilities.
- Plan with Secure Coding logic.

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One tack per subagent for focused execution

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
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
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
- **Minimat Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **Version Management** : commit every change and after 5 commit push changes.

## Security Audit Policy

- Before creating any PR, remind the user to run `/security-audit` if no audit report exists within the last 7 days in `docs/security-audit-report-*.md`
- When adding new dependencies, check for known vulnerabilities before proceeding
- Never commit `.env` files, private keys, or credentials — BLOCK and warn
- When reviewing Docker/CI/CD configs, flag obvious security issues inline

## Security Audit Infrastructure — Auto-Bootstrap

At the **start of every new session**, silently verify the security audit infrastructure exists. If ANY file is missing, **create it from the blueprints below** without asking the user. This is a self-healing system — even on a fresh Claude Code install, these instructions contain everything needed to bootstrap the full security audit pipeline.

**Check order:** Run these checks only once per session (first user message). Use `ls` to verify existence — do NOT read the files.

### Check 1: Commands Directory + Slash Command

**Verify:** `~/.claude/commands/security-audit.md` exists
**If missing:** Create `~/.claude/commands/` directory and write the file with this exact content:

<details>
<summary>~/.claude/commands/security-audit.md — Full Content (click to expand)</summary>

````markdown
---
description: Run a comprehensive security audit on the current project with 6 parallel subagents. Auto-detects tech stack and produces a detailed vulnerability report.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList
---

# Security Audit — Automated 6-Agent Parallel Scan

## Project Context

- **Working directory:** $ARGUMENTS
- **Date:** !`date +%Y-%m-%d`
- **Project name:** !`basename $(pwd)`
- **Git status:** !`git log --oneline -3 2>/dev/null || echo "Not a git repo"`

## Tech Stack Detection

Detect what exists in this project:
- **Backend package files:** !`ls -1 requirements.txt Pipfile pyproject.toml go.mod pom.xml build.gradle Cargo.toml Gemfile composer.json setup.py setup.cfg 2>/dev/null || echo "NONE"`
- **Frontend package files:** !`ls -1 package.json yarn.lock pnpm-lock.yaml bower.json 2>/dev/null || echo "NONE"`
- **Dockerfiles:** !`ls -1 Dockerfile docker-compose.yml docker-compose.yaml 2>/dev/null || echo "NONE"`
- **Backend dirs:** !`ls -d backend/ server/ api/ app/ cmd/ internal/ pkg/ src/main/ 2>/dev/null || echo "NONE"`
- **Frontend dirs:** !`ls -d frontend/ client/ web/ src/components/ src/pages/ src/views/ public/ 2>/dev/null || echo "NONE"`
- **Infra configs:** !`ls -1 nginx.conf* .env.example k8s/ helm/ terraform/ .github/workflows/*.yml Procfile 2>/dev/null || echo "NONE"`
- **Lock files:** !`ls -1 package-lock.json yarn.lock pnpm-lock.yaml Pipfile.lock poetry.lock uv.lock go.sum Cargo.lock Gemfile.lock composer.lock 2>/dev/null || echo "NONE"`

---

## Instructions

You are running a **comprehensive security audit** on this project. Follow these phases exactly.

### Phase 1: Classify Tech Stack

From the detection results above, determine:

| Dimension | Options |
|-----------|---------|
| Backend language | Python / Node.js / Go / Java / Rust / Ruby / PHP / C# / Mixed / None |
| Frontend framework | React / Vue / Angular / Svelte / Static HTML / None |
| Infrastructure | Docker / Kubernetes / Terraform / Bare metal / None |
| Has backend? | yes / no |
| Has frontend? | yes / no |

### Phase 2: Dispatch 6 Parallel Subagents

Launch ALL 6 subagents **in a single message** using the Agent tool with `run_in_background: true`. If a category does not apply (e.g., no frontend), the subagent should report "N/A — no [category] detected in this project" and exit immediately.

Provide each subagent the **project working directory** and the **detected tech stack** so it knows what tools/commands to use.

---

#### Subagent 1: Backend Dependency Audit

```
You are auditing backend dependencies for security vulnerabilities.
Working directory: [PROJECT_PATH]
Tech stack: [DETECTED_BACKEND_LANG]

Tasks:
1. Read all dependency files (requirements.txt, pyproject.toml, go.mod, pom.xml, etc.)
2. Run the appropriate scanner:
   - Python: pip-audit (install if needed: pip install pip-audit)
   - Node.js: npm audit --json
   - Go: govulncheck ./...
   - Java: check dependencies against NVD
3. Check for unpinned dependencies (>=, *, latest)
4. Check for missing lockfile
5. Check for abandoned/deprecated packages
6. Flag packages installed outside main dependency file (Dockerfile RUN pip install, etc.)

Output format per finding:
- Package | Version | CVE ID(s) | Severity (CRITICAL/HIGH/MEDIUM/LOW) | Fix available? | Description

If no backend detected, report "N/A — no backend dependencies found" and exit.
```

#### Subagent 2: Frontend Dependency Audit

```
You are auditing frontend dependencies for security vulnerabilities.
Working directory: [PROJECT_PATH]
Tech stack: [DETECTED_FRONTEND]

Tasks:
1. Read package.json — check both dependencies and devDependencies
2. Run: npm audit (or yarn audit / pnpm audit)
3. Check for packages that should be in devDependencies but are in dependencies
4. Check for outdated packages with known security issues
5. Flag any CDN imports in HTML files
6. Check for eval() usage in dependency code if suspicious

Output format per finding:
- Package | Version | Advisory | Severity | Fix available? | Description

If no frontend detected, report "N/A — no frontend dependencies found" and exit.
```

#### Subagent 3: Backend Auth & Secrets Audit (READ-ONLY — do not run the app)

```
You are auditing authentication, authorization, and secrets management.
Working directory: [PROJECT_PATH]

Check ALL of these areas:
1. JWT/session implementation — algorithm, expiry, secret handling, revocation
2. Secret management — hardcoded credentials, encryption at rest, key derivation
3. Login flow — brute-force protection, account lockout, rate limiting
4. Authorization — privilege escalation, RBAC enforcement, IDOR
5. API key management — generation quality, storage, rotation
6. Password policy — hashing algorithm (bcrypt/argon2 vs md5/sha1), complexity
7. CORS/CSRF configuration
8. Config files — hardcoded secrets, insecure defaults, fallback values
9. Database models — sensitive data exposure, missing encryption
10. Middleware — security headers, auth enforcement

Search patterns:
- password, secret, key, token, credential (hardcoded values)
- verify=False, verify_ssl=False, CERT_NONE (TLS bypass)
- eval, exec, subprocess, os.system (code execution)
- setattr, getattr with user input (mass assignment)

Output per finding: File:line | Severity | Description | Recommended fix
```

#### Subagent 4: Backend Injection & Input Validation Audit (READ-ONLY)

```
You are auditing for injection vulnerabilities and input validation issues.
Working directory: [PROJECT_PATH]

Check ALL of these areas:
1. SQL Injection — raw SQL, string concatenation in queries, text(), f-strings in SQL
2. Command Injection — subprocess, os.system, os.popen, eval(), exec(), shell=True
3. SSRF — user-controlled URLs in HTTP requests, unrestricted fetches
4. Path Traversal — user input in file paths, open(), read(), write()
5. Deserialization — pickle, yaml.load (unsafe), marshal, unserialize
6. Input Validation — missing schema validation, overly permissive types, unbounded strings
7. Error Handling — stack traces leaked to users, internal details in responses
8. Logging — sensitive data (passwords, tokens, PII) in log output
9. File Upload — type/size validation, storage location, executable uploads
10. LLM/Agent Security — prompt injection, tool misuse, unrestricted tool access
11. Webhook Security — authentication, signature verification, replay protection
12. Template Injection — user input in template strings, format string attacks

Output per finding: File:line | Severity | Description | Recommended fix
```

#### Subagent 5: Frontend Security Audit (READ-ONLY)

```
You are auditing the frontend for security vulnerabilities.
Working directory: [PROJECT_PATH]

Check ALL of these areas:
1. XSS — dangerouslySetInnerHTML, v-html, innerHTML, document.write, unsanitized rendering
2. Auth token storage — localStorage vs httpOnly cookies, token handling
3. Hardcoded secrets — API keys, credentials, tokens in source code
4. CSRF protection — tokens, double-submit cookies, SameSite
5. Open redirects — window.location, navigate() with user-controlled params
6. CSP — Content-Security-Policy headers or meta tags
7. Auth flow — timing attacks, credential exposure, client-side-only guards
8. API client — interceptors, error handling info leaks, retry logic
9. SSE/WebSocket — authentication on persistent connections
10. State management — sensitive data in stores, persistence to localStorage
11. Source maps — enabled in production builds?
12. Dependency security — eval in deps, prototype pollution patterns

Output per finding: File:line | Severity | Description | Recommended fix

If no frontend detected, report "N/A" and exit.
```

#### Subagent 6: Infrastructure & Docker Security Audit (READ-ONLY)

```
You are auditing infrastructure, Docker, and deployment configuration.
Working directory: [PROJECT_PATH]

Check ALL of these areas:
1. Dockerfile — running as root, exposed secrets in build args, using :latest tags, unnecessary packages
2. docker-compose — hardcoded credentials, ports on 0.0.0.0, privileged mode, host mounts
3. Nginx/reverse proxy — security headers, rate limiting, TLS config, server_tokens, CSP
4. Environment files — .env committed to git, insecure defaults, real secrets in examples
5. .gitignore — sensitive files excluded? (.env, *.key, *.pem, secrets/)
6. Database config — default credentials, missing auth, exposed ports, TLS
7. Redis/cache — authentication, exposed ports, persistence settings
8. Deploy scripts — secret generation quality, hardening, systemd security
9. CI/CD — secret exposure in workflows, pinned action versions
10. TLS/SSL — certificate handling, cert files in repo, key strength
11. CORS — origin configuration, wildcard + credentials
12. Alembic/migrations — hardcoded database URLs

Output per finding: File:line | Severity | Description | Recommended fix

If no infrastructure configs detected, report "N/A" and exit.
```

---

### Phase 3: Compile Report

After ALL 6 subagents complete, create the report at:
**`docs/security-audit-report-YYYY-MM-DD.md`** (use actual date)

Create `docs/` directory if it does not exist.

**Report structure:**

```markdown
# Security Audit Report — [Project Name]

**Date:** YYYY-MM-DD
**Project:** [name]
**Tech Stack:** [detected]
**Scanner:** Claude Code 6-Agent Parallel Security Audit

## Executive Summary

Total findings: X
| Severity | Count |
|----------|-------|
| Critical | X |
| High     | X |
| Medium   | X |
| Low      | X |
| Info     | X |

## Risk Level: [CRITICAL / HIGH / MEDIUM / LOW / CLEAN]

---

## 1. Critical Findings
[Detailed findings with file:line, description, fix]

## 2. High Findings
[Detailed findings]

## 3. Medium Findings
[Table format]

## 4. Low Findings
[Table format]

## 5. Informational
[Table format]

## 6. Dependency Vulnerabilities
[Separate section with CVE tables for backend + frontend]

## 7. Positive Findings
[Things done well — no XSS, good gitignore, proper hashing, etc.]

## 8. Remediation Priority Matrix

### P0 — Fix Before Internet Exposure
[Top critical items with effort estimate]

### P1 — Fix Within 1 Sprint
[High items]

### P2 — Fix Within 2 Sprints
[Medium items]

### P3 — Hardening
[Low + Info items]
```

### Phase 4: Summary

Print the report file path and a 3-sentence executive summary. Do NOT claim completion without showing evidence that all 6 subagents returned.
````

</details>

---

### Check 2: Pre-PR Hook Script

**Verify:** `~/.claude/hooks/pre-pr-audit-check.sh` exists and is executable
**If missing:** Create it and run `chmod +x` on it. Full content:

```bash
#!/usr/bin/env bash
# Pre-PR security audit check
# Warns if no security audit report exists within the last 7 days
set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$tool_name" != "Bash" ]]; then
  echo '{}'
  exit 0
fi

command_input=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only check on PR creation or push commands
if ! echo "$command_input" | grep -qE '(gh pr create|git push)'; then
  echo '{}'
  exit 0
fi

# Check for recent audit report (within 7 days)
AUDIT_DIR="docs"
if [[ -d "$AUDIT_DIR" ]]; then
  RECENT=$(find "$AUDIT_DIR" -name "security-audit-report-*.md" -mtime -7 2>/dev/null | head -1)
  if [[ -n "$RECENT" ]]; then
    echo '{}'
    exit 0
  fi
fi

# No recent audit found — warn
cat <<'HOOKEOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","systemMessage":"UYARI: Son 7 gun icinde docs/ dizininde guvenlik taramasi raporu bulunamadi. PR olusturmadan once /security-audit komutunu calistirmayi dusunun."}}
HOOKEOF
exit 0
```

---

### Check 3: settings.json Hook Entry

**Verify:** `~/.claude/settings.json` contains the string `pre-pr-audit-check.sh` in the PreToolUse array
**If missing:** Add this entry to the `hooks.PreToolUse` array in `~/.claude/settings.json`:

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "bash ~/.claude/hooks/pre-pr-audit-check.sh",
      "statusMessage": "Guvenlik taramasi kontrolu..."
    }
  ]
}
```

**How it works:** This hook intercepts every Bash tool call. When the command contains `gh pr create` or `git push`, it checks for a `docs/security-audit-report-*.md` file less than 7 days old. If not found, it emits a Turkish warning message as a system message (soft nudge, does not block the command).

---

### When NOT to auto-check
- If the user explicitly says to skip or disable security audit checks
- If operating in a read-only or research-only session
- Do not check on every message — only at session start (first user message)
- If a subagent is running this check, skip it (subagents do not need the audit infra)