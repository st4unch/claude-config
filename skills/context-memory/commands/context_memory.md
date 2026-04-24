---
description: Projeyi analiz edip .claude/memories/ altına kalıcı kategori dosyaları oluşturur veya yeniler (frontend, backend, database, infra vb.).
---

context-memory skill'ini **ANALYZE modunda** çalıştır.

Yapman gerekenler:

1. **Analiz verisini al:**
   ```bash
   python3 .claude/skills/context-memory/scripts/analyze_project.py
   ```
   (Skill farklı bir konumdaysa `~/.claude/skills/context-memory/scripts/analyze_project.py` dene.)

2. **JSON çıktısına bak**, özellikle:
   - `top_level_dirs` — hangi üst düzey klasörler var, hangilerinin `hint`'i belirgin
   - `manifests` — paket/build dosyaları (monorepo mu, hangi dil)
   - `signals` — framework/tool ipuçları (Next.js, Django, Docker, migrations vb.)
   - `languages` — dil dağılımı
   - `readme_head` — projenin kendi tanımı
   - `existing_memories` — zaten varsa, üzerine yazmayı teyit et

3. **Kategorileri kendin belirle.** SKILL.md'deki "Kategorileri belirle" adımını takip et:
   - Her projede: `00-index.md` + `project-structure.md`
   - Sonra projeye özgü kategoriler (frontend, backend, database, api, infra, tests, auth vs. — projede karşılığı olanlar)
   - Monorepo'larda paket/uygulama bazlı ayırmayı düşün

4. **Dosyaları yaz.** SKILL.md'deki şablonu kullan. Her kategori dosyasının "Son güncelleme" satırında `session: initial-analyze` yaz.

5. **Özet ver.** Kısa tut: hangi kategorilere böldün, niye, kaç dosya yazıldı.

$ARGUMENTS
