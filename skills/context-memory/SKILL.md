---
name: context-memory
description: Proje için kalıcı, kategori bazlı memory dosyaları oluşturur ve günceller. İki moda sahiptir: (1) ANALYZE — kullanıcı `/context_memory` slash komutunu çağırdığında veya "projeyi analiz edip memory oluştur" dediğinde projeyi baştan tarar, frontend/backend/database/infra gibi kategorileri kendisi tespit edip `.claude/memories/` altına kategori dosyaları yazar. (2) UPDATE — PreCompact hook auto-compact başlatmadan önce tetiklendiğinde, o oturumda öğrenilen bilgileri ilgili kategori dosyalarına işler VE bir oturum özeti yazar. Manuel tetikleyiciler: "memory oluştur", "/context_memory", "projeyi analiz et", "oturum özetini kaydet", "bağlamı koru". Compact bağlam kaybını önler ve proje bilgisi birikir.
---

# context-memory

Projenin uzun ömürlü hafızasını `.claude/memories/` altında tutar. Compact sonrası bağlam sıfırlandığında, bu klasördeki dosyalar Claude'un projeyi hızla yeniden kavramasını sağlar.

İki mod vardır:

- **ANALYZE** — projeyi baştan tara, kategori dosyalarını oluştur (ilk kurulum veya yenileme)
- **UPDATE** — oturumda öğrenilenleri mevcut kategori dosyalarına işle + oturum özeti yaz (compact öncesi)

Hangi modda çalıştığını tetikleyicisinden anla:

| Tetikleyici | Mod |
|---|---|
| `/context_memory` slash komutu | ANALYZE |
| Kullanıcı "projeyi analiz et", "memory dosyalarını oluştur" der | ANALYZE |
| PreCompact hook mesajı ("auto-compact tetiklendi") | UPDATE |
| Kullanıcı "oturum özetini kaydet" der | UPDATE (session-only) |
| `.claude/memories/` boş VE hook tetiklenmiş | Önce ANALYZE, sonra UPDATE (aynı turda) |

---

## Dosya yapısı

```
.claude/memories/
├── 00-index.md              # Navigasyon + proje özet (her zaman)
├── project-structure.md     # Üst düzey yapı (her zaman)
├── frontend.md              # Kategori dosyası (varsa)
├── backend.md               # (varsa)
├── database.md              # (varsa)
├── api.md                   # (varsa — REST/GraphQL)
├── infra.md                 # (varsa — Docker/K8s/Terraform)
├── tests.md                 # (varsa)
├── auth.md                  # (varsa — ayrı modül ise)
├── <diğer-özel-kategoriler> # proje gerektiriyorsa
└── _sessions/
    └── YYYY-MM-DD_HHMMSS_<slug>.md  # oturum özetleri
```

**Kategori dosyalarının isimleri sabit değil.** Proje Django monolit ise `frontend.md` + `backend.md` yerine tek `django-app.md` daha uygun olabilir. Projeyi gördükten sonra karar ver — ama isimleri küçük harf, tire ile ayrılmış, tekil tut (`frontend.md`, `smart-contracts.md`, `data-pipeline.md`).

---

## ANALYZE modu

Amaç: proje kökünü tarayıp kategori dosyalarını **sıfırdan yazmak** veya **baştan yenilemek**.

### Adım 1 — Analiz verisini al

Önce yapısal ipuçlarını topla:

```bash
python3 <SKILL_DIR>/scripts/analyze_project.py
```

