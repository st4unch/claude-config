---
name: project-auditor
description: Audit an existing project for production-readiness gaps without making any modifications. Use when the user asks to review, audit, or analyze an existing codebase for architectural, security, observability, deployment, or operational gaps. Triggers on phrases like "audit my project", "is my project production ready", "check for missing architecture", "review codebase", "find gaps", "projemi kontrol et", "eksikleri bul", "production ready mi", "mimari eksikler", or when analyzing an existing project for improvement opportunities. This skill is READ-ONLY for application code — it NEVER modifies, refactors, or makes invasive changes to the project being audited. It ONLY creates task documents under /tasks/ directory for later execution.
---

# Project Auditor

Mevcut bir projeyi production-readiness açısından değerlendirip eksikleri yapılandırılmış task dosyaları olarak `/tasks/missing-architectures/` altına yazan skill. Riskli değişiklikleri **asla** uygulamaz, sadece tespit eder ve dokümante eder.

## Temel İlke — NON-INVASIVE

Bu skill çalışırken **application code'una dokunmaz**. Sadece:
- Dosyaları okur (read-only)
- Bulgularını `/tasks/missing-architectures/` klasörüne markdown olarak yazar
- Varsa `tasks/todo.md`'yi update eder

**Yapmaz:**
- Kod refactor
- Migration, schema değişikliği
- Framework/library update
- Config/secret dosyalarına yazma
- `.env` oluşturma veya değiştirme
- Mevcut script'lerin davranışını değiştirme

## İş Akışı

### 1. Discovery — Projeyi Anla

Proje root'unda şu dosyaları oku ve mimari bir resim oluştur:

- `README.md`, `CLAUDE.md`
- `package.json`, `requirements.txt`, `Gemfile`, `go.mod`, `pyproject.toml`, vb.
- `docker-compose.yml`, `Dockerfile`
- `.github/workflows/`, `.gitlab-ci.yml`
- Mevcut `install.sh`, `deploy.sh`, `update.sh`, `backup.sh`, `health-check.sh` (varsa)
- `migrations/` klasörü
- `tasks/` klasörü (varsa mevcut todo'lar)
- `.env.example` (varsa)

Stack'i tespit et (language, framework, DB, deployment hedefi).

### 2. Gap Analysis — Production Hygiene Checklist

Şu kriterler üzerinden kontrol et ve her eksikliği not al:

**Deployment & Operations:**
- `install.sh` var mı? Sıfırdan yeni bir makinede kuruyor mu?
- `deploy.sh` var mı? İlk production deployment'ı tamamlıyor mu?
- `update.sh` var mı? Backup → pull → migrate → health check → rollback on fail akışı var mı?
- `rollback.sh` var mı?
- `health-check.sh` veya `/health` endpoint var mı?
- Blue-green veya health-check-gated deployment pattern var mı?

**Data Layer:**
- Migration discipline uygulanıyor mu? (numbered files, up/down, idempotent)
- Migration runner update script'ine entegre mi?
- `backup.sh` var mı, scheduled mi, off-site kopya alınıyor mu?
- `restore.sh` var mı ve test edilmiş mi?

**Security & Secrets:**
- `.env` production'da kullanılıyor mu? (KÖTÜ — initial setup wizard veya entrypoint'e geçilmeli)
- Secret'lar git history'de sızmış mı? (gitleaks ile tara)
- Default admin password enforce-change-on-first-login var mı?
- `.gitignore` secret patternlerini kapsıyor mu?
- Dependency vulnerability scan var mı? (npm audit, pip-audit, renovate/dependabot)

