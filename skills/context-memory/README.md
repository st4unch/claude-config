# context-memory

Claude Code için **slash komutu + skill + PreCompact hook** paketi.

İki iş yapar:

1. **`/context_memory`** — projeyi frontend/backend/database/infra demeden analiz edip `.claude/memories/` altına **kalıcı kategori dosyaları** oluşturur. Hangi kategorilerin gerektiğini proje yapısına bakıp Claude karar verir.

2. **PreCompact hook** — context ~%95'e ulaşıp auto-compact tetiklendiğinde compact'ı durdurur, Claude'a o oturumda öğrenilenleri kategori dosyalarına **işletir** ve bir oturum özeti yazdırır. Ancak ondan sonra compact'a izin verir.

Net etki: proje hakkındaki bilgi oturumdan oturuma **birikir**, compact sonrası sıfırlanmaz.

---

## Dosya yapısı (üretilen)

```
.claude/memories/
├── 00-index.md              # Navigasyon
├── project-structure.md     # Üst düzey yapı + akış
├── frontend.md              # (varsa — Claude karar verir)
├── backend.md               # (varsa)
├── database.md              # (varsa)
├── api.md                   # (varsa)
├── infra.md                 # (varsa)
├── tests.md                 # (varsa)
└── _sessions/
    └── 2026-04-24_143052_auth-refactor.md  # oturum özetleri
```

Kategori dosyaları **uzun ömürlü** — proje yapısı + domain bilgisi + dikkat edilmesi gereken noktalar. Her oturumda güncellenir (yeniden yazılmaz).

Session dosyaları **oturum bazlı** — o oturumun hedefi, kararlar, açık sorunlar, sonraki adım.

---

## Çalışma akışı

### İlk kurulum (manuel)

```
/context_memory
```

Claude `analyze_project.py`'yi çalıştırır, projenin yapısını anlar (monorepo mu, Next.js mi, Django mi, hangi klasörler ne iş yapar), sonra uygun kategori dosyalarını `.claude/memories/` altına yazar.

### Oturum sırasında

Hiçbir şey yapmana gerek yok. Sen kodla, Claude çalış.

### Auto-compact tetiklendiğinde (varsayılan: **subprocess mode**)

1. Claude Code auto-compact başlatır.
2. Hook `pre_compact_gate.sh` compact'ı durdurur.
3. Hook **ayrı bir `claude -p` süreci** (subprocess) başlatır — ana oturumun context'ini kullanmaz, kesmez.
4. Ana Claude sana çok kısa bir mesaj atar: "memory arka planda oluşturuluyor, 30-60 sn sonra `/compact`'ı tekrar dene".
5. Subprocess arka planda:
   - `.claude/memories/` yoksa ANALYZE + UPDATE, varsa sadece UPDATE çalıştırır
   - Kategori dosyalarını `str_replace` ile günceller
   - `_sessions/` altına özet yazar
6. Memory hazır olduğunda sen `/compact` yazarsın → hook taze memory'yi görür → compact çalışır.

Sonraki oturumda Claude `.claude/memories/` altındaki dosyaları okuyarak projeye hızla oryante olur.

**Subprocess'i kapatmak istersen:** `CLAUDE_CTX_MEMORY_MODE=inline` ortam değişkenini set et. O zaman eski davranışa (ana Claude memory'yi kendisi yazar) döner.

**`claude` CLI yoksa:** Hook otomatik olarak inline mode'a düşer.

---

## Kurulum

### 1. Paketi kopyala

**Proje bazlı:**
```bash
mkdir -p .claude/skills .claude/commands
cp -r context-memory .claude/skills/
cp context-memory/commands/context_memory.md .claude/commands/
chmod +x .claude/skills/context-memory/scripts/*.sh
chmod +x .claude/skills/context-memory/scripts/*.py
```

**Kullanıcı geneli (tüm projelerde):**
```bash
mkdir -p ~/.claude/skills ~/.claude/commands
cp -r context-memory ~/.claude/skills/
cp context-memory/commands/context_memory.md ~/.claude/commands/
chmod +x ~/.claude/skills/context-memory/scripts/*.sh
chmod +x ~/.claude/skills/context-memory/scripts/*.py
```

