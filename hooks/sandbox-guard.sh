#!/bin/bash
# Claude Code sandbox hook: restrict access to the session's working directory.
# Subdirectories are allowed freely. Parent/sibling directories trigger a permission prompt.
ALLOWED_DIR="$(pwd)"
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

ask() {
  local path="$1"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"Bu islem calisma dizini disina erisiyor: '$path'. Izin verilen dizin: $ALLOWED_DIR\"}}"
  exit 0
}

check_path() {
  local p="$1"
  [ -z "$p" ] || [ "$p" = "null" ] && return 0
  local resolved
  resolved=$(python3 -c "import os.path,sys; print(os.path.normpath(sys.argv[1]))" "$p" 2>/dev/null)
  [ -z "$resolved" ] && resolved="$p"
  [ "$resolved" = "$ALLOWED_DIR" ] && return 0
  [[ "$resolved" == "$ALLOWED_DIR/"* ]] && return 0
  return 1
}

case "$tool_name" in
  Read|Write|Edit)
    fp=$(echo "$input" | jq -r '.tool_input.file_path // ""')
    check_path "$fp" || ask "$fp"
    ;;
  Glob|Grep)
    p=$(echo "$input" | jq -r '.tool_input.path // ""')
    check_path "$p" || ask "$p"
    ;;
  Bash)
    cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
    cd_targets=$(echo "$cmd" | grep -oE 'cd[[:space:]]+/[^[:space:];|&"]+' | sed 's/cd[[:space:]]*//')
    if [ -n "$cd_targets" ]; then
      while IFS= read -r target; do
        [ -z "$target" ] && continue
        check_path "$target" || ask "$target"
      done <<< "$cd_targets"
    fi
    ;;
esac