**Observability:**
- Structured logging var mı? (pino, structlog, winston — stack'e göre)
- Request ID / trace ID middleware var mı?
- Log aggregation var mı? (Dozzle minimum, Loki ideal)
- Error tracking var mı? (Sentry, Glitchtip, vb.)
- Uptime monitoring var mı? (Uptime Kuma veya eşdeğeri)

**Application Lifecycle:**
- Graceful shutdown var mı?
- Docker restart policy var mı?
- Initial setup wizard var mı (UI'lı projeler için)?
- Admin panel / in-app management var mı (UI'lı projelerde)?
- Self-update mekanizması var mı (UI'lı projelerde)?

**Development Workflow:**
- Pre-commit hook'lar var mı? (gitleaks, lint, format)
- Script'lerin test'i otomatik mi? (install.sh, deploy.sh, update.sh çalışır durumda mı)
- CI/CD config var mı?

### 3. Risk Classification

Her gap için risk/effort/invasiveness değerlendir:

- **risk_level**: `low` (non-invasive, yan yana eklenebilir) | `medium` (mevcut davranışı değiştirir ama geri alınabilir) | `high` (DB schema, auth, major refactor)
- **invasive**: `true` (uygulamaya dokunur) | `false` (observer/yanına eklenir)
- **effort_hours**: tahmini süre

### 4. Task Dosyalarını Yaz

`/tasks/missing-architectures/` klasörü yoksa oluştur. Her gap için bir dosya oluştur:

Dosya adı formatı: `NNN-kebab-case-title.md` (örnek: `001-structured-logging.md`)

Dosya içeriği:

```markdown
---
id: arch-NNN
title: [Başlık]
status: todo
risk_level: low|medium|high
invasive: true|false
effort_hours: N
category: deployment|data|security|observability|lifecycle|dev-workflow
created: YYYY-MM-DD
---

## Context
[Proje şu an neyi yapmıyor, bu eksik olmanın etkisi ne]

## Proposed Change
[Ne eklenmeli, nasıl]

## Non-Invasive Approach
[Mevcut davranışı değiştirmeden nasıl eklenir — non-invasive olanlar için]

## Acceptance Criteria
- [ ] Madde 1
- [ ] Madde 2

## Implementation Notes
[Hangi araç, hangi pattern, senin stack'ine uygun öneri]

## Compliance Check
<!-- Task tamamlandıktan sonra doldurulacak -->
- [ ] Implementation matches proposed change
- [ ] No breaking changes to existing behavior
- [ ] Documentation updated
- [ ] Tests pass
```

### 5. Özet Rapor

`/tasks/missing-architectures/_AUDIT_REPORT.md` dosyası oluştur:

```markdown
# Architecture Audit Report
**Date**: YYYY-MM-DD
**Project**: [proje adı]
**Stack**: [tespit edilen stack]

## Summary
- Total gaps identified: N
- Low risk (quick wins): N
- Medium risk (planned): N
- High risk (major work): N

## Quick Wins (non-invasive, <2hr each)
- [ ] [arch-001](001-structured-logging.md) — Structured logging
- [ ] ...

## Planned Improvements (medium risk)
- [ ] [arch-XXX](XXX-migration-discipline.md) — Migration discipline
- [ ] ...

## Major Work (high risk, separate planning)
- [ ] ...

## Recommendations
[Hangi sırayla gitmek mantıklı, neler paralel yapılabilir]
```

### 6. Kullanıcıya Dur

Skill'in işi burada biter. Task dosyaları yazıldıktan sonra kullanıcıya:

> "Audit tamamlandı. `/tasks/missing-architectures/` altında N gap bulundu. `_AUDIT_REPORT.md` dosyasını açıp öncelik sırasına bakabilirsin. Hangi task'i çalışmak istersen söyle, ayrı bir session'da üzerinde çalışalım."

**Task'leri çalıştırma, otomatik uygulama yapma.** İş burada biter.

## Davranış Notları

- Türkçe açıklama + İngilizce jargon (deployment, scaffold, endpoint, migration, vb.)
- Opinion'lu ol, "şu ya da bu" deme — net öneri ver
- Eksik tespit ederken "belki", "muhtemelen" gibi zayıflatıcı ifadelerden kaçın — ya var ya yok
- Stack'e göre araç öner (Node.js'te pino, Python'da structlog, vb.)
- Gap bulmakla kalma, **nasıl ekleneceğinin yolunu da yaz** — implementation notes kısmı boş kalmasın
