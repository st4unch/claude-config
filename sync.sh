#!/usr/bin/env bash
# claude-config sync — safely share Claude Code config across machines
# Usage:
#   ./sync.sh pull          — Download shared files from repo to ~/.claude/
#   ./sync.sh push          — Upload local shared files to repo
#   ./sync.sh diff          — Show differences between local and repo
#   ./sync.sh setup         — First-time setup (clone repo + pull)
set -euo pipefail

REPO_URL="git@github.com:st4unch/claude-config.git"
REPO_NAME="claude-config"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Shared files manifest ────────────────────────────────────────────
SHARED_FILES=(
    "CLAUDE.md:CLAUDE.md"
    "settings.json:settings.json"
    "hooks/rm-guard.sh:hooks/rm-guard.sh"
    "hooks/sandbox-guard.sh:hooks/sandbox-guard.sh"
    "hooks/pre-pr-audit-check.sh:hooks/pre-pr-audit-check.sh"
    "scripts/telegram-notify.sh:scripts/telegram-notify.sh"
    "scripts/telegram-approval.py:scripts/telegram-approval.py"
    "scripts/claude-sessions.sh:scripts/claude-sessions.sh"
    "commands/kickoff.md:commands/kickoff.md"
    "commands/security-audit.md:commands/security-audit.md"
    "skills/frontend-design/SKILL.md:skills/frontend-design/SKILL.md"
    "skills/project-auditor/SKILL.md:skills/project-auditor/SKILL.md"
    "skills/project-architect/SKILL.md:skills/project-architect/SKILL.md"
)

# ─── Setup command ─────────────────────────────────────────────────────
do_setup() {
    info "First-time setup..."

    # Check SSH key
    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        error "GitHub SSH erisimi yok. Once SSH key ekleyin:"
        echo "  ssh-keygen -t ed25519 -C 'your@email.com'"
        echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title 'my-pc'"
        exit 1
    fi

    # Clone if needed
    if [ ! -d "$CLAUDE_DIR/$REPO_NAME" ]; then
        info "Repo klonlaniyor..."
        git clone "$REPO_URL" "$CLAUDE_DIR/$REPO_NAME"
        ok "Repo klonlandi: $CLAUDE_DIR/$REPO_NAME"
    fi

    # Pull shared files
    info "Dosyalar indiriliyor..."
    REPO_DIR="$CLAUDE_DIR/$REPO_NAME" do_pull

    echo ""
    ok "Kurulum tamamlandi!"
    echo ""
    info "Kullanim:"
    echo "  cd ~/.claude/claude-config && ./sync.sh pull   — Dosyalari guncelle"
    echo "  cd ~/.claude/claude-config && ./sync.sh push   — Dosyalari repoyla paylas"
}

# ─── Pull command ──────────────────────────────────────────────────────
do_pull() {
    info "Pulling shared files from repo to $CLAUDE_DIR ..."

    mkdir -p "$CLAUDE_DIR/hooks"
    mkdir -p "$CLAUDE_DIR/commands"
    mkdir -p "$CLAUDE_DIR/scripts"
    mkdir -p "$CLAUDE_DIR/skills/frontend-design"
    mkdir -p "$CLAUDE_DIR/skills/project-auditor"
    mkdir -p "$CLAUDE_DIR/skills/project-architect"

    local changed=0
    local skipped=0

    for entry in "${SHARED_FILES[@]}"; do
        repo_path="${entry%%:*}"
        local_path="${entry##*:}"

        src="$REPO_DIR/$repo_path"
        dst="$CLAUDE_DIR/$local_path"

        if [ ! -f "$src" ]; then
            warn "Repo dosyasi eksik: $repo_path — atlandi"
            ((skipped++)) || true
            continue
        fi

        if [ -f "$dst" ]; then
            if diff -q "$src" "$dst" >/dev/null 2>&1; then
                echo "  $local_path — degisiklik yok"
                continue
            fi
            cp "$dst" "${dst}.bak"
            warn "Yedeklendi: ${dst}.bak"
        fi

        cp "$src" "$dst"
        chmod +x "$dst" 2>/dev/null || true
        ok "Guncellendi: $local_path"
        ((changed++)) || true
    done

    echo ""
    if [ "$changed" -gt 0 ]; then
        ok "$changed dosya guncellendi. $skipped atlandi."
    else
        info "Tum dosyalar guncel."
    fi
}