### 2. Hook'u ekle

`.claude/settings.json` (proje) veya `~/.claude/settings.json` (kullanıcı) aç, `hooks.PreCompact` girişini ekle:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/.claude/skills/context-memory/scripts/pre_compact_gate.sh"
          }
        ]
      }
    ]
  }
}
```

Kullanıcı geneli kurulumda `${CLAUDE_PROJECT_DIR}` yerine mutlak yol:
```json
"command": "bash ~/.claude/skills/context-memory/scripts/pre_compact_gate.sh"
```

### 3. Slash komutunun yerini doğrula

Claude Code custom command'ları `.claude/commands/` altından okur. `/context_memory` komutunun görünmesi için `context_memory.md`'nin doğru klasörde olduğundan emin ol. Claude Code'u yeniden başlat veya komut listesini yenile.

### 4. Test

```bash
# Projende, Claude Code oturumu aç
/context_memory
# → kategori dosyaları oluşmalı, .claude/memories/'e bak

# Biraz çalış, sonra:
/compact
# → ilk sefer bloklanmalı, Claude memory'yi güncellemeli
# → tekrar /compact → bu sefer geçmeli
```

---

## Yapılandırma

`scripts/pre_compact_gate.sh` içinde:

- `MEMORY_DIR_REL=".claude/memories"` — memory klasör yolu
- `FRESHNESS_SECONDS=300` — "taze" sayılma eşiği (varsayılan 5 dk)

Uzun oturumlarda `FRESHNESS_SECONDS`'ı artırmak faydalı olabilir (örn. 900 = 15 dk).

### Subprocess mode env değişkeni

Hook iki modda çalışabilir:

| Ortam değişkeni | Davranış |
|---|---|
| `CLAUDE_CTX_MEMORY_MODE=subprocess` (varsayılan) | Memory'yi arka planda ayrı `claude -p` süreci yazar. Ana oturum kesilmez. |
| `CLAUDE_CTX_MEMORY_MODE=inline` | Ana Claude memory'yi kendisi yazar (eski davranış). `claude` CLI yoksa otomatik bu moda düşer. |

Hem hook hem subprocess çalışırken `.claude/memories/.subprocess.log` dosyasında log tutulur. Subprocess çalışırken lock dosyası: `.claude/memories/.subprocess.lock` (otomatik temizlenir).

---

## Manuel kullanım

`/context_memory` dışında şu ifadelerle de skill tetiklenir:
- "Projeyi analiz edip memory oluştur"
- "Memory dosyalarını yenile"
- "Oturum özetini `.claude/memories/`'ye kaydet"
- "Bağlamı koru, compact gelmeden özet yaz"

---

## Dosya içerikleri neye benzer

**Kategori dosyası (`frontend.md` örneği):**

```markdown
# Frontend

**Konum:** `frontend/`
**Stack:** Next.js 14 App Router, TypeScript, Tailwind, Zustand
**Sorumluluğu:** Web istemci — SSR sayfalar + client bileşenler, backend API'ye istek atar.

## Giriş noktaları
- `frontend/src/app/layout.tsx` — kök layout, auth provider burada
- `frontend/src/app/page.tsx` — landing sayfası

## Dosya haritası
- `src/components/` — UI bileşenleri
- `src/lib/api.ts` — backend client wrapper (fetch + hata dönüşümü)
- `src/stores/` — Zustand store'ları

