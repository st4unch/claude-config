#!/usr/bin/env bash
# pre_compact_gate.sh
# Claude Code PreCompact hook'u olarak çalışır.
#
# İki çalışma modu:
#
#   (A) SUBPROCESS MODE (varsayılan, CLAUDE_CTX_MEMORY_MODE=subprocess):
#       - Taze memory yoksa, `claude -p` ile ARKA PLANDA ayrı bir Claude
#         instance başlatır (build_memory_subprocess.sh aracılığıyla).
#       - Ana oturum kesilmez — başka bir süreç memory'yi yazar.
#       - Hook hemen {"decision":"block"} döner ve Claude'a minimal mesaj verir:
#         "arka planda memory oluşturuluyor, 30-60 sn sonra /compact'ı tekrar dene".
#       - Kullanıcı /compact'ı tekrar çağırdığında hook taze memory'yi görür,
#         izin verir.
#
#   (B) INLINE MODE (CLAUDE_CTX_MEMORY_MODE=inline):
#       - Eski davranış. Hook ana Claude oturumuna "skill'i çalıştır" talimatı
#         verir. Claude memory'yi kendisi yazar (context'ini kullanır, kesinti).
#       - `claude` CLI yoksa veya kullanıcı subprocess'i istemiyorsa fallback.
#
# Stdin: Claude Code'un PreCompact hook JSON'ı

set -euo pipefail

# --- Yapılandırma ---
MEMORY_DIR_REL=".claude/memories"
FRESHNESS_SECONDS=300
MODE="${CLAUDE_CTX_MEMORY_MODE:-subprocess}"  # subprocess | inline

# Hook script'inin bulunduğu dizin — subprocess launcher'ı bulmak için
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBPROCESS_LAUNCHER="$SCRIPT_DIR/build_memory_subprocess.sh"

# --- Stdin'i oku ---
INPUT="$(cat)"

extract_field() {
  local field="$1"
  if command -v jq >/dev/null 2>&1; then
    echo "$INPUT" | jq -r --arg f "$field" '.[$f] // empty'
  else
    echo "$INPUT" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
      | sed -E "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/" \
      | head -n1
  fi
}

SESSION_ID="$(extract_field session_id)"
TRANSCRIPT_PATH="$(extract_field transcript_path)"
CWD="$(extract_field cwd)"
TRIGGER="$(extract_field trigger)"

[ -z "$CWD" ] && CWD="$(pwd)"

MEMORY_DIR="$CWD/$MEMORY_DIR_REL"

# --- Taze memory kontrolü ---
has_fresh_memory() {
  [ -d "$MEMORY_DIR" ] || return 1
  local now threshold
  now="$(date +%s)"
  threshold=$(( now - FRESHNESS_SECONDS ))
  local f mtime
  while IFS= read -r -d '' f; do
    if stat -c %Y "$f" >/dev/null 2>&1; then
      mtime=$(stat -c %Y "$f")
    else
      mtime=$(stat -f %m "$f")
    fi
    [ "$mtime" -ge "$threshold" ] && return 0
  done < <(find "$MEMORY_DIR" -type f -name "*.md" -print0 2>/dev/null)
  return 1
}

memory_dir_state() {
  [ ! -d "$MEMORY_DIR" ] && { echo "missing"; return; }
  ls "$MEMORY_DIR"/*.md >/dev/null 2>&1 && echo "populated" || echo "empty"
}

# --- Subprocess çalışıyor mu? ---
subprocess_running() {
  local lock="$MEMORY_DIR/.subprocess.lock"
  [ -f "$lock" ] || return 1
  local pid
  pid="$(cat "$lock" 2>/dev/null || echo "")"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# --- JSON escape yardımcısı ---
escape_json() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$1"
}

emit_block() {
  local reason="$1"
  local reason_json
  reason_json="$(escape_json "$reason")"
  cat <<EOF
{"decision":"block","reason":${reason_json}}
EOF
}

# --- Ana mantık ---

# 1) Taze memory varsa → izin ver (sessiz)
if has_fresh_memory; then
  exit 0
fi

STATE="$(memory_dir_state)"

# 2) Subprocess mode + claude CLI mevcut → arka plana delege et
if [ "$MODE" = "subprocess" ] && command -v claude >/dev/null 2>&1 && [ -x "$SUBPROCESS_LAUNCHER" ]; then

  if subprocess_running; then
    # Zaten çalışıyor — kullanıcıya bekle de
    REASON="Context-memory subprocess'i hâlâ çalışıyor (arka planda memory oluşturuyor). Kullanıcıya şunu söyle: \"Memory oluşturma arka planda devam ediyor. Birkaç saniye bekleyip \`/compact\` komutunu tekrar çalıştır.\" SKILL'i çalıştırma, başka bir şey yapma."
    emit_block "$REASON"
    exit 0
  fi

  # Subprocess'i başlat
  if bash "$SUBPROCESS_LAUNCHER" "$CWD" "$TRANSCRIPT_PATH" "$SESSION_ID" "$STATE" 2>/dev/null; then
    REASON="Arka planda memory oluşturmak için ayrı bir Claude süreci başlatıldı (state=$STATE). Kullanıcıya şunu söyle: \"Context-memory arka planda çalışıyor (.claude/memories/'e yazılıyor). 30-60 saniye sonra \`/compact\` komutunu tekrar çalıştır — memory hazır olduğunda compact sorunsuz çalışacak.\" Sadece bu bilgiyi ilet. SKILL'i ÇALIŞTIRMA, memory'yi sen yazma."
    emit_block "$REASON"
    exit 0
  fi
  # Subprocess başlatılamadı → inline fallback'e düş
fi

# 3) Inline mode (veya subprocess fallback) → Claude'a kendisi yazsın de
if [ "$STATE" = "populated" ]; then
  MODE_INSTR="UPDATE modunda çalış: mevcut kategori dosyalarını bu oturumda öğrenilenlerle incremental olarak (str_replace) güncelle VE .claude/memories/_sessions/ altına oturum özetini yaz."
else
  MODE_INSTR="Memory klasörü boş veya yok. Önce ANALYZE modunda çalış (analyze_project.py → kategori dosyaları), sonra UPDATE modunu çalıştır (session özeti)."
fi

REASON=$(cat <<EOF
[context-memory hook] Auto-compact tetiklendi (trigger=${TRIGGER:-auto}). Compact engellendi.

$MODE_INSTR

Oturum verileri:
- transcript_path: ${TRANSCRIPT_PATH}
- session_id: ${SESSION_ID}
- cwd: ${CWD}

Memory durumu: ${STATE}
Çalışma modu: inline (subprocess mevcut değil veya kapatıldı)

context-memory skill'indeki şablonları ve kuralları takip et. Bitince kullanıcıya \`/compact\` komutunu tekrar çalıştırmasını söyle. Kendin \`/compact\` çağırma.
EOF
)

emit_block "$REASON"
exit 0
