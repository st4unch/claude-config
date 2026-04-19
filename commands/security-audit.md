---
description: Run a comprehensive security audit with 6 parallel subagents. Auto-detects tech stack and produces a detailed vulnerability report.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList
version: security-audit-v3.0
---

# Security Audit -- 6-Agent Parallel Scan

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
- Subagent 2 -- Frontend Dependency Audit: npm/yarn/pnpm audit. CDN imports, dynamic code execution patterns. Output: Package | Version | Advisory | Severity | Fix available? | Description
- Subagent 3 -- Backend Auth & Secrets Audit (READ-ONLY): JWT, hardcoded credentials, CORS/CSRF, brute-force, RBAC, IDOR. Patterns: password/secret/key/token hardcoded; verify=False; dynamic execution; mass assignment. Output: File:line | Severity | Description | Fix
- Subagent 4 -- Backend Injection & Input Validation (READ-ONLY): SQLi, CMDi, SSRF, path traversal, unsafe deserialization, prompt injection, webhook auth, template injection. Output: File:line | Severity | Description | Fix
- Subagent 5 -- Frontend Security Audit (READ-ONLY): XSS, token storage, open redirects, CSP, source maps, prototype pollution, WebSocket auth. Output: File:line | Severity | Description | Fix
- Subagent 6 -- Infrastructure & Docker Audit (READ-ONLY): Dockerfile (root, :latest, build-arg secrets), docker-compose, nginx, .gitignore, CI/CD, Redis auth, TLS, CORS. Output: File:line | Severity | Description | Fix

If category N/A -> report "N/A" and exit.

### Phase 3: Compile Report
Write to: docs/security-audit-report-YYYY-MM-DD.md
Structure: Executive Summary (severity table + risk level) -> Critical/High/Medium/Low/Info findings -> Dependency CVE tables -> Positive findings -> Remediation Priority Matrix (P0-P3)

### Phase 4: Summary
Print report path + 3-sentence executive summary. Do NOT claim completion without evidence all 6 subagents returned.
