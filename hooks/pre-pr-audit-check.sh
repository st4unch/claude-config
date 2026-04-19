#!/usr/bin/env bash
# Pre-PR security audit check
# Warns if no security audit report exists within the last 7 days
set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$tool_name" != "Bash" ]]; then
  echo '{}'
  exit 0
fi

command_input=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only check on PR creation or push commands
if ! echo "$command_input" | grep -qE '(gh pr create|git push)'; then
  echo '{}'
  exit 0
fi

# Check for recent audit report (within 7 days)
AUDIT_DIR="docs"
if [[ -d "$AUDIT_DIR" ]]; then
  RECENT=$(find "$AUDIT_DIR" -name "security-audit-report-*.md" -mtime -7 2>/dev/null | head -1)
  if [[ -n "$RECENT" ]]; then
    echo '{}'
    exit 0
  fi
fi

# No recent audit found — warn
cat <<'HOOKEOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","systemMessage":"UYARI: Son 7 gun icinde docs/ dizininde guvenlik taramasi raporu bulunamadi. PR olusturmadan once /security-audit komutunu calistirmayi dusunun."}}
HOOKEOF
exit 0
