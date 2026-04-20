---
name: issue-finder
description: Use when asked to find bugs, review code for issues, audit a project for problems, or identify risks in an existing codebase. Triggers on "code review", "audit this project", "find bugs", "review this code", "any problems here", "bug ara", "hata bul", "issue bul", "mantık hatası", "uygulamamı analiz et", "neler yanlış", "risk var mı". Read-only — never modifies code, never generates patches.
---

# Issue Finder

## Overview

Analyzes an existing codebase and surfaces real, actionable issues across four categories: Runtime Bugs, Logical Errors, Business Logic Issues, and Security Risks. Produces findings with file+line evidence and writes task files to `/tasks/missing-architectures/`. **Strictly read-only — never modifies source code.**

## Operating Principles

- **Evidence-based only** — every finding must cite file + line, or mark as "Flow-level" when no single line applies
- **No hallucination** — never invent code or assume behavior not visible in source
- **Risk-oriented** — ignore style, framework preferences, subjective best practices
- **Signal over noise** — fewer high-quality findings beat many low-quality ones
- **Solo developer realism** — skip enterprise concerns (compliance frameworks, academic SOLID purity, near-zero-probability edge cases)

## Context Gathering

Ask clarifying questions ONLY if:
- Entry point cannot be identified
- No runnable code is visible
- Tech stack cannot be inferred

In ALL other cases, proceed with scanning immediately. Do NOT ask about preferences, style, or scope when these can be inferred from the codebase.

## Scan Priority Order

Always scan in this exact order, regardless of project scope:

1. **Auth / security files** — login, session, token, middleware, permissions, auth
2. **Payment / financial logic** — checkout, billing, pricing, tax, invoice, transaction
3. **External integrations** — API clients, webhooks, third-party SDKs, HTTP clients
4. Entry points — main, app, server, index, wsgi, asgi
5. Routes / controllers
6. Business logic / service layer
7. Data access layer
8. Frontend state management & validation

Categories 1–3 are always scanned first regardless of scope or project type.

## Scan Categories

### A. Runtime Bugs

Scan for:
- Null / undefined access without null checks
- Unawaited async calls, unhandled promise rejections
- Race conditions (shared mutable state, parallel writes)
- Type coercion producing unexpected values
- Array index out of bounds
- Silent catch blocks (empty body or bare `pass`)
- Missing required environment variables at startup
- No timeouts on external HTTP calls
- Resource leaks (unclosed files, DB connections, streams)

### B. Logical Errors

Scan for:
- AND/OR conditions swapped
- State inconsistency (flag set but never cleared, or cleared too early)
- Unused return values (especially errors and status codes)
- Execution order assumptions that may not hold
- Non-idempotent operations called multiple times
- Cache staleness (stale reads, missing invalidation)
- Wrong variable scope (closure capturing wrong variable)
- Mutation during iteration
- Unreachable branches caused by logic error (not just dead code style)

### C. Business Logic Issues

Scan for:
- Incorrect calculations (off-by-one, wrong formula, float precision in money)
- Authorization flaws (wrong role checked, ownership not verified)
- Data integrity issues (missing cascades, orphaned records)
- Misleading UI states (loading spinner never dismissed, wrong status shown)
- Undefined edge cases — zero, null, negative, maximum, empty collection
- Validation mismatch between frontend and backend
- Partial success flows with no rollback or compensation
- Concurrent modification of shared resources
- Time / timezone bugs (naive datetimes, DST edge cases, clock skew)

### D. Security Issues

#### D1 — Code-Level Security (MUST always detect and report in full)

- Authentication bypass (routes missing auth middleware, logic shortcuts)
- Injection — SQL, command, template, NoSQL, LDAP
- Hardcoded secrets (API keys, passwords, tokens in source or config)
- Broken authorization (IDOR, privilege escalation, missing ownership checks)
- Insecure deserialization

#### D2 — Architecture-Level Security (OPTIONAL — max 2 sentences total, not per item)

Mention briefly only:
- Rate limiting
- CORS configuration
- Cryptography policy

Do NOT deep-dive D2. After 2 sentences combined, immediately recommend `project-auditor` for structural security review.

## Severity Model

| Severity | Criteria |
|----------|----------|
| **Critical** | Crash, data loss, security vulnerability, financial miscalculation |
| **High** | Wrong output, user misled, authorization flaw with limited impact |
| **Medium** | Edge-case failure, degraded behavior |
| **Low** | Non-breaking improvement |

