#!/usr/bin/env bash
#
# ps1.sh - Git & GitHub Sync-Aware Bash Prompt Installer
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/ps1.sh | bash -s -- [OPTIONS]
#
# Options:
#   -t, --try        Install ps1 command but don't add to .bashrc (run 'ps1' manually)
#   -p, --permanent  Add ps1 to .bashrc (useful after --remove or initial -t usage)
#   -u, --update     Update ps1 command and .bashrc from latest version
#   --remove         Remove ps1 from .bashrc only (keeps ps1 command installed)
#   --uninstall      Remove both ps1 command and .bashrc configuration
#   --help           Show this help message
#
# Default behavior (no options): Install ps1 command and add to .bashrc

set -e

# --- Configuration ---
PS1_COMMAND_NAME="ps1"
INSTALL_DIR="$HOME/.local/bin"
PS1_PATH="$INSTALL_DIR/$PS1_COMMAND_NAME"
BACKUP_PREFIX="$HOME/.bashrc.ps1_backup"
BASHRC="$HOME/.bashrc"
MARKER_START="# --- PS1_START ---"
MARKER_END="# --- PS1_END ---"

# --- The Prompt Code (embedded) ---
read -r -d '' PROMPT_CODE << 'PROMPT_EOF' || true
# --- Prompt ---
_T=""

function __has_sudo() {
    [[ $EUID -eq 0 ]] && return 0
    groups | grep -qE '\b(sudo|wheel)\b' && return 0
    return 1
}

function __generate_prompt() {
    local RESET="\[\\033[0m\]"
    local HOST_BG="\[\\033[48;5;25m\]"
    local HOST_FG="\[\\033[38;5;253m\]"
    local TRI1="\[\\033[0;38;5;25;48;5;13m\]${_T}"

    if [[ -f /.dockerenv ]] || grep -q 'lxc\|docker\|containerd' /proc/1/cgroup 2>/dev/null; then
        HOST_BG="\[\\033[48;5;28m\]"
        TRI1="\[\\033[0;38;5;28;48;5;13m\]${_T}"
    elif [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        HOST_BG="\[\\033[48;5;130m\]"
        TRI1="\[\\033[0;38;5;130;48;5;13m\]${_T}"
    fi

    local USER_BG="\[\\033[48;5;13m\]"
    local USER_FG=$(__has_sudo && echo "\[\\033[1;33m\]" || echo "\[\\033[38;5;244m\]")
    local TRI2="\[\\033[0;38;5;13;48;5;239m\]${_T}"

    local DIR_BG="\[\\033[48;5;239m\]"
    local DIR_FG="\[\\033[38;5;253m\]"
    local GIT_STATUS=""

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        DIR_FG="\[\\033[1;38;5;166m\]"
        [[ -n $(git status --porcelain 2>/dev/null) ]] && DIR_FG="\[\\033[1;38;5;178m\]"

        local REMOTE=$(git remote get-url origin 2>/dev/null)
        if [[ "$REMOTE" =~ github\\.com ]]; then
            local ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            local SYNC_CACHE="/tmp/git-sync"
            local SYNC_THROTTLE=5
            local FRESH=0

            # Symbols
            local SYM_OK="\[\\033[1;38;5;46m\]✓"
            local SYM_DIFF="\[\\033[1;33m\]!"
            local SYM_FAIL="\[\\033[1;38;5;196m\]≠"
            local SYM_NOREMOTE="\[\\033[1;38;5;196m\]✗"
            local SYM_DEFAULT="\[\\033[1;33m\]?"

            if [[ -f "$SYNC_CACHE" ]]; then
                local MTIME=$(stat -c %Y "$SYNC_CACHE" 2>/dev/null)
                local NOW=$(date +%s)
                if [[ -n "$MTIME" ]] && (( NOW - MTIME < SYNC_THROTTLE )); then
                    FRESH=1
                    local VAL=$(cat "$SYNC_CACHE" 2>/dev/null)
                    case "$VAL" in
                        ✓) GIT_STATUS="$SYM_OK" ;;
                        !) GIT_STATUS="$SYM_DIFF" ;;
                        ≠) GIT_STATUS="$SYM_FAIL" ;;
                        *) GIT_STATUS="$SYM_DEFAULT" ;;
                    esac
                fi
            fi

            if [[ $FRESH -eq 0 ]]; then
                GIT_STATUS="$SYM_DEFAULT"
                (
                    cd "$ROOT" 2>/dev/null || exit
                    
                    timeout 4 git fetch origin --quiet 2>/dev/null || true
                    
                    B=$(git branch --show-current 2>/dev/null)
                    if [[ -n "$B" ]] && git rev-parse --verify "origin/$B" &>/dev/null; then
                        if git diff --quiet "origin/$B" 2>/dev/null && [[ -z $(git ls-files --others --exclude-standard) ]]; then
                            printf "✓" > "$SYNC_CACHE"
                        else
                            printf "!" > "$SYNC_CACHE"
                        fi
                    else
                        printf "≠" > "$SYNC_CACHE"
                    fi
                ) &>/dev/null & disown
            fi
        else
            GIT_STATUS="$SYM_NOREMOTE"
        fi
    fi

    local TRI3="\[\\033[0;38;5;239;49m\]${_T}"
    PS1="\n${HOST_FG}${HOST_BG} \h ${TRI1}${USER_FG}${USER_BG} \u ${TRI2}${DIR_FG}${DIR_BG} \w ${GIT_STATUS}${TRI3}${RESET}"
}

