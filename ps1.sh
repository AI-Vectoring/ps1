#!/usr/bin/env bash
#
# ps1.sh - Git & GitHub Sync-Aware Bash Prompt Installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AI-Vectoring/ps1/master/ps1.sh | bash -s -- [OPTIONS]
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
REPO_PS1_URL="https://raw.githubusercontent.com/AI-Vectoring/ps1/master/ps1.sh"
REPO_BASHRC_URL="https://raw.githubusercontent.com/AI-Vectoring/ps1/master/bashrc"

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

get_prompt_code() {
    curl -fsSL "$REPO_BASHRC_URL" | sed -n '/^# --- PROMPT_START ---/,/^PROMPT_COMMAND=__generate_prompt$/p'
}

install_ps1_command() {
    mkdir -p "$INSTALL_DIR"

    local prompt_code
    prompt_code=$(get_prompt_code)

    if [[ -z "$prompt_code" ]]; then
        log_error "Failed to get prompt code"
        exit 1
    fi

    cat > "$PS1_PATH" << 'HEADER_EOF'
#!/usr/bin/env bash
# ps1 - Git & GitHub Sync-Aware Bash Prompt
# Source to activate the prompt. Run with args to manage installation.

INSTALL_DIR="$HOME/.local/bin"
PS1_PATH="$INSTALL_DIR/ps1"
BASHRC="$HOME/.bashrc"
MARKER_START="# --- PS1_START ---"
MARKER_END="# --- PS1_END ---"
BACKUP_PREFIX="$HOME/.bashrc.ps1_backup"
REPO_PS1_URL="https://raw.githubusercontent.com/AI-Vectoring/ps1/master/ps1.sh"

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
HEADER_EOF

    printf '%s\n' "$prompt_code" >> "$PS1_PATH"

    cat >> "$PS1_PATH" << 'HANDLERS_EOF'

# Skip subcommand handling when sourced
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

case "${1:-}" in
    -u|--update)
        log_info "Updating ps1..."
        curl -fsSL "$REPO_PS1_URL" | bash -s -- --update
        ;;
    --remove)
        if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
            backup_file="${BACKUP_PREFIX}.$(date +%Y%m%d_%H%M%S)"
            cp "$BASHRC" "$backup_file"
            temp_file=$(mktemp)
            sed "/$MARKER_START/,/$MARKER_END/d" "$BASHRC" > "$temp_file"
            mv "$temp_file" "$BASHRC"
            log_info "Removed ps1 from .bashrc (backup: $backup_file)"
        else
            log_info "ps1 not in .bashrc"
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
            log_info "Uninstalled ps1 completely (backup: $backup_file)"
        else
            log_info "Removed ps1 command"
        fi
        ;;
    -p|--permanent)
        if ! grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
            {
                echo ""
                echo "$MARKER_START"
                echo "if [ -x \"$PS1_PATH\" ]; then source \"$PS1_PATH\"; fi"
                echo "$MARKER_END"
            } >> "$BASHRC"
            log_info "Added ps1 to .bashrc"
        else
            log_info "ps1 already in .bashrc"
        fi
        ;;
    --help|-h|"")
        cat << 'HELPTEXT'
ps1 - Git & GitHub Sync-Aware Bash Prompt

Usage:
  source ps1       Activate prompt in current session
  ps1 -u           Update from GitHub
  ps1 --remove     Remove from .bashrc only
  ps1 --uninstall  Remove completely
  ps1 -p           Add to .bashrc
  ps1 --help       Show this help
HELPTEXT
        ;;
    *)
        log_error "Unknown option: $1"
        exit 1
        ;;
esac
HANDLERS_EOF

    chmod +x "$PS1_PATH"
    log_info "Installed ps1 command to $PS1_PATH"

    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_info "Note: $INSTALL_DIR may not be in your PATH"
        log_info "Add 'export PATH=\"$INSTALL_DIR:\$PATH\"' to your .bashrc if 'ps1' command is not found"
    fi
}

update_ps1() {
    log_info "Updating ps1..."
    install_ps1_command

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