**Rule:** If unsure between two severity levels, pick the lower one. Critical is reserved for real, verifiable danger only.

## Confidence Model

Every finding must include a Confidence indicator, independent of severity:

| Confidence | Meaning |
|------------|---------|
| **High** | Directly verifiable in code — clear, unambiguous evidence |
| **Medium** | Strong signal but depends on runtime behavior or unseen context |
| **Low** | Pattern-based suspicion — requires human verification |

A Critical finding can have Low confidence. Always mark it explicitly.

## De-duplication Rule

If the same root cause appears in multiple files:
- Create a **single** issue entry
- List all affected files under it
- Create ONE task file for the group

Example: missing null check across 8 files → 1 ISSUE-ID, 1 task file, all 8 files listed inside.

## Finding Formats

### Critical / High Format

```
[ISSUE-XXX] <Short descriptive title>
Category: Bug | Logic | Business | Security
File(s): path/to/file.ext:line  (or list of files if de-duplicated)
Severity: Critical | High
Confidence: High | Medium | Low

**What**
Clear description of what the problem is.

**Why it matters**
Concrete impact — data loss, wrong output, security breach, financial error, etc.

**Example scenario**
A realistic scenario where this causes failure.

**Suggested direction**
High-level remediation approach. No code, no patches.
```

### Medium / Low Format

```
[ISSUE-XXX] <Short title> | Category | File:line | Severity | Confidence
One or two sentences describing the problem and its impact.
```

## Task File Generation

### Setup

If `/tasks/missing-architectures/` does not exist, create it before writing any file.

### Critical and High Findings — One File Each

**Filename:** `issue-XXX-short-slug.md`

**Template:**

```markdown
---
id: ISSUE-XXX
title: <Short descriptive title>
status: todo
risk_level: critical | high
invasive: false
effort_hours: <estimate>
source: issue-finder
created: <YYYY-MM-DD>
category: bug | logic | business | security
severity: critical | high
confidence: high | medium | low
---

## Finding

<Full Critical/High finding block>

## Acceptance Criteria

- [ ] <Specific verifiable condition 1>
- [ ] <Specific verifiable condition 2>
- [ ] <Specific verifiable condition 3>

## Compliance Check

<!-- To be filled when resolving -->
```

### Medium and Low Findings — Single Aggregate File

Filename: `issue-finder-low-priority.md`

```markdown
# Issue Finder — Low Priority Findings

## Medium

- [ ] [ISSUE-XXX] File:line — Description (Confidence: X)

## Low

- [ ] [ISSUE-XXX] File:line — Description (Confidence: X)
```

## Task File Cap

**Maximum task files per scan: 25** (Critical + High individual files combined).

If Critical + High findings exceed 25:
- ✅ Create task files for **Critical** findings only
- ⚠️ Summarize all High findings in a single overflow file: `issue-finder-high-overflow.md`
- The output summary must mention the overflow file

## Architecture Scope Boundary

If architecture-level gaps are detected (missing logging, no backups, no observability, no migration discipline, no health checks):
- Mention them — max **2 sentences total** across all gaps combined
- Recommend `project-auditor` immediately
- Do NOT create task files for architecture gaps — those belong to `project-auditor`

## Hard Execution Constraints

This skill WILL NOT:
- ❌ Fix code
- ❌ Generate patches or diffs
- ❌ Modify any source file
- ❌ Add or modify tests
- ❌ Expand scope to refactoring or feature work
- ❌ Give generic framework advice

If the user requests fixes during execution, respond with exactly:

> "Issue Finder is read-only. I've documented the finding in the task file. To implement the fix, start a new session and reference the task file ID."

## Scope Boundaries

This skill is NOT for:
- Academic code quality (DRY, SOLID, clean code principles)
- Framework migration planning
- Full architecture reviews → use `project-auditor`
- Performance profiling
- Test coverage analysis

## Output Summary

After completing the scan, always output this block:

```
## Scan Summary

Files scanned: X
Total issues: X (Critical: X | High: X | Medium: X | Low: X)
Confidence distribution: High: X | Medium: X | Low: X

Top 3 Issues:
1. [ISSUE-001] <title> — Critical, Security, High Confidence
2. [ISSUE-002] <title> — High, Business, Medium Confidence
3. [ISSUE-003] <title> — Critical, Bug, Low Confidence

Task files created: X
[If cap triggered: High-priority overflow → tasks/missing-architectures/issue-finder-high-overflow.md]
```

Do NOT repeat full finding content in the summary — it is already in the task files.
