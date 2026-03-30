#!/bin/bash
# Toggle between Claude (Anthropic) and z.ai provider — global
# Usage:
#   bash ~/.claude/switch-provider.sh         # toggle
#   bash ~/.claude/switch-provider.sh zai     # force z.ai
#   bash ~/.claude/switch-provider.sh claude  # force Claude

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
ZAI_CONFIG="$HOME/.claude/zai-provider.json"

if [ ! -f "$ZAI_CONFIG" ]; then
    echo "z.ai config bulunamadi: $ZAI_CONFIG"
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo "settings.json bulunamadi: $SETTINGS"
    exit 1
fi

# Detect current provider
current="claude"
if jq -e '.env.ANTHROPIC_BASE_URL' "$SETTINGS" >/dev/null 2>&1; then
    current="zai"
fi

# Determine target
target="${1:-}"
if [ -z "$target" ]; then
    if [ "$current" = "claude" ]; then
        target="zai"
    else
        target="claude"
    fi
fi

case "$target" in
    zai|z.ai)
        if [ "$current" = "zai" ]; then
            echo "Zaten z.ai aktif."
            exit 0
        fi
        # Merge z.ai env into global settings
        jq -s '.[0] * .[1]' "$SETTINGS" "$ZAI_CONFIG" > "${SETTINGS}.tmp"
        mv "${SETTINGS}.tmp" "$SETTINGS"
        echo ">>> z.ai aktif edildi"
        echo "Yeni session baslatarak z.ai kullanabilirsiniz."
        ;;
    claude|anthropic)
        if [ "$current" = "claude" ]; then
            echo "Zaten Claude aktif."
            exit 0
        fi
        # Remove z.ai env block from global settings
        jq 'del(.env)' "$SETTINGS" > "${SETTINGS}.tmp"
        mv "${SETTINGS}.tmp" "$SETTINGS"
        echo ">>> Claude (Anthropic) aktif edildi"
        echo "Yeni session baslatarak Claude kullanabilirsiniz."
        ;;
    *)
        echo "Kullanim: $0 [zai|claude]"
        exit 1
        ;;
esac
