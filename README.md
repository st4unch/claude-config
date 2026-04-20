# claude-config

Claude Code yapılandırma dosyaları — hooks, skills, slash komutları ve ayarlar.

## Kurulum

```bash
# Repoyu klonla
git clone git@github.com:st4unch/claude-config.git ~/.claude/claude-config

# Dosyaları ~/.claude/ altına kopyala
cd ~/.claude/claude-config && ./sync.sh pull

# Yeni bir Claude session başlat
```

## sync.sh

```bash
./sync.sh pull    # Repodan ~/.claude/ altına indir
./sync.sh push    # Yerel değişiklikleri repoya gönder
./sync.sh diff    # Farkları göster
```

## Dosya Yapısı

```
claude-config/
├── CLAUDE.md                            # Claude davranış kuralları ve iş akışı
├── settings.json                        # Plugin'ler, hook'lar, izinler
├── commands/
│   ├── kickoff.md                       # /kickoff — yeni proje başlangıç prosedürü
│   ├── security-audit.md               # /security-audit — 6-agent paralel güvenlik taraması
│   └── find-bugs.md                    # /find-bugs — kod tabanı bug ve risk taraması
├── hooks/
│   ├── rm-guard.sh                     # rm -f / rm -rf komutlarını onaya sorar
│   ├── sandbox-guard.sh                # Dizin erişimini sınırlar
│   ├── pre-pr-audit-check.sh           # PR öncesi güvenlik raporu kontrolü
│   └── session-hook.sh                 # Oturum takip hooku
├── scripts/
│   ├── telegram-notify.sh              # Claude durağında Telegram bildirimi
│   ├── telegram-approval.py            # İzin isteklerini Telegram'dan onayla
│   └── claude-sessions.sh             # Aktif Claude oturumu monitörü
└── skills/
    ├── frontend-design/SKILL.md        # Üretim kaliteli frontend arayüz tasarımı
    ├── project-auditor/SKILL.md        # Mevcut proje production-readiness denetimi
    ├── project-architect/SKILL.md      # Yeni proje uçtan uca mimari tasarımı
    └── issue-finder/SKILL.md           # Kod tabanında bug, mantık ve güvenlik riski tespiti
```

## Skills

| Skill | Tetikleyici | Ne Yapar |
|-------|-------------|----------|
| `frontend-design` | "arayüz yap", "component oluştur" | Production-grade UI üretir |
| `project-auditor` | "projeyi denetle", "audit et" | Read-only production-readiness raporu |
| `project-architect` | "mimari planla", "yeni proje" | Uçtan uca teknik mimari tasarlar |
| `issue-finder` | `/find-bugs`, "bug ara", "hata bul" | Kod tabanını tarar, `/tasks/missing-architectures/` altına dosya yazar |

## Hooks

| Hook | Olay | Davranış |
|------|------|----------|
| `rm-guard.sh` | PreToolUse (Bash) | `rm -f` / `rm -rf` içeren komutları onaya sorar |
| `sandbox-guard.sh` | PreToolUse (Bash) | İzin verilmeyen dizinlere erişimi engeller |
| `pre-pr-audit-check.sh` | PreToolUse (Bash) | `gh pr create` / `git push` öncesi 7 günlük audit raporu kontrolü |
| issue-finder prompt hook | PostToolUse (Write\|Edit) | Kaynak kod yazıldığında kritik güvenlik sorunlarını anında işaretler |

## Telegram Entegrasyonu

`scripts/` altındaki betikler Claude'u Telegram'a bağlar:

- **`telegram-notify.sh`** — Claude durduğunda veya bildirim ürettiğinde mesaj gönderir
- **`telegram-approval.py`** — İzin isteklerini Telegram'a yönlendirir, onay/ret orada verilir

Kimlik bilgileri commit edilmez; `~/.claude/channels/telegram/.env` dosyasından yüklenir.
