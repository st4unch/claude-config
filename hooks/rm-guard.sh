#!/usr/bin/env bash
# PreToolUse hook: Blocks dangerous rm commands (rm -rf, rm -r without confirmation)
# Reads JSON from stdin, outputs JSON to stdout.

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$tool_name" != "Bash" ]]; then
  echo '{}'
  exit 0
fi

command_input=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Strip leading/trailing whitespace
command_input=$(echo "$command_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Check for rm commands
# Match: rm -rf, rm -r (without -i or --interactive), rm -fr, rm with wildcards
if echo "$command_input" | grep -qE '(^|\s|;|&&|\||\`)rm\s+(-(r|R)[fF]*|-f[a-zA-Z]*)(\s|$|;)'; then
  # Dangerous rm detected (recursive + force)
  cat <<'EOF'
{"decision":"block","reason":"BLOCKED: Dangerous rm command detected (rm -rf / rm -r without -i). This is a system-wide safety hook. If you truly need to delete files, use the dedicated file tools (Edit, Write) or ask the user for confirmation first."}
EOF
  exit 0
fi

if echo "$command_input" | grep -qE '(^|\s|;|&&|\||\`)rm\s+'; then
  # Regular rm detected - allow but warn
  cat <<'EOF'
{"systemMessage":"WARNING: rm command detected. Consider using dedicated file tools instead for better traceability and safety."}
EOF
  exit 0
fi

echo '{}'
exit 0
