#!/usr/bin/env python3
"""
Telegram Approval Hook for Claude Code
PreToolUse hook: sends approval request to Telegram with inline buttons,
polls for callback response via getUpdates, returns permission decision.
"""

import json
import sys
import os
import time
import subprocess
import urllib.request
import urllib.error

# --- Config ---
APPROVAL_TIMEOUT = int(os.environ.get("TELEGRAM_APPROVAL_TIMEOUT", "120"))
CHAT_ID = "REDACTED_CHAT_ID"
ENV_FILE = os.path.expanduser("~/.claude/channels/telegram/.env")
APPROVALS_DIR = os.path.expanduser("~/.claude/approvals")


def load_bot_token():
    """Load bot token from .env file."""
    token = os.environ.get("TELEGRAM_BOT_TOKEN")
    if token:
        return token
    with open(ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if line.startswith("TELEGRAM_BOT_TOKEN="):
                return line.split("=", 1)[1].strip()
    return None


def telegram_api(method, payload=None):
    """Call Telegram Bot API."""
    token = load_bot_token()
    if not token:
        return None
    url = f"https://api.telegram.org/bot{token}/{method}"
    if payload:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    else:
        req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception:
        return None


def get_last_update_id():
    """Get the current max update_id without consuming anything."""
    result = telegram_api("getUpdates", {"offset": -1, "limit": 1})
    if result and result.get("ok") and result.get("result"):
        return result["result"][0]["update_id"]
    return 0


def send_approval_message(project, tool, detail):
    """Send approval request with inline keyboard."""
    # Truncate detail for readability
    detail_short = detail[:300] + ("..." if len(detail) > 300 else "")

    text = (
        f"🔐 *Onay Gerekli*\n"
        f"📁 `{project}`\n"
        f"🔧 `{tool}`\n\n"
        f"```\n{detail_short}\n```\n\n"
        f"⏳ {APPROVAL_TIMEOUT}sn içinde onay bekleniyor..."
    )

    payload = {
        "chat_id": CHAT_ID,
        "parse_mode": "Markdown",
        "text": text,
        "reply_markup": {
            "inline_keyboard": [
                [
                    {"text": "✅ Onayla", "callback_data": "approve"},
                    {"text": "❌ Reddet", "callback_data": "deny"},
                ]
            ]
        },
    }

    result = telegram_api("sendMessage", payload)
    if result and result.get("ok"):
        return result["result"]["message_id"]
    return None


def wait_for_callback(msg_id, start_update_id, project, tool):
    """Poll getUpdates for callback query matching our message."""
    deadline = time.time() + APPROVAL_TIMEOUT
    offset = start_update_id + 1  # Start from the next update

    while time.time() < deadline:
        remaining = int(deadline - time.time())
        if remaining <= 0:
            break

        # Long poll for 5 seconds at a time
        poll_timeout = min(5, remaining)
        result = telegram_api("getUpdates", {
            "offset": offset,
            "timeout": poll_timeout,
            "allowed_updates": ["callback_query"],
        })

        if not result or not result.get("ok"):
            time.sleep(1)
            continue

        for update in result.get("result", []):
            offset = update["update_id"] + 1  # Acknowledge this update

            cb = update.get("callback_query")
            if not cb:
                continue

            cb_msg_id = cb.get("message", {}).get("message_id")
            if cb_msg_id != msg_id:
                continue

            # Found our callback!
            cb_data = cb.get("data", "")
            cb_id = cb.get("id", "")

            # Answer the callback (removes loading spinner)
            telegram_api("answerCallbackQuery", {
                "callback_query_id": cb_id,
                "text": "✅ Onaylandı" if cb_data == "approve" else "❌ Reddedildi",
            })

            # Update the message to show the decision
            new_text = (
                f"🔐 *Onay Gerekli*\n"
                f"📁 `{project}`\n"
                f"🔧 `{tool}`\n\n"
            )
            if cb_data == "approve":
                new_text += "✅ **ONAYLANDI**"
            else:
                new_text += "❌ **REDDEDİLDİ**"

            telegram_api("editMessageText", {
                "chat_id": CHAT_ID,
                "message_id": msg_id,
                "parse_mode": "Markdown",
                "text": new_text,
            })

            return cb_data

    return None


def send_timeout_message(msg_id, project, tool):
    """Update message to show timeout."""
    text = (
        f"🔐 *Onay Gerekli*\n"
        f"📁 `{project}`\n"
        f"🔧 `{tool}`\n\n"
        f"⌛ *Zaman aşımı* — terminalde onay bekleniyor..."
    )
    telegram_api("editMessageText", {
        "chat_id": CHAT_ID,
        "message_id": msg_id,
        "parse_mode": "Markdown",
        "text": text,
    })


# --- Main ---
def main():
    # Read hook input from stdin
    try:
        input_data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    cwd = input_data.get("cwd", os.getcwd())
    project = os.path.basename(cwd) if cwd != os.path.expanduser("~") else "~"

    # Extract tool-specific detail
    tool_input = input_data.get("tool_input", {})
    if tool_name == "Bash":
        detail = tool_input.get("command", "")
    elif tool_name in ("Edit", "Write", "Read"):
        detail = tool_input.get("file_path", "")
    elif tool_name == "WebFetch":
        detail = tool_input.get("url", "")
    else:
        detail = json.dumps(tool_input, ensure_ascii=False)[:300]

    if not detail:
        detail = "(detay yok)"

    # Get current update offset before sending
    last_id = get_last_update_id()

    # Send approval request
    msg_id = send_approval_message(project, tool_name, detail)
    if not msg_id:
        # Can't send message - fall back to terminal
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask"
            }
        }))
        return

    # Poll for callback
    decision = wait_for_callback(msg_id, last_id, project, tool_name)

    if decision == "approve":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow"
            }
        }))
    elif decision == "deny":
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny"
            }
        }))
    else:
        # Timeout - notify and fall back to terminal
        send_timeout_message(msg_id, project, tool_name)
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask"
            }
        }))


if __name__ == "__main__":
    main()
