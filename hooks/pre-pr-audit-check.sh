#!/usr/bin/env bash
# version: pre-pr-hook-v3.0
# Warns when no security audit report exists within the last 7 days.
set -euo pipefail
input=$(cat)
tool_name=$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[[ "$tool_name" == "Bash" ]] || { echo '{}'; exit 0; }
command_input=$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
echo "$command_input" | grep -qE '(gh pr create|git push)' || { echo '{}'; exit 0; }
AUDIT_DIR="docs"
if [[ -d "$AUDIT_DIR" ]]; then
  RECENT=$(find "$AUDIT_DIR" -name "security-audit-report-*.md" -mtime -7 2>/dev/null | head -1)
  [[ -z "$RECENT" ]] || { echo '{}'; exit 0; }
fi
printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","systemMessage":"WARNING: No security audit report found in docs/ within the last 7 days. Consider running /security-audit before creating a PR."}}'
exit 0
