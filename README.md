# claude-config

Claude Code yapilandirmasini makineler arasi guvenle paylasmak icin repo.

## Hizli Baslangic (Yeni Bilgisayarda)

```bash
# 1. Repoyu klonla
git clone git@github.com:st4unch/claude-config.git ~/.claude/claude-config

# 2. Dosyalari indir
cd ~/.claude/claude-config && ./sync.sh pull

# 3. Yeni Claude session baslatin
```

## Mevcut Bilgisayarda Guncelleme

```bash
# Repo'daki degisiklikleri cek
cd ~/.claude/claude-config && git pull && ./sync.sh pull

# Local degisiklikleri repoya gonder
cd ~/.claude/claude-config && ./sync.sh push
```

## Dosya Yapisi

```
claude-config/
├── sync.sh                          # Pull/Push/Diff scripti
├── CLAUDE.md                        # Claude davranis kurallari
├── settings.json                    # Plugin'ler, hook'lar, izinler
├── commands/
│   ├── kickoff.md                   # Proje baslangic slash komutu
│   └── security-audit.md            # 6-agent guvenlik tarama komutu
├── hooks/
│   ├── rm-guard.sh                  # rm -rf koruma hooku
│   ├── sandbox-guard.sh             # Dizin erisim sinirlama hooku
│   └── pre-pr-audit-check.sh        # PR oncesi guvenlik tarama uyarisi
├── scripts/
│   ├── telegram-notify.sh           # Telegram bildirim betigi
│   ├── telegram-approval.py         # Telegram onay betigi
│   └── claude-sessions.sh           # Aktif Claude session monitoru
└── skills/
    ├── frontend-design/SKILL.md     # Frontend tasarim skill'i
    ├── project-auditor/SKILL.md     # Mevcut proje audit (read-only)
    └── project-architect/SKILL.md   # Yeni proje mimari planlama
```

## Ne Paylasilir, Ne Paylasilmaz

| Dosya | Paylasilir mi? | Neden |
|-------|----------------|-------|
| `CLAUDE.md` | Evet | Davranis kurallari |
| `settings.json` | Evet | Plugin'ler ve hook'lar |
| `hooks/` | Evet | Guvenlik hooklari |
| `scripts/` | Evet | Yardimci betikler |
| `commands/` | Evet | Slash komutlari |
| `skills/` | Evet | Ozel skill'ler |
| `settings.local.json` | **Hayir** | Makineye ozel izinler |
| `projects/` | **Hayir** | Proje bellekleri makineye ozel |

## Komutlar

```bash
# Repodan dosyalari indir
cd ~/.claude/claude-config && ./sync.sh pull

# Local dosyalari repoya gonder
cd ~/.claude/claude-config && ./sync.sh push

# Farklari goster
cd ~/.claude/claude-config && ./sync.sh diff

# Ilk kurulum (yeni bilgisayarda)
cd ~/.claude/claude-config && ./sync.sh setup
```

## Guvenlik

- `settings.local.json` ve `projects/` asla sync edilmez
- `hooks/pre-pr-audit-check.sh` — PR olusturmadan once guvenlik raporu olup olmadigini kontrol eder
- `hooks/rm-guard.sh` — `rm -rf` komutlarini onay isteyerek calistirir