Script JSON döner: `top_level_dirs` (hint'leriyle), `manifests`, `signals`, `languages`, `readme_head`, `existing_memories`. Kategori kararını **bu JSON'a bakarak** ver — ezberden değil.

### Adım 2 — Kategorileri belirle

JSON'a bakıp hangi kategori dosyalarını yaratacağını sen kararlaştır. Kurallar:

- **Her projede:** `00-index.md` ve `project-structure.md` olmalı.
- **Varsa ayır:** `top_level_dirs` içindeki her belirgin sorumluluk bloğu bir kategori alır (örn. `frontend/`, `backend/`, `packages/common/`).
- **Monorepo ise:** `packages/` veya `apps/` alt öğelerinin her biri kendi dosyasını hak edebilir (örn. `app-web.md`, `app-mobile.md`, `pkg-shared-types.md`). Ama 10+ paket varsa gruplandır.
- **Küçük projelerde abartma:** 200 dosyalık tek-dil projede `project-structure.md` tek başına yeterli olabilir.
- **Cross-cutting concerns ayrıysa dosya ayır:** auth, db migration, deployment pipeline ayrı klasörlerdeyse ayrı dosyaları hak eder.

### Adım 3 — Dosyaları yaz

Her kategori dosyası şu şablonu izler:

```markdown
# <Kategori başlığı>

**Konum:** `frontend/` (veya ilgili yol(lar))
**Stack:** Next.js 14, TypeScript, Tailwind, Zustand
**Sorumluluğu:** 1-2 cümle — bu kod bloğu ne yapar, neye karar verir.

## Giriş noktaları
- `frontend/src/app/layout.tsx` — kök layout
- `frontend/src/app/page.tsx` — ana sayfa
- `frontend/next.config.js` — yapılandırma

## Dosya haritası
- `src/components/` — yeniden kullanılabilir UI bileşenleri
- `src/app/` — Next.js App Router sayfaları
- `src/lib/api.ts` — backend'e istek atan client wrapper
- `src/stores/` — Zustand store'ları

## Önemli kavramlar / domain dili
- **FeatureFlag**: `src/lib/flags.ts`'de tanımlı, UI'da `useFlag('name')` ile kullanılıyor
- **Session**: JWT değil, httpOnly cookie; `/api/me` endpoint'i ile doğrulanır

## Dikkat edilmesi gerekenler
- `app/api/` klasörü VAR ama sadece proxy — asıl backend `backend/`'de
- Eski class component'ler `src/legacy/` altında — dokunma
- Tailwind config extend edilmiş — renk paleti `theme.colors` özel

## Açık sorular / bilinmeyenler
- `useAuthShim` hook'unun neden gerekli olduğu net değil — sonra incele

## Son güncelleme
2026-04-24 14:30 (session: initial-analyze) — kategori dosyası ilk kez oluşturuldu.
```

`project-structure.md` özel — kategoriler arası ilişkiyi gösterir:

```markdown
# Proje Yapısı

**İsim:** MyApp
**Tip:** full-stack web app (monorepo değil, iki klasör)
**Ana teknolojiler:** Next.js 14, Node.js/Express, PostgreSQL, Docker

## Yüksek seviye akış
Kullanıcı → Next.js (frontend/) → Express API (backend/) → Postgres
Static asset'ler Vercel'de, API Fly.io'da, DB Neon'da.

## Klasör haritası
- `frontend/` → [frontend.md](./frontend.md)
- `backend/`  → [backend.md](./backend.md)
- `backend/migrations/` → [database.md](./database.md)
- `infra/` → [infra.md](./infra.md)
- `.github/workflows/` → [infra.md](./infra.md) içinde

## Build & çalıştırma
- Yerel: `docker compose up`
- Test: `pnpm test` (kökten)
- Deploy: main'e push → GitHub Actions → Vercel + Fly

## Kod sahipliği / konvansiyonlar
- TS strict mod açık; `any` commit'te reject edilir
- Conventional commits (feat:, fix:, chore:)
- PR merge öncesi migration review zorunlu
```

`00-index.md` her memory dosyasına link veren basit bir dizin:

```markdown
# Memory Index

Son analiz: 2026-04-24 14:30
Proje kökü: `/home/user/myapp`

## Kalıcı dosyalar
- [project-structure.md](./project-structure.md) — genel bakış, start here
- [frontend.md](./frontend.md) — Next.js client
- [backend.md](./backend.md) — Express API
- [database.md](./database.md) — Postgres şema + migrasyonlar
- [infra.md](./infra.md) — Docker, CI/CD, deploy

## Son oturumlar
- [_sessions/2026-04-24_143052_auth-refactor.md](./_sessions/2026-04-24_143052_auth-refactor.md)
```

### Adım 4 — Kullanıcıya özet ver

ANALYZE bitince kullanıcıya **kısa** bir özet ver:
- Hangi kategori dosyalarını oluşturdun
- Neden o kategorileri seçtin (1 cümle)
- Toplam kaç dosya yazıldı, nerede

---

## UPDATE modu

Amaç: **mevcut kategori dosyalarını değiştir, yeni bilgiyle geliştir** + oturum özeti yaz.

### Adım 1 — Mevcut memory var mı kontrol et

```bash
ls .claude/memories/*.md 2>/dev/null
```

**Yoksa**: önce ANALYZE modunu çalıştır (kategori dosyalarını oluştur), sonra UPDATE'e geç. Aynı tur içinde iki iş yapacaksın.

### Adım 2 — Transcript metadata'sını al (PreCompact tetiklemesinde)

Hook sana `transcript_path` vermişse:

```bash
python3 <SKILL_DIR>/scripts/extract_transcript_summary.py <transcript_path>
```

Çıktıdaki `files_touched`, `files_edited`, `files_created`, `commands_run` alanlarına bak. Bunlar hangi kategorileri güncelleyeceğinin ipucudur (örn. `frontend/src/...` dokunulmuş → `frontend.md` güncellenecek).

Manuel tetiklemede bu script'i çalıştırmana gerek yok — konuşmadan çıkar.

### Adım 3 — Hangi kategori dosyaları güncellenecek belirle

Oturumda:
- **Yeni bir dosya/modül tanındı mı?** → ilgili kategori dosyasının "Dosya haritası" bölümüne ekle
- **Yeni bir domain kavramı öğrenildi mi?** → "Önemli kavramlar" bölümüne ekle
- **Standart dışı bir konvansiyon keşfedildi mi?** → "Dikkat edilmesi gerekenler" bölümüne ekle
- **Kategori dosyasında yazan bir şey yanlış çıktı mı?** → ilgili satırı `str_replace` ile DÜZELT

**Agresif değil, incremental ol.** Tüm dosyayı yeniden yazma. `str_replace` ile sadece değişen bölümü güncelle. "Son güncelleme" satırını mutlaka yenile.

### Adım 4 — Oturum özetini yaz

Her UPDATE çağrısında `.claude/memories/_sessions/` altına bir dosya oluştur:

**Dosya adı:** `YYYY-MM-DD_HHMMSS_<kisa-slug>.md` (örn. `2026-04-24_143052_auth-refactor.md`)

**İçerik:**

```markdown
# <1 cümlelik özet>

**Tarih:** 2026-04-24 14:30
**Session ID:** <kısa id, hook verdiyse>
**Trigger:** auto-compact | manual
**Etkilenen kategoriler:** frontend, backend

## Hedef
Bu oturumda ne yapılmak istendi? 1-3 cümle.

## Özet
Yapılan işin akıcı anlatımı. 1-2 paragraf. Olgu odaklı.

## Alınan kararlar
- Karar 1 — gerekçe
- Karar 2 — gerekçe

## Değişen / oluşturulan dosyalar
- `frontend/src/auth/login.tsx` — redirect logic eklendi
- `backend/src/middleware/auth.ts` — JWT doğrulama eklendi

## Çalışan / çalışmayan yaklaşımlar
- ✅ httpOnly cookie + CSRF token çalıştı
- ❌ localStorage'da JWT → XSS riski, vazgeçildi

## Açık sorunlar / TODO
- [ ] Refresh token rotation henüz yok
- [ ] E2E test yazılmadı

## Kritik bağlam (compact sonrası şart)
- Auth middleware `req.user`'ı set ediyor, downstream handler'lar buna güveniyor
- Logout flow sadece cookie siliyor, server-side session tablosu YOK

## Sonraki adım
Refresh token rotasyonunu `backend/src/auth/refresh.ts` içine ekle.
```

### Adım 5 — Index'i güncelle

`00-index.md` dosyasının "Son oturumlar" bölümüne yeni session dosyasının linkini ekle. 10'dan fazla session biriktiyse en eskileri listeden çıkar (dosyayı silme — sadece index'ten kaldır).