PROMPT_COMMAND=__generate_prompt
PROMPT_EOF

# --- Helper Functions ---

show_help() {
    cat << 'HELP'
ps1.sh - Git & GitHub Sync-Aware Bash Prompt Installer

Usage:
  curl -fsSL <URL> | bash -s -- [OPTIONS]

Options:
  -t, --try        Install ps1 command but don't add to .bashrc
                   Run 'ps1' manually to activate prompt in current session
  -p, --permanent  Add ps1 to .bashrc (useful after --remove or initial -t)
  -u, --update     Update ps1 command and .bashrc from latest version
  --remove         Remove ps1 from .bashrc only (keeps ps1 command)
  --uninstall      Remove both ps1 command and .bashrc configuration
  --help           Show this help message

Default behavior (no options): Install ps1 command and add to .bashrc

The prompt displays:
  - Hostname with color coding (green=container, orange=SSH, blue=local)
  - Username (yellow if sudo access, gray otherwise)
  - Current directory (orange for git repos, bright orange if uncommitted changes)
  - GitHub sync status (✓=synced, !=changes, ≠=no remote, ?=fetching)
HELP
    exit 0
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

backup_bashrc() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_PREFIX}.${timestamp}"
    cp "$BASHRC" "$backup_file"
    log_info "Backed up .bashrc to $backup_file"
}

is_in_bashrc() {
    grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null
}

add_to_bashrc() {
    if is_in_bashrc; then
        log_info "ps1 already in .bashrc, skipping"
        return 0
    fi
    
    cat >> "$BASHRC" << EOF

$MARKER_START
# Source ps1 command
if [ -x "$PS1_PATH" ]; then
    source "$PS1_PATH"
fi
$MARKER_END
EOF
    log_info "Added ps1 to .bashrc"
}

remove_from_bashrc() {
    if ! is_in_bashrc; then
        log_info "ps1 not found in .bashrc"
        return 0
    fi
    
    backup_bashrc
    local temp_file=$(mktemp)
    sed "/$MARKER_START/,/$MARKER_END/d" "$BASHRC" > "$temp_file"
    mv "$temp_file" "$BASHRC"
    log_info "Removed ps1 from .bashrc"
}

