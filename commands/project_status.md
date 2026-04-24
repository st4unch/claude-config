---
name: project-status
description: >
  Use this skill whenever the user runs /project_status or asks for a project status update, 
  status report, durum raporu, or progress summary. Reads project metadata from CLAUDE.md, 
  inspects recent git activity, open/modified files, and conversation history to produce a 
  structured status report. Always trigger when the user types /project_status or asks 
  "ne durumda", "status ver", "durum raporu", "what's the status", "progress update", or 
  any similar phrase requesting a project status summary.
allowed-tools: Bash, Read, Glob, Grep
---

# Project Status Skill (`/project_status`)

Bu skill, ekip üyelerinin Claude Code üzerinde çalıştığı projelerin anlık durum raporunu
standart bir formatta üretir. Rapor; CLAUDE.md'deki proje bilgileri, git geçmişi, 
güncel dosya değişiklikleri ve konuşma bağlamı kullanılarak oluşturulur.

---

## Execution Steps

### 1. Proje bilgilerini topla

CLAUDE.md dosyasını oku (varsa). Şu alanları çıkar:
- **Proje adı**
- **Sorumlu kişi**
- **Repo / modül adı**
- Varsa özel notlar

CLAUDE.md yoksa veya bu alanlar eksikse, kullanıcıya sor ya da mevcut repo adını kullan.

### 2. Git aktivitesini incele

Aşağıdaki komutları çalıştır (git repo ise):

```bash
# Son 7 günün commit'leri
git log --oneline --since="7 days ago" --author=$(git config user.email) 2>/dev/null | head -20

# Mevcut değişiklikler
git status --short 2>/dev/null

# Son değiştirilen dosyalar
git diff --name-only HEAD~5 HEAD 2>/dev/null | head -20
```

Git repo değilse bu adımı atla, konuşma geçmişinden çıkar.

### 3. Konuşma geçmişini tara

Bu session'da konuşulan konuları, tamamlanan işleri, karşılaşılan engelleri ve 
kullanıcının belirttiği sonraki adımları çıkar.

### 4. Raporu formatla

Aşağıdaki şablonu kullanarak Markdown raporu oluştur.
**Şablondan sapma — başlıkları değiştirme, sıralarını koruma.**

```
---
**📁 Proje:** <proje adı>
**👤 Sorumlu:** <isim>
**📅 Tarih:** <bugünün tarihi, GG/AA/YYYY>

---

**✅ Bu hafta yapılanlar:**
- <madde 1>
- <madde 2>
- ... (max 5 madde, net ve teknik)

**🚧 Devam eden işler:**
- <şu an üzerinde çalışılan şey>

**⛔ Engeller / Beklenenler:**
- <varsa engel veya beklenen karar/destek — yoksa "Engel yok">

**➡️ Sonraki adım:**
<tek cümle, aksiyon odaklı>

**🎯 Tahmini tamamlanma:**
<tarih veya "Belirsiz">
---
```

### 5. Çıktıyı sun

- Raporu kod bloğu içinde ver (kullanıcı kopyalayıp paylaşabilsin)
- Blok dışında tek cümleyle özet yap: "Rapor hazır, kopyalayıp paylaşabilirsin."
- Eksik bilgi varsa (örn. tahmini tarih bilinmiyorsa) kullanıcıya sor, ama raporu bekletme — mevcut bilgiyle üret, eksik alanı `?` ile bırak.

---

## Edge Cases

| Durum | Davranış |
|---|---|
| CLAUDE.md yok | Repo adı + kullanıcı adını kullan, uyar |
| Git repo değil | Git adımını atla, sadece konuşma geçmişini kullan |
| Hiç aktivite yok | "Bu hafta kayıt bulunamadı" yaz, kullanıcıya sor |
| Birden fazla proje | Her biri için ayrı rapor üret |

---

## Örnek Çıktı

```
---
**📁 Proje:** UZAI – SAST Modülleri & Ajanları
**👤 Sorumlu:** Furkan
**📅 Tarih:** 10/04/2025

---

**✅ Bu hafta yapılanlar:**
- Semgrep rule engine entegrasyonu tamamlandı
- Python ve JS için temel SAST ajan prototipi yazıldı
- False positive filtreleme için ilk prompt seti test edildi

**🚧 Devam eden işler:**
- Java desteği için rule mapping devam ediyor

**⛔ Engeller / Beklenenler:**
- UZAI API erişimi için onay bekleniyor

**➡️ Sonraki adım:**
Java rule mapping tamamlanıp integration test yazılacak.

**🎯 Tahmini tamamlanma:**
25/04/2025
---
```
