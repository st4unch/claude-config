#!/bin/bash
# Telegram notification hook for Claude Code
# Reads hook input from stdin, sends a message via Telegram Bot API

# Load bot token
ENV_FILE="$HOME/.claude/channels/telegram/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  exit 0
fi
source "$ENV_FILE"

CHAT_ID="REDACTED_CHAT_ID"

# Read hook input from stdin
INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT=$(basename "$CWD" 2>/dev/null)
[[ "$CWD" == "$HOME" ]] && PROJECT="~"

case "$EVENT" in
  Notification)
    TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')
    MSG=$(echo "$INPUT" | jq -r '.message // ""')
    if [[ "$TYPE" == "permission_prompt" ]]; then
      TEXT="🔐 *Onay Bekleniyor*
📁 \`$PROJECT\`
$MSG"
    else
      exit 0
    fi
    ;;
  Stop)
    LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' | head -c 200)
    TEXT="✅ *Cevap Bekliyor*
📁 \`$PROJECT\`
${LAST_MSG}..."
    ;;
  *)
    exit 0
    ;;
esac

# Send via Telegram Bot API
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d parse_mode="Markdown" \
  -d text="$TEXT" \
  > /dev/null 2>&1 &

exit 0