### Adım 6 — Kullanıcıya bildir

UPDATE tamamlandıktan sonra kullanıcıya **3 cümleyi geçmeyen** bir onay ver:
1. Hangi kategori dosyaları güncellendi
2. Session dosyası nereye yazıldı
3. "Şimdi `/compact` komutunu tekrar çalıştır" (hook tetiklemesiyse)

---

## Üretim kuralları (her iki mod için)

**Zorunlu:**
- `.claude/memories/` klasörü yoksa `mkdir -p` ile oluştur (alt klasör `_sessions/` dahil).
- Dosya adlarında tire, küçük harf, ASCII slug kullan (Türkçe karakter OK ama slug kısmında değil).
- Her dosyanın sonunda `## Son güncelleme` satırı olsun — tarih + session bilgisi.

**İçerik kalitesi:**
- **Bilgi yoğun, anlatıcı değil.** "Kullanıcı şunu istedi" yerine "X yapısı şöyle çalışıyor."
- **Damıt, kopyalama.** Transcript'i aynen aktarma — özünü çıkar.
- **Dosya yollarını tam yaz** (proje kökünden).
- **Belirsizlikleri kaydet.** "X'in neden gerekli olduğu anlaşılmadı" — bu kıymetli.
- **Boş bölüm bırakma** — içerik yoksa `_Bu oturumda yok._` yaz, şablonu bozma.

