---
name: project-architect
description: Design end-to-end production-ready architecture for a new solo developer project, or plan significant architectural changes. Use when the user starts a new project, says "new project", "start a project", "let's plan the architecture", "what stack should I use", "production ready tasarla", "yeni proje başlatıyorum", "mimariyi konuşalım", "stack seçimi". This skill assumes solo developer context — default to end-to-end design, NOT MVP. Research current best practices per project (do not rely on stale preferences). Output: decision log (ADRs), stack selection, scaffold plan with install.sh/deploy.sh/update.sh, and initial task list under /tasks/.
---

# Project Architect

Yeni bir solo developer projesi için end-to-end production-ready mimari kurgulayan skill. Her projede sıfırdan research yapar, opinion'lu tek bir stack önerir, scaffold planını `/tasks/` altına yazar.

## Temel İlkeler

- **MVP değil end-to-end.** Solo developer sonradan eklemek için değil, baştan doğru kurmak için zaman harcar. Auth, migration discipline, logging format, update mekanizması baştan planlanır.
- **Her projede yeniden research.** Preferred stack dosyası yok. Training data stale olabilir, web search zorunlu.
- **Opinion'lu, tek öneri.** "Şu ya da bu" yok, "şu, çünkü..." var.
- **No .env in production.** Kullanıcı kurulumda `.env` doldurmasın — setup wizard veya entrypoint script ile secret'lar auto-generate olur veya ilk UI'dan alınır.
- **In-app management.** UI'lı projelerde admin panel + self-update + package management arayüzden yapılabilir olmalı.
- **Full lifecycle scripts.** `install.sh`, `deploy.sh`, `update.sh`, `rollback.sh`, `backup.sh`, `restore.sh`, `health-check.sh` zorunlu.

## İş Akışı

### 1. Discovery

Şu soruları sor (genel değil, ayırt edici olanlar):

**Zorunlu:**
- Bu uygulama ne tür? (internal tool, public SaaS, API service, background job, mobile backend)
- Kullanıcı profili? (sadece sen, küçük ekip, public)
- State tutuyor mu? (DB türü, file storage, cache)
- Hassas veri var mı? (PII, credentials, regulated)
- UI var mı, yoksa headless mi?
- Deployment hedefi? (VPS, cloud, self-hosted)

**Koşullu (ilk cevaplara göre):**
- Auth türü
- Multi-tenant mı
- Async iş var mı
- Real-time gereksinim

**Yapma:**
- "MVP mi full mu?" sorma. Default end-to-end.
- "Hangi framework?" sorma. Sen research edip öner.

### 2. Research

Web search kullanarak:
- Stack adaylarının güncel durumu
- Bilinen güvenlik sorunları, breaking change'ler
- Ekosistem değişiklikleri
- Self-update, one-click install, admin panel destekleyen araçlar öncelikli

**Research kriterleri:**
- Maintained (son 6 ay commit)
- Güvenlik vulnerability yok
- Docker-friendly
- Self-hosted-friendly
- Documentation kaliteli

### 3. Proposal — Opinion'lu Karar

Her kategoride tek net öneri + 1-2 cümle gerekçe:

- Runtime/framework
- Data layer (DB + migration tool)
- Auth
- Deployment (reverse proxy, TLS, container orchestration)
- Secret management (NO .env in prod — setup wizard veya entrypoint)
- Backup (ne, nereye, hangi sıklıkla)
- Observability (logging, error tracking, uptime, metrics)
- Update mechanism (blue-green, health-check-gated, rollback)
- Admin panel (UI'lı projelerde zorunlu)

### 4. ADR Üretimi

`docs/adr/` klasörü oluştur. Her kritik karar için ayrı markdown:

Minimum ADR seti:
- `0001-stack-selection.md`
- `0002-auth-strategy.md`
- `0003-deployment-strategy.md`
- `0004-observability-strategy.md`
- `0005-backup-strategy.md`
- `0006-update-rollback-strategy.md`
- `0007-initial-setup-strategy.md` (NO .env in prod detayı)
- `0008-admin-panel-strategy.md` (UI'lı projelerde)

ADR formatı:

```markdown
# ADR-NNNN: [Başlık]

**Tarih**: YYYY-MM-DD
**Durum**: Accepted

## Context
[Karar neden gündemde]

## Decision
[Ne seçildi]

## Rationale
[Neden bu seçildi]

## Alternatives Considered
[Hangi alternatifler elendi, neden]

## Consequences
[Trade-off'lar]
```

### 5. Scaffold Plan — `/tasks/` Altına Task'ler

`/tasks/scaffold/` klasörü oluştur. Her scaffold adımı için bir task:

Zorunlu scaffold task'leri:
- `001-repo-init.md` — git init, .gitignore, README, LICENSE
- `002-docker-setup.md` — Dockerfile, docker-compose.yml
- `003-install-script.md` — install.sh (sıfırdan kurulum)
- `004-deploy-script.md` — deploy.sh (ilk production)
- `005-update-script.md` — update.sh (backup + pull + migrate + health check + rollback)
- `006-rollback-script.md` — rollback.sh
- `007-backup-script.md` — backup.sh + restore.sh + cron
- `008-health-check.md` — /health endpoint + health-check.sh
- `009-entrypoint-setup-wizard.md` — NO .env — entrypoint auto-generate + setup wizard
- `010-migration-setup.md` — migration tool, numbered files, up/down
- `011-structured-logging.md` — pino/structlog/winston + request ID middleware
- `012-error-tracking.md` — Sentry/Glitchtip init
- `013-uptime-monitoring.md` — Uptime Kuma integration
- `014-log-aggregation.md` — Dozzle (minimum) + rotation
- `015-pre-commit-hooks.md` — gitleaks, lint, format
- `016-dependency-management.md` — Renovate/Dependabot config
- `017-admin-panel.md` — (UI'lı projelerde) admin panel scaffold
- `018-self-update.md` — (UI'lı projelerde) in-app update mekanizması

Her task dosyası `project-auditor`'daki format ile aynı.

### 6. Özet

`/tasks/PROJECT_PLAN.md` dosyası — ADR'lara link, scaffold task sırası, kritik kararların özeti.

Kullanıcıya:

> "Mimari planı hazır. `docs/adr/` altında NN karar, `/tasks/scaffold/` altında NN scaffold task'i var. `PROJECT_PLAN.md`'den başlayabilirsin. Hangi task'ten başlamak istersin?"

## Davranış Notları

- Türkçe açıklama + İngilizce jargon
- Research adımı atlanmaz — web search zorunlu
- Opinion'lu ol, kararsız kalma
- MVP savunma — kullanıcı "MVP yapayım" dese bile end-to-end ilkesini hatırlat
- Stack seçimi self-update, one-click install, no-env-setup destekleyen araçlara öncelik
