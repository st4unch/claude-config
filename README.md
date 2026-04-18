# claude-config

Claude Code yapilandirmasini makineler arasi guvenle paylasmak icin repo.

## Hizli Baslangic (Yeni Bilgisayarda)

```bash
# 1. Repoyu klonla
git clone git@github.com:st4unch/claude-config.git ~/.claude/claude-config

# 2. Sync scriptini calistir
cd ~/.claude/claude-config && ./sync.sh pull

# 3. z.ai token sorulacak — girin
# 4. Yeni Claude session baslatin
```

## Dosya Yapisi

```
claude-config/
├── sync.sh                          # Pull/Push/Diff scripti
├── CLAUDE.md                        # Claude davranis kurallari
├── commands/
│   ├── switch-provider.sh           # Provider toggle betigi (switch komutu)
│   └── zai-provider.template.json   # z.ai ayar sablonu (token yok)
├── hooks/
│   ├── rm-guard.sh                  # rm -rf koruma hooku
│   └── sandbox-guard.sh             # Dizin erisim sinirlama hooku
├── skills/
│   ├── frontend-design/SKILL.md     # Frontend tasarim skill'i
│   ├── project-auditor/SKILL.md     # Mevcut proje audit — read-only, /tasks/ altina task uretir
│   └── project-architect/SKILL.md   # Yeni proje mimari planlama — ADR + scaffold tasks uretir
├── settings.json                    # ORNEK ONLY — makineye ozel, sync edilmez
└── projects/                        # ORNEK ONLY — makineye ozel, sync edilmez
```

## Ne Paylasilir, Ne Paylasilmaz

| Dosya | Paylasilir mi? | Neden |
|-------|----------------|-------|
| `CLAUDE.md` | Evet | Davranis kurallari |
| `hooks/` | Evet | Guvenlik hooklari |
| `skills/` | Evet | Ozel skill'ler |
| `commands/switch-provider.sh` | Evet | Provider toggle betigi |
| `settings.json` | **Hayir** | Her makinenede farkli (izinler, eklentiler) |
| `zai-provider.json` | **Template** | Token gizlenerek sadece sablon paylasilir |
| `projects/` | **Hayir** | Proje bellekleri makineye ozel |

## Komutlar

```bash
# Repodan dosyalari indir
./sync.sh pull

# Local dosyalari repoya gonder
./sync.sh push

# Farklari goster
./sync.sh diff

# Ilk kurulum (yeni bilgisayarda)
./sync.sh setup
```

## Switch Komutu

Provider arasi gecis yapar:

```bash
switch          # Toggle: z.ai <-> Claude
switch zai      # z.ai'e gec
switch claude   # Claude'a gec
```

`switch` komutu `~/.local/bin/switch` konumuna kurulur.

## Guvenlik

- API tokenlari repoda **tutmaz** — sadece `.template.json` olarak saklanir
- `sync.sh push` komutu zai-provider.json'daki token'i otomatik gizler
- `settings.json` ve `projects/` asla sync edilmez