**Hacim hedefi:**
- Kategori dosyaları: 50-200 satır (zamanla büyüyebilir, 400'ü aşarsa alt kategoriye böl)
- Session dosyaları: 40-120 satır
- `00-index.md`: 20-60 satır

---

## Yardımcı araçlar

- `scripts/analyze_project.py <root>` — proje yapısı JSON'u (ANALYZE için şart, UPDATE'te opsiyonel)
- `scripts/extract_transcript_summary.py <transcript>` — transcript metadata JSON'u (UPDATE hook tetiklemesinde)
- `scripts/pre_compact_gate.sh` — PreCompact hook'unun kendisi (Claude bunu çağırmaz, Claude Code çağırır)

---

## Referans: hook tetiklendiğinde gelen mesaj

PreCompact hook iki farklı şekilde tetiklenebilir. Hangisi olduğu reason mesajından anlaşılır:

### Durum 1: Subprocess modunda (ana Claude'u kesmez)

```
Arka planda memory oluşturmak için ayrı bir Claude süreci başlatıldı (state=...).
Kullanıcıya şunu söyle: "Context-memory arka planda çalışıyor (.claude/memories/'e
yazılıyor). 30-60 saniye sonra `/compact` komutunu tekrar çalıştır..."
Sadece bu bilgiyi ilet. SKILL'i ÇALIŞTIRMA, memory'yi sen yazma.
```

Bu durumda **skill'i ÇALIŞTIRMA**. Başka bir Claude süreci memory'yi yazıyor. Sen sadece kullanıcıya kısa bir bilgi ver ve sustur. Kendi context'ini ve odağını koru.

### Durum 2: Inline modunda (claude CLI yok veya kapatılmış)

```
[context-memory hook] Auto-compact tetiklendi. Compact engellendi.
UPDATE modunda çalış: ...
transcript_path: ...
session_id: ...
cwd: ...
Çalışma modu: inline
```

Bu durumda SKILL'i kendin çalıştır — yukarıdaki ANALYZE/UPDATE adımlarını takip et. Bitince kullanıcıya `/compact`'i tekrar çalıştırmasını söyle. **Kendin `/compact` çağırma.**