install_ps1_command() {
    mkdir -p "$INSTALL_DIR"
    
    # Write the prompt code to the install location
    cat > "$PS1_PATH" << 'SCRIPT_EOF'
#!/usr/bin/env bash
# ps1 - Git & GitHub Sync-Aware Bash Prompt
# Run 'ps1' to activate the prompt in current session
# Run 'ps1 -u' to update, 'ps1 --remove' to remove from bashrc, etc.

INSTALL_DIR="$HOME/.local/bin"
PS1_PATH="$INSTALL_DIR/ps1"
BASHRC="$HOME/.bashrc"
MARKER_START="# --- PS1_START ---"
MARKER_END="# --- PS1_END ---"
BACKUP_PREFIX="$HOME/.bashrc.ps1_backup"

# Embedded prompt code
_T=""

function __has_sudo() {
    [[ $EUID -eq 0 ]] && return 0
    groups | grep -qE '\b(sudo|wheel)\b' && return 0
    return 1
}

function __generate_prompt() {
    local RESET="\[\\033[0m\]"
    local HOST_BG="\[\\033[48;5;25m\]"
    local HOST_FG="\[\\033[38;5;253m\]"
    local TRI1="\[\\033[0;38;5;25;48;5;13m\]${_T}"

    if [[ -f /.dockerenv ]] || grep -q 'lxc\|docker\|containerd' /proc/1/cgroup 2>/dev/null; then
        HOST_BG="\[\\033[48;5;28m\]"
        TRI1="\[\\033[0;38;5;28;48;5;13m\]${_T}"
    elif [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        HOST_BG="\[\\033[48;5;130m\]"
        TRI1="\[\\033[0;38;5;130;48;5;13m\]${_T}"
    fi

    local USER_BG="\[\\033[48;5;13m\]"
    local USER_FG=$(__has_sudo && echo "\[\\033[1;33m\]" || echo "\[\\033[38;5;244m\]")
    local TRI2="\[\\033[0;38;5;13;48;5;239m\]${_T}"

    local DIR_BG="\[\\033[48;5;239m\]"
    local DIR_FG="\[\\033[38;5;253m\]"
    local GIT_STATUS=""

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        DIR_FG="\[\\033[1;38;5;166m\]"
        [[ -n $(git status --porcelain 2>/dev/null) ]] && DIR_FG="\[\\033[1;38;5;178m\]"

        local REMOTE=$(git remote get-url origin 2>/dev/null)
        if [[ "$REMOTE" =~ github\\.com ]]; then
            local ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            local SYNC_CACHE="/tmp/git-sync"
            local SYNC_THROTTLE=5
            local FRESH=0

            local SYM_OK="\[\\033[1;38;5;46m\]✓"
            local SYM_DIFF="\[\\033[1;33m\]!"
            local SYM_FAIL="\[\\033[1;38;5;196m\]≠"
            local SYM_NOREMOTE="\[\\033[1;38;5;196m\]✗"
            local SYM_DEFAULT="\[\\033[1;33m\]?"

            if [[ -f "$SYNC_CACHE" ]]; then
                local MTIME=$(stat -c %Y "$SYNC_CACHE" 2>/dev/null)
                local NOW=$(date +%s)
                if [[ -n "$MTIME" ]] && (( NOW - MTIME < SYNC_THROTTLE )); then
                    FRESH=1
                    local VAL=$(cat "$SYNC_CACHE" 2>/dev/null)
                    case "$VAL" in
                        ✓) GIT_STATUS="$SYM_OK" ;;
                        !) GIT_STATUS="$SYM_DIFF" ;;
                        ≠) GIT_STATUS="$SYM_FAIL" ;;
                        *) GIT_STATUS="$SYM_DEFAULT" ;;
                    esac
                fi
            fi

            if [[ $FRESH -eq 0 ]]; then
                GIT_STATUS="$SYM_DEFAULT"
                (
                    cd "$ROOT" 2>/dev/null || exit
                    timeout 4 git fetch origin --quiet 2>/dev/null || true
                    B=$(git branch --show-current 2>/dev/null)
                    if [[ -n "$B" ]] && git rev-parse --verify "origin/$B" &>/dev/null; then
                        if git diff --quiet "origin/$B" 2>/dev/null && [[ -z $(git ls-files --others --exclude-standard) ]]; then
                            printf "✓" > "$SYNC_CACHE"
                        else
                            printf "!" > "$SYNC_CACHE"
                        fi
                    else
                        printf "≠" > "$SYNC_CACHE"
                    fi
                ) &>/dev/null & disown
            fi
        else
            GIT_STATUS="$SYM_NOREMOTE"
        fi
    fi

    local TRI3="\[\\033[0;38;5;239;49m\]${_T}"
    PS1="\n${HOST_FG}${HOST_BG} \h ${TRI1}${USER_FG}${USER_BG} \u ${TRI2}${DIR_FG}${DIR_BG} \w ${GIT_STATUS}${TRI3}${RESET}"
}

PROMPT_COMMAND=__generate_prompt

