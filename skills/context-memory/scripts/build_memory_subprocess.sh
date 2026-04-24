#!/usr/bin/env bash
# build_memory_subprocess.sh
#
# Arka planda (nohup ile detach) bir `claude -p` headless instance'ı başlatır
# ve context-memory skill'ini UPDATE (veya ANALYZE+UPDATE) modunda çalıştırır.
# Ana oturumun context'ini KULLANMAZ — tamamen ayrı bir Claude süreci.
#
# pre_compact_gate.sh tarafından çağrılır. Doğrudan Claude tarafından çağrılmaz.
#
# Kullanım:
#   build_memory_subprocess.sh <cwd> <transcript_path> <session_id> <state>
#
# <state>: missing | empty | populated
#
# Exit 0 → subprocess başlatıldı (arka planda). Gerçek iş bitişini beklemez.
# Exit 1 → launcher hatası (claude CLI yok, path sorunu vs.)

set -euo pipefail

CWD="${1:-}"
TRANSCRIPT_PATH="${2:-}"
SESSION_ID="${3:-}"
STATE="${4:-populated}"

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERR: invalid cwd: $CWD" >&2
  exit 1
fi

MEMORY_DIR="$CWD/.claude/memories"
mkdir -p "$MEMORY_DIR"

LOCK_FILE="$MEMORY_DIR/.subprocess.lock"
LOG_FILE="$MEMORY_DIR/.subprocess.log"

# --- Çift çalıştırma koruması ---
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID="$(cat "$LOCK_FILE" 2>/dev/null || echo "")"
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "INFO: subprocess already running (pid=$LOCK_PID)" >&2
    exit 0  # Zaten çalışıyor, ikinci kez başlatma
  else
    # Stale lock
    rm -f "$LOCK_FILE"
  fi
fi

# --- claude CLI var mı? ---
if ! command -v claude >/dev/null 2>&1; then
  echo "ERR: 'claude' CLI PATH'te bulunamadı. Subprocess modu kullanılamaz." >&2
  exit 1
fi

# --- Mod talimatını hazırla ---
if [ "$STATE" = "populated" ]; then
  MODE_INSTRUCTION="UPDATE modunda çalış. Transcript'i oku, mevcut kategori dosyalarını (.claude/memories/*.md) str_replace ile incremental güncelle. Tüm dosyayı yeniden yazma. Sonra .claude/memories/_sessions/ altına bu oturumun özet dosyasını oluştur."
else
  MODE_INSTRUCTION="Memory boş. Önce ANALYZE modunda çalış: analyze_project.py'ı çağırıp projeye uygun kategori dosyalarını .claude/memories/ altında oluştur. Sonra UPDATE modunu da çalıştır: bu oturumun özetini _sessions/ altına yaz."
fi

# Subprocess'e verilecek prompt
PROMPT=$(cat <<EOF
.claude/skills/context-memory/SKILL.md dosyasını oku ve kurallarına göre çalış.

$MODE_INSTRUCTION

Oturum verileri:
- transcript_path: $TRANSCRIPT_PATH
- session_id: $SESSION_ID
- cwd: $CWD

Transcript metadatasını almak için:
  python3 .claude/skills/context-memory/scripts/extract_transcript_summary.py "$TRANSCRIPT_PATH"

Memory dosyalarını .claude/memories/ altına yaz. İş bitince sadece kısa bir
"done" raporu ver (hangi dosyalar oluşturuldu/güncellendi listesi). Başka
bir şey yapma.
EOF
)

# --- Subprocess'i arka planda başlat ---
# nohup + disown ile ana hook süreci öldüğünde bile devam etsin.
# stdout/stderr log dosyasına.
# setsid ile yeni session oluştur (parent'tan bağımsız)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting subprocess: session=$SESSION_ID state=$STATE" >> "$LOG_FILE"

# Inline bir runner yarat ki PID lock yönetimi + cleanup doğru olsun
RUNNER_SCRIPT=$(cat <<RUNNER
#!/usr/bin/env bash
set +e
cd "$CWD"
echo \$\$ > "$LOCK_FILE"

# claude -p ile headless çalıştır
# --dangerously-skip-permissions: subprocess etkileşimli olmadığı için her izin
# için onay bekleyemez. Skill kendi skopu içinde çalışıyor (memory yazma).
# Eğer bu flag sorun yaratırsa alternatif: --allowedTools "Read,Write,Edit,Bash"
claude -p "\$(cat <<'PROMPT_EOF'
$PROMPT
PROMPT_EOF
)" --dangerously-skip-permissions >> "$LOG_FILE" 2>&1

RC=\$?
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] subprocess finished (rc=\$RC)" >> "$LOG_FILE"
rm -f "$LOCK_FILE"
RUNNER
)

# Runner'ı tmp dosyaya yaz, setsid ile detach et
RUNNER_FILE="$(mktemp "${TMPDIR:-/tmp}/ctx-memory-runner.XXXXXX.sh")"
printf '%s\n' "$RUNNER_SCRIPT" > "$RUNNER_FILE"
chmod +x "$RUNNER_FILE"

# setsid + nohup: terminal/session'dan tamamen bağımsız
if command -v setsid >/dev/null 2>&1; then
  setsid nohup bash "$RUNNER_FILE" </dev/null >/dev/null 2>&1 &
else
  # macOS ve bazı BSD'lerde setsid yok
  nohup bash "$RUNNER_FILE" </dev/null >/dev/null 2>&1 &
fi
disown "$!" 2>/dev/null || true

# Runner dosyasını 10 sn sonra silmek için arka plan timer
(sleep 10 && rm -f "$RUNNER_FILE") </dev/null >/dev/null 2>&1 &
disown "$!" 2>/dev/null || true

exit 0
