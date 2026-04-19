---
name: project-architect
description: Design end-to-end production-ready architecture for a new solo developer project. Use when the user starts a new project or plans significant architectural changes. Triggers on "new project", "start a project", "plan the architecture", "what stack", "production ready tasarla", "yeni proje başlatıyorum", "mimariyi konuşalım", "stack seçimi". Solo developer context — default to end-to-end design, NOT MVP. Research current best practices per project (training data may be stale). Output: ADRs, stack selection, scaffold plan with install.sh/update.sh, and task list under /tasks/scaffold/.
---

# Project Architect

Yeni bir solo developer projesi için end-to-end production-ready mimari kuran skill. Her projede sıfırdan research yapar, opinion'lu tek bir stack önerir.

## Temel İlkeler

- **MVP değil end-to-end.** Sonradan eklemesi zor olan şeyler (auth, migration, logging, update) baştan kurulur.
- **Her projede fresh research.** Preferred stack dosyası yok — web search zorunlu.
- **Opinion'lu, tek öneri.** Trade-off açıkla ama karar ver.
- **No .env in production.** Entrypoint auto-generate veya setup wizard.
- **In-app management.** UI'lı projelerde admin panel + self-update zorunlu.
- **Full lifecycle scripts.** `install.sh`, `update.sh`, `rollback.sh`, `backup.sh`, `health-check.sh`.
- **Solo dev realizmi.** Blue-green, restore testi, disaster recovery gibi enterprise ritüelleri zorla aramıyoruz.

## İş Akışı

### 1. Discovery

**Zorunlu sorular:**
- Uygulama türü? (internal tool, public SaaS, API, background job)
- Kullanıcı profili? (sadece sen, küçük ekip, public)
- State var mı? (DB, file storage, cache)
- Hassas veri? (PII, credentials, regulated)
- UI var mı?
- Deployment hedefi? (VPS, cloud, self-hosted)

**Koşullu (cevaplara göre):**
- Auth türü
- Async iş
- Real-time gereksinim

**Yapma:**
- "MVP mi?" sorma — default end-to-end
- "Hangi framework?" sorma — research edip öner

### 2. Research

Web search ile:
- Stack adaylarının güncel durumu (maintained, son 6 ay commit)
- Bilinen güvenlik sorunları
- Self-update, one-click install, admin panel destekleyen araçlar öncelikli

### 3. Proposal — Tek Net Öneri

Her kategoride karar + 1-2 cümle gerekçe:

- Runtime/framework
- Data layer (DB + migration tool)
- Auth (gerekiyorsa)
- Deployment (reverse proxy, TLS, container)
- Secret management (NO .env in prod)
- Backup (ne, nereye)
- Observability (logging, error tracking, uptime)
- Update mechanism
- Admin panel (UI'lı projelerde)

### 4. ADR Üretimi

`docs/adr/` klasörü oluştur:

- `0001-stack-selection.md`
- `0002-auth-strategy.md` (varsa)
- `0003-deployment-strategy.md`
- `0004-observability-strategy.md`
- `0005-backup-strategy.md`
- `0006-update-rollback-strategy.md`
- `0007-initial-setup-strategy.md`
- `0008-admin-panel-strategy.md` (UI'lı projelerde)

Format:

```markdown
# ADR-NNNN: [Başlık]
**Tarih**: YYYY-MM-DD
**Durum**: Accepted

## Context
## Decision
## Rationale
## Alternatives Considered
## Consequences
```

### 5. Scaffold Task'leri

`/tasks/scaffold/` klasörü, sıralı task dosyaları (project-auditor formatıyla aynı):

**Zorunlu core task'ler:**
- `001-repo-init.md` — git init, .gitignore, README
- `002-docker-setup.md` — Dockerfile + docker-compose
- `003-install-script.md` — install.sh
- `004-update-script.md` — update.sh (backup + pull + migrate + health check + rollback on fail)
- `005-rollback-script.md` — rollback.sh
- `006-entrypoint-no-env.md` — entrypoint auto-generate secrets, NO .env
- `007-migration-setup.md` — numbered migrations, up/down
- `008-backup-script.md` — backup.sh + cron (restore test zorunlu değil)
- `009-health-check.md` — /health endpoint
- `010-structured-logging.md` — pino/structlog + request ID
- `011-error-tracking.md` — Sentry/Glitchtip init
- `012-uptime-monitoring.md` — Uptime Kuma
- `013-pre-commit-gitleaks.md` — secret scanning

**UI'lı projeler için ek:**
- `014-admin-panel.md` — admin UI scaffold
- `015-self-update.md` — in-app update mekanizması
- `016-setup-wizard.md` — first-run setup UI

### 6. Özet

`/tasks/PROJECT_PLAN.md` — ADR linkleri + scaffold sırası + kritik kararların özeti.

Kullanıcıya:

> "Plan hazır. `docs/adr/` altında NN karar, `/tasks/scaffold/` altında NN task. `PROJECT_PLAN.md`'den başla. Hangi task'le başlayalım?"

## Davranış Notları

- Türkçe + İngilizce jargon
- Research atlanmaz
- Opinion'lu ol
- MVP savunusuna karşı end-to-end hatırlat
- Enterprise overkill'den kaçın (restore testi, disaster recovery, vb.)