# Handle command-line arguments when sourced
case "${1:-}" in
    -u|--update)
        log_info "Updating ps1..."
        curl -fsSL "https://raw.githubusercontent.com/USER/REPO/main/ps1.sh" | bash -s -- -u
        ;;
    --remove)
        if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
            backup_file="${BACKUP_PREFIX}.$(date +%Y%m%d_%H%M%S)"
            cp "$BASHRC" "$backup_file"
            temp_file=$(mktemp)
            sed "/$MARKER_START/,/$MARKER_END/d" "$BASHRC" > "$temp_file"
            mv "$temp_file" "$BASHRC"
            echo "[INFO] Removed ps1 from .bashrc (backup: $backup_file)"
        else
            echo "[INFO] ps1 not in .bashrc"
        fi
        ;;
    --uninstall)
        rm -f "$PS1_PATH"
        if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
            backup_file="${BACKUP_PREFIX}.$(date +%Y%m%d_%H%M%S)"
            cp "$BASHRC" "$backup_file"
            temp_file=$(mktemp)
            sed "/$MARKER_START/,/$MARKER_END/d" "$BASHRC" > "$temp_file"
            mv "$temp_file" "$BASHRC"
            echo "[INFO] Uninstalled ps1 completely (backup: $backup_file)"
        else
            echo "[INFO] Removed ps1 command"
        fi
        ;;
    -p|--permanent)
        if ! grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
            echo "" >> "$BASHRC"
            echo "$MARKER_START" >> "$BASHRC"
            echo "# Source ps1 command" >> "$BASHRC"
            echo "if [ -x \"$PS1_PATH\" ]; then" >> "$BASHRC"
            echo "    source \"$PS1_PATH\"" >> "$BASHRC"
            echo "fi" >> "$BASHRC"
            echo "$MARKER_END" >> "$BASHRC"
            echo "[INFO] Added ps1 to .bashrc"
        else
            echo "[INFO] ps1 already in .bashrc"
        fi
        ;;
    -t|--try)
        echo "[INFO] Try mode: run 'source $PS1_PATH' to activate in current session"
        ;;
    -h|--help|"")
        cat << 'HELPTEXT'
ps1 - Git & GitHub Sync-Aware Bash Prompt

Usage:
  ps1              Activate prompt in current session
  ps1 -t           Show activation command
  ps1 -u           Update from GitHub
  ps1 --remove     Remove from .bashrc only
  ps1 --uninstall  Remove completely
  ps1 -p           Add to .bashrc
  ps1 --help       Show this help
HELPTEXT
        ;;
    *)
        echo "[ERROR] Unknown option: $1"
        echo "Run 'ps1 --help' for usage"
        exit 1
        ;;
esac
SCRIPT_EOF

    chmod +x "$PS1_PATH"
    log_info "Installed ps1 command to $PS1_PATH"
    
    # Check if INSTALL_DIR is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_info "Note: $INSTALL_DIR may not be in your PATH"
        log_info "Add 'export PATH=\"$INSTALL_DIR:\$PATH\"' to your .bashrc if 'ps1' command is not found"
    fi
}

update_ps1() {
    log_info "Updating ps1..."
    # Re-run installation which overwrites the file
    install_ps1_command
    
    # Update bashrc entry if present
    if is_in_bashrc; then
        remove_from_bashrc
        add_to_bashrc
    fi
    
    log_info "Update complete"
}

uninstall_all() {
    if [ -f "$PS1_PATH" ]; then
        rm -f "$PS1_PATH"
        log_info "Removed ps1 command"
    fi
    
    if is_in_bashrc; then
        remove_from_bashrc
    fi
    
    log_info "Uninstall complete"
}

# --- Main Logic ---

# Parse arguments
ACTION="install"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--try)
            ACTION="try"
            shift
            ;;
        -p|--permanent)
            ACTION="permanent"
            shift
            ;;
        -u|--update)
            ACTION="update"
            shift
            ;;
        --remove)
            ACTION="remove"
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Execute action
case "$ACTION" in
    install)
        backup_bashrc
        install_ps1_command
        add_to_bashrc
        log_info "Installation complete! Open a new terminal or run 'source $BASHRC'"
        ;;
    try)
        install_ps1_command
        log_info "Try mode: ps1 command installed but not added to .bashrc"
        log_info "To activate now: source $PS1_PATH"
        log_info "To make permanent later: ps1 -p"
        ;;
    permanent)
        if [ ! -f "$PS1_PATH" ]; then
            log_error "ps1 command not found at $PS1_PATH"
            log_error "Run without options first to install, or use -t to install without adding to .bashrc"
            exit 1
        fi
        backup_bashrc
        add_to_bashrc
        log_info "Added ps1 to .bashrc"
        ;;
    update)
        if [ ! -f "$PS1_PATH" ]; then
            log_error "ps1 not installed, cannot update"
            exit 1
        fi
        update_ps1
        ;;
    remove)
        remove_from_bashrc
        log_info "ps1 removed from .bashrc (command still available at $PS1_PATH)"
        ;;
    uninstall)
        uninstall_all
        ;;
esac
