---
name: project-auditor
description: Audit an existing solo-developer project for production-readiness gaps without making any modifications. Use when the user asks to review, audit, or analyze an existing codebase for architectural, security, observability, or operational gaps. Triggers on phrases like "audit my project", "is my project production ready", "check for missing stuff", "review codebase", "find gaps", "projemi kontrol et", "eksikleri bul", "production ready mi", "mimari eksikler". This skill is READ-ONLY for application code — it NEVER modifies, refactors, or makes changes to the project being audited. It ONLY creates task documents under /tasks/missing-architectures/ for later manual execution.
---

# Project Auditor

Mevcut bir projeyi production-readiness açısından değerlendirip eksikleri yapılandırılmış task dosyaları olarak `/tasks/missing-architectures/` altına yazan skill. Kod'a dokunmaz, sadece tespit eder.

## Temel İlke — NON-INVASIVE

Bu skill çalışırken **application code'una dokunmaz**. Sadece dosyaları okur ve `/tasks/missing-architectures/` altına markdown yazar. Kod refactor, migration, config değişikliği yapmaz.

## Kapsam Notu

Solo developer için realistik bir checklist. "Backup restore testi", "off-site replica", "blue-green deployment" gibi enterprise pattern'leri kovalamayız. Odak: **gerçekten kullanılan, kaybolursa canın yanan şeyler**.

## İş Akışı

### 1. Discovery

Proje root'unda şu dosyaları oku:

- `README.md`, `CLAUDE.md`
- `package.json`, `requirements.txt`, `Gemfile`, `go.mod`, `pyproject.toml`
- `docker-compose.yml`, `Dockerfile`
- Mevcut script'ler: `install.sh`, `deploy.sh`, `update.sh`, `backup.sh`, `health-check.sh` (varsa)
- `migrations/` klasörü
- `.env.example` (varsa)
- `.gitignore`

Stack'i tespit et (language, framework, DB, deployment hedefi).

### 2. Gap Analysis — Pragmatik Checklist

**Deployment Scripts (kritik):**
- `install.sh` var mı? Sıfırdan kuruyor mu?
- `update.sh` var mı? Backup + pull + migrate + health check + fail-on-error akışı var mı?
- `rollback.sh` var mı veya update.sh içinde rollback logic'i var mı?
- Health check endpoint (`/health`) veya script var mı?

**Data Layer (kritik):**
- Migration discipline var mı? (numbered files, up/down — restore testi aramıyoruz, sadece pattern)
- `backup.sh` var mı ve scheduled çalışıyor mu? (restore test zorunlu değil, backup olması yeterli)

**Security (kritik):**
- `.env` production'da kullanılıyor mu? (kötü — entrypoint veya setup wizard'a geçmeli)
- `.gitignore` `.env`, secret patternlerini kapsıyor mu?
- Pre-commit hook'ta gitleaks var mı?
- Default admin password varsa ilk login'de değişmeye zorluyor mu?

**Observability (kritik):**
- Structured logging var mı? (pino/structlog/winston)
- Request ID / trace ID middleware var mı?
- Error tracking var mı? (Sentry, Glitchtip, free tier yeter)
- Uptime monitoring var mı? (Uptime Kuma veya eşdeğeri)

**Nice-to-have (zorunlu değil, var olsa iyi):**
- Log aggregation (Dozzle minimum)
- Dependency vulnerability scan (npm audit, pip-audit)
- Admin panel (UI'lı projelerde, update/config management için)
- Self-update mekanizması (UI'lı projelerde)

**Gündem dışı (solo dev için overkill — bunları aramayız):**
- Backup restore testi
- Off-site backup replica
- Blue-green deployment
- CI/CD (opsiyonel, flagla)
- Rate limiting (public endpoint hariç)
- GDPR/regulatory (hassas veri yoksa)
- Load testing
- Graceful shutdown detayları

### 3. Risk Classification

Her gap için:

- **risk_level**: `low` (non-invasive, yan yana eklenir) | `medium` (mevcut davranışı değiştirir) | `high` (DB schema, auth, major refactor — sadece rapor et, task yazma)
- **invasive**: `true` | `false`
- **effort_hours**: tahmin

### 4. Task Dosyalarını Yaz

`/tasks/missing-architectures/` klasörü yoksa oluştur. Her gap için:

Dosya adı: `NNN-kebab-case.md` (örn: `001-structured-logging.md`)

Format:

```markdown
---
id: arch-NNN
title: [Başlık]
status: todo
risk_level: low|medium|high
invasive: true|false
effort_hours: N
category: deployment|data|security|observability|nice-to-have
created: YYYY-MM-DD
---

## Context
[Ne eksik, ne etkisi var]

## Proposed Change
[Ne eklenmeli, hangi araç/pattern]

## Non-Invasive Approach
[Mevcut kod'a dokunmadan nasıl eklenir]

## Acceptance Criteria
- [ ] Madde 1
- [ ] Madde 2

## Implementation Notes
[Stack'e özel öneri, kütüphane seçimi]
```

### 5. Özet Rapor

`/tasks/missing-architectures/_AUDIT_REPORT.md`:

```markdown
# Audit Report — [Proje Adı]
**Date**: YYYY-MM-DD
**Stack**: [tespit edilen]

## Summary
Total: N | Low risk: N | Medium risk: N | High risk (info only): N

## Quick Wins (düşük risk, hızlı kazanç)
- [ ] [arch-001](001-xxx.md) — Başlık

## Planned (orta risk, planla)
- [ ] ...

## High Risk (sadece bilgi — manuel planlama gerekir)
- Başlık — neden riskli

## Öneriler
[Hangi sırayla gidilirse mantıklı]
```

### 6. Kullanıcıya Dur

Skill'in işi burada biter:

> "Audit tamamlandı. `/tasks/missing-architectures/` altında N gap bulundu. `_AUDIT_REPORT.md`'yi aç, önce quick win'lere bak. Hangi task'i çalışmak istersen söyle."

Task'leri çalıştırma, uygulama yapma.

## Davranış Notları

- Türkçe + İngilizce jargon (deployment, scaffold, migration, endpoint)
- Opinion'lu ol, "belki" "muhtemelen" deme
- Stack'e göre araç öner (Node → pino, Python → structlog)
- "Nasıl eklenir"i açık yaz — implementation notes boş kalmasın
- Enterprise pattern'leri dayatma — solo dev context'i
