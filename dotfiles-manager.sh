
#!/bin/sh

# ==========================================
# Noctalia + Sway Dotfiles Manager
# POSIX SH compatible
# ==========================================

REPO="${DOTS_REPO:-$HOME/dotfiles}"
DOTS="$REPO/dots"
SCRIPT="$REPO/dotfiles-manager.sh"

# ==========================================
# Helpers
# ==========================================

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_git() {
    command -v git >/dev/null 2>&1 || die "Git is not installed"
}

require_rsync() {
    command -v rsync >/dev/null 2>&1 || die "rsync is not installed"
}

check_repo() {
    [ -d "$REPO/.git" ] || die "Repository not initialized. Run init first."
}

# ==========================================
# Initialize repository
# ==========================================

init() {
    require_git

    mkdir -p "$REPO" "$DOTS" || die "Cannot create repository"

    if [ ! -d "$REPO/.git" ]; then
        git -C "$REPO" init || die "Git init failed"
        git -C "$REPO" branch -M main || die "Cannot create main branch"
    fi

    # Copy manager script into repository
    if [ -f "$0" ]; then
        case "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" in
            "$SCRIPT") ;;
            *)
                cp "$0" "$SCRIPT" || die "Cannot copy manager script"
                chmod +x "$SCRIPT"
                ;;
        esac
    fi

    echo "Repository initialized: $REPO"
}

# ==========================================
# Synchronize configurations
# ==========================================

sync() {
    require_rsync
    mkdir -p "$DOTS" || die "Cannot create dots directory"

    sync_dir "$HOME/.config/noctalia" "$DOTS/.config/noctalia"
    sync_dir "$HOME/.local/share/noctalia" "$DOTS/.local/share/noctalia"
    sync_dir "$HOME/.local/state/noctalia" "$DOTS/.local/state/noctalia"
    sync_dir "$HOME/.config/sway" "$DOTS/.config/sway"

    echo "Configuration sync completed."
}

sync_dir() {
    SRC="$1"
    DST="$2"

    if [ -d "$SRC" ]; then
        mkdir -p "$DST" || die "Cannot create $DST"

        echo "Syncing: $SRC"

        rsync -a --delete "$SRC/" "$DST/" ||
            die "Sync failed: $SRC"
    else
        echo "Skipping missing directory: $SRC"
    fi
}

# ==========================================
# Commit
# ==========================================

commit() {
    require_git
    init
    sync

    git -C "$REPO" add dotfiles-manager.sh dots/ ||
        die "Git add failed"

    if git -C "$REPO" diff --cached --quiet; then
        echo "Nothing to commit."
        return 0
    fi

    MESSAGE="${2:-Update dotfiles $(date '+%Y-%m-%d %H:%M:%S')}"

    git -C "$REPO" commit -m "$MESSAGE" ||
        die "Commit failed"

    echo "Commit completed."
}

# ==========================================
# Pull
# ==========================================

pull() {
    require_git
    check_repo

    git -C "$REPO" pull --rebase ||
        die "Pull failed"

    echo "Pull completed."
}

# ==========================================
# Push
# ==========================================


push() {
    require_git
    check_repo

    BRANCH=$(git -C "$REPO" branch --show-current)

    if [ -z "$BRANCH" ]; then
        die "Cannot determine current branch"
    fi

    UPSTREAM=$(git -C "$REPO" rev-parse --abbrev-ref \
        --symbolic-full-name '@{u}' 2>/dev/null || true)

    if [ -z "$UPSTREAM" ]; then
        git -C "$REPO" push -u origin "$BRANCH" ||
            die "Initial push failed"
    else
        git -C "$REPO" push ||
            die "Push failed"
    fi

    echo "Push completed."
}


# ==========================================
# Backup
# ==========================================

backup() {
    commit "$@"
    push
}

# ==========================================
# Status
# ==========================================

status() {
    require_git
    check_repo

    git -C "$REPO" status
}

# ==========================================
# Restore
# ==========================================

restore() {
    require_rsync
    check_repo

    echo "Restoring Noctalia and Sway configurations..."

    sync_dir "$DOTS/.config/noctalia" "$HOME/.config/noctalia"
    sync_dir "$DOTS/.local/share/noctalia" "$HOME/.local/share/noctalia"
    sync_dir "$DOTS/.local/state/noctalia" "$HOME/.local/state/noctalia"
    sync_dir "$DOTS/.config/sway" "$HOME/.config/sway"

    echo "Restore completed."
}

# ==========================================
# Remote
# ==========================================

remote() {
    require_git
    check_repo

    if [ "$#" -eq 0 ]; then
        git -C "$REPO" remote -v
    else
        git -C "$REPO" remote add origin "$1" ||
            die "Cannot add remote"
    fi
}

# ==========================================
# Help
# ==========================================

help() {
    cat <<EOF

Noctalia + Sway Dotfiles Manager

Repository: $REPO

Commands:

  init              Initialize Git repository
  sync              Sync configurations
  commit [message]  Sync and commit
  pull              Pull remote changes
  push              Push commits
  backup [message]  Sync, commit and push
  restore           Restore configurations
  status            Show Git status
  remote [URL]      Show or add Git remote
  help              Show help

Examples:

  $0 init
  $0 sync
  $0 commit "Update Noctalia"
  $0 backup "Configuration backup"
  $0 pull
  $0 push
  $0 restore

EOF
}

# ==========================================
# Command dispatcher
# ==========================================

COMMAND="${1:-help}"

case "$COMMAND" in
    init)
        init
        ;;
    sync)
        sync
        ;;
    commit)
        commit "$@"
        ;;
    pull)
        pull
        ;;
    push)
        push
        ;;
    backup)
        backup "$@"
        ;;
    restore)
        restore
        ;;
    status)
        status
        ;;
    remote)
        shift
        remote "$@"
        ;;
    help|-h|--help)
        help
        ;;
    *)
        die "Unknown command: $COMMAND"
        ;;
esac
