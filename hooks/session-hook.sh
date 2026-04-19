#!/usr/bin/env bash
# Session tracking hook for Claude Code
# Tracks session IDs, project folders, and latest commits in ~/.claude/sessions.json
set -euo pipefail

SESSIONS_FILE="$HOME/.claude/sessions.json"
HOOK_TYPE="${CLAUDE_HOOK_TYPE:-}"
SESSION_ID="${CLAUDE_SESSION_ID:-}"

# Always exit 0 — never block Claude
trap 'exit 0' ERR

# Need a session ID to do anything useful
if [[ -z "$SESSION_ID" ]]; then
  echo '{}'
  exit 0
fi

# Initialize sessions file if missing
if [[ ! -f "$SESSIONS_FILE" ]]; then
  echo '[]' > "$SESSIONS_FILE"
fi

# Detect project folder (git root basename, fallback to cwd basename)
PROJECT_FOLDER="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"

# Get current timestamp in ISO8601
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Get latest commit info
get_last_commit() {
  git log -1 --format='%h %s' 2>/dev/null || echo ""
}

# --- jq path ---
upsert_with_jq() {
  local last_commit="$1"
  local tmp
  tmp=$(mktemp)

  local exists
  exists=$(jq --arg sid "$SESSION_ID" '[.[] | select(.claude_session_id == $sid)] | length' "$SESSIONS_FILE")

  if [[ "$exists" -gt 0 ]]; then
    # Update existing entry
    jq --arg sid "$SESSION_ID" \
       --arg pf "$PROJECT_FOLDER" \
       --arg lc "$last_commit" \
       --arg now "$NOW" \
       'map(if .claude_session_id == $sid then
         .project_folder = $pf |
         .updated_at = $now |
         (if $lc != "" then .last_commit = $lc else . end)
       else . end)' "$SESSIONS_FILE" > "$tmp"
  else
    # Insert new entry
    jq --arg sid "$SESSION_ID" \
       --arg pf "$PROJECT_FOLDER" \
       --arg lc "$last_commit" \
       --arg now "$NOW" \
       '. + [{
         "claude_session_id": $sid,
         "project_folder": $pf,
         "last_commit": $lc,
         "created_at": $now,
         "updated_at": $now
       }]' "$SESSIONS_FILE" > "$tmp"
  fi

  mv "$tmp" "$SESSIONS_FILE"
}

# --- python3 fallback ---
upsert_with_python() {
  local last_commit="$1"
  python3 - "$SESSIONS_FILE" "$SESSION_ID" "$PROJECT_FOLDER" "$last_commit" "$NOW" <<'PYEOF'
import json, sys

sessions_file, sid, pf, lc, now = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

with open(sessions_file, "r") as f:
    sessions = json.load(f)

found = False
for s in sessions:
    if s.get("claude_session_id") == sid:
        s["project_folder"] = pf
        s["updated_at"] = now
        if lc:
            s["last_commit"] = lc
        found = True
        break

if not found:
    sessions.append({
        "claude_session_id": sid,
        "project_folder": pf,
        "last_commit": lc,
        "created_at": now,
        "updated_at": now
    })

with open(sessions_file, "w") as f:
    json.dump(sessions, f, indent=2)
PYEOF
}

# --- Main logic ---

# Read stdin (hook input) but we don't block on it
INPUT=""
if ! [ -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

case "$HOOK_TYPE" in
  PreToolUse)
    last_commit="$(get_last_commit)"
    if command -v jq &>/dev/null; then
      upsert_with_jq "$last_commit"
    else
      upsert_with_python "$last_commit"
    fi
    ;;

  PostToolUse)
    # Only update commit info if the Bash command was git commit or git push
    COMMAND_INPUT=""
    if [[ -n "$INPUT" ]]; then
      if command -v jq &>/dev/null; then
        COMMAND_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
      else
        COMMAND_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || true)
      fi
    fi

    if echo "$COMMAND_INPUT" | grep -qE 'git\s+(commit|push)'; then
      last_commit="$(get_last_commit)"
      if [[ -n "$last_commit" ]]; then
        if command -v jq &>/dev/null; then
          upsert_with_jq "$last_commit"
        else
          upsert_with_python "$last_commit"
        fi
      fi
    fi
    ;;

  *)
    # Unknown hook type — no-op
    ;;
esac

echo '{}'
exit 0