## Önemli kavramlar
- **Session:** httpOnly cookie, `/api/me` ile doğrulanır (JWT localStorage'da değil)
- **FeatureFlag:** `src/lib/flags.ts` — runtime, rollout için

## Dikkat edilmesi gerekenler
- `app/api/` sadece proxy — asıl backend `backend/` altında
- `src/legacy/` — eski class component'ler, ellemeyin

## Son güncelleme
2026-04-24 14:30 (session: auth-refactor) — auth flow güncellendi.
```

**Session dosyası (`_sessions/2026-04-24_143052_auth-refactor.md` örneği):**

```markdown
# httpOnly cookie tabanlı auth'a geçiş tamamlandı

**Tarih:** 2026-04-24 14:30
**Trigger:** auto-compact
**Etkilenen kategoriler:** frontend, backend

## Hedef
localStorage JWT'den httpOnly cookie + CSRF token'a geçiş.

## Özet
Backend tarafında `auth middleware` yazıldı, cookie'den token alıp
doğruluyor. Frontend'de `useAuth()` hook'u refactor edildi —
localStorage artık kullanılmıyor.

## Alınan kararlar
- CSRF için double-submit pattern, custom header + cookie karşılaştırma
- Refresh token şimdilik yok (sonraki sprint)

## Açık sorunlar
- [ ] E2E test yazılmadı
- [ ] Refresh token rotation yapılmalı

## Kritik bağlam
- Middleware `req.user`'ı set eder, downstream handler'lar buna güvenir
- Logout sadece cookie siler, sunucu tarafında session tablosu YOK
```

---

## Sorun giderme

**Hook çalışmıyor gibi.**
- `claude --debug` ile başlat, hook log'larını gör.
- `settings.json`'daki path doğru mu?
- Script `chmod +x` edilmiş mi?

**Her `/compact` bloklanıyor.**
- Memory dosyası oluşmuş mu? `ls -lt .claude/memories/`
- Sistem saati + mtime farkı `FRESHNESS_SECONDS`'tan küçük olmalı.
- Subprocess mode'daysan `tail .claude/memories/.subprocess.log` ile logu incele.

**Subprocess başlatılıyor ama memory dosyası oluşmuyor.**
- `.claude/memories/.subprocess.log` dosyasına bak. Büyük olasılıkla:
  - `claude -p` oturum/auth hatası veriyor (mevcut Claude Code oturumuna giriş yapmış olmalısın)
  - `--dangerously-skip-permissions` flag'i desteklenmiyor (sürümüne göre değişebilir). Bu durumda `build_memory_subprocess.sh` içinde flag'i `--allowedTools "Read,Write,Edit,Bash"` ile değiştir
  - Skill yolu bulunamıyor (proje kökünde `.claude/skills/context-memory/` olduğundan emin ol)

**Subprocess kilidi takıldı.**
- Subprocess crash olursa stale lock kalabilir. `rm .claude/memories/.subprocess.lock` ile temizle.
- Hook bir sonraki çalışmasında stale lock'u otomatik tespit edip temizler (PID yaşıyor mu diye bakar).

**Subprocess'i tamamen kapatmak istiyorum.**
- `.claude/settings.json` hook komutunu şöyle değiştir:
  ```json
  "command": "CLAUDE_CTX_MEMORY_MODE=inline bash ${CLAUDE_PROJECT_DIR}/.claude/skills/context-memory/scripts/pre_compact_gate.sh"
  ```

**`/context_memory` tanınmıyor.**
- `.claude/commands/context_memory.md` mevcut mu?
- Claude Code oturumunu yeniden başlat.

**`jq` hatası.**
- Script `jq` varsa kullanır, yoksa grep fallback devreye girer. İkisinde de çalışır.

**Claude Code sürümüm `{"decision":"block"}` desteklemiyor.**
- Erken 1.x sürümlerinde PreCompact bloklama kısıtlıydı. En güncele geç. Alternatif: gate script'teki JSON çıktısını `echo "$REASON" >&2; exit 2` ile değiştir.

---

## Dosya yapısı (paketin kendisi)

```
context-memory/
├── SKILL.md                            # Claude'a modları öğreten rehber
├── README.md                           # Bu dosya
├── commands/
│   └── context_memory.md               # /context_memory slash komutu
├── scripts/
│   ├── pre_compact_gate.sh             # PreCompact hook (dispatcher)
│   ├── build_memory_subprocess.sh      # Arka plan claude -p launcher
│   ├── analyze_project.py              # Proje yapısı çıkarıcı (ANALYZE için)
│   └── extract_transcript_summary.py   # Transcript metadata (UPDATE için)
└── hooks/
    └── settings.example.json           # Hook yapılandırma örneği
```