# ─── Push command ──────────────────────────────────────────────────────
do_push() {
    info "Pushing local shared files to repo ..."

    local changed=0

    for entry in "${SHARED_FILES[@]}"; do
        repo_path="${entry%%:*}"
        local_path="${entry##*:}"

        dst="$REPO_DIR/$repo_path"
        src="$CLAUDE_DIR/$local_path"

        if [ ! -f "$src" ]; then
            warn "Local dosya eksik: $local_path — atlandi"
            continue
        fi

        mkdir -p "$(dirname "$dst")"

        if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
            echo "  $repo_path — degisiklik yok"
            continue
        fi

        cp "$src" "$dst"
        ok "Repo guncellendi: $repo_path"
        ((changed++)) || true
    done

    # Defense-in-depth: projects/ staging'e sizmamali (SHARED_FILES'da yok ama paranoia)
    if [[ -d "$REPO_DIR/projects" ]] && [[ -n "$(ls -A "$REPO_DIR/projects" 2>/dev/null)" ]]; then
        error "KRITIK: $REPO_DIR/projects/ icerik barindiriyor — push iptal."
        error "projects/ asla staging'e girmemeli. Temizle: rm -rf $REPO_DIR/projects"
        return 1
    fi

    echo ""
    if [ "$changed" -gt 0 ]; then
        ok "$changed dosya repoya eklendi. Yayinlamak icin: cd $REPO_DIR && git add -A && git commit -m 'update' && git push"
    else
        info "Repo guncel."
    fi
}

# ─── Diff command ──────────────────────────────────────────────────────
do_diff() {
    info "Karsilastirma (local vs repo) ..."
    echo ""

    for entry in "${SHARED_FILES[@]}"; do
        repo_path="${entry%%:*}"
        local_path="${entry##*:}"

        src="$REPO_DIR/$repo_path"
        dst="$CLAUDE_DIR/$local_path"

        if [ ! -f "$src" ] || [ ! -f "$dst" ]; then
            echo -e "  ${YELLOW}EKSIK${NC}    $local_path"
            continue
        fi

        if diff -q "$src" "$dst" >/dev/null 2>&1; then
            echo -e "  ${GREEN}AYNI${NC}      $local_path"
        else
            echo -e "  ${RED}FARKLI${NC}    $local_path"
            diff --color=always -u "$src" "$dst" | head -20
            echo ""
        fi
    done
}

# ─── Main ──────────────────────────────────────────────────────────────
case "${1:-help}" in
    pull)  do_pull ;;
    push)  do_push ;;
    diff)  do_diff ;;
    setup) do_setup ;;
    *)
        echo "claude-config sync — Claude Code yapilandirmasini makineler arasi paylas"
        echo ""
        echo "Kullanim: $0 <komut>"
        echo ""
        echo "Komutlar:"
        echo "  setup  Ilk kurulum (repo klonla + dosyalari indir)"
        echo "  pull   Repodaki dosyalari ~/.claude/ dizinine indir"
        echo "  push   Local dosyalari repoya yukle"
        echo "  diff   Local ve repo arasindaki farklari goster"
        echo ""
        echo "Paylasilan dosyalar:"
        for entry in "${SHARED_FILES[@]}"; do
            echo "  ${entry##*:}"
        done
        echo ""
        echo "Paylasilmayanlar (makineye ozel):"
        echo "  settings.local.json — Makineye ozel izinler"
        echo "  projects/           — Proje bellekleri (makineye ozel)"
        ;;
esac
