# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=999999
HISTFILESIZE=999999

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# enable color support of ls and handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias run=' _blah(){ lxc exec "$1" bash;}; _blah'

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# --- Prompt ---
#_T=$'\uE0B0'
#PS1="\n\[\033[38;5;253;48;5;25m\] \h \[\033[0;38;5;25;48;5;45m\]${_T}\[\033[1;33;45m\] \u \[\033[0;38;5;45;48;5;240m\]${_T}\[\033[38;5;253;48;5;240m\] \w \[\033[0;38;5;240;49m\]${_T}\[\033[1;38;5;208m\] \[\033[0m\]"
#PS1="\n\[\033[38;5;253;48;5;25m\] \h \[\033[0;38;5;25;45m\]${_T}\[\033[1;33;45m\] \u \[\033[0;35;48;5;240m\]${_T}\[\033[38;5;253;48;5;240m\] \w \[\033[0;38;5;240;49m\]${_T}\[\033[1;38;5;208m\] \[\033[0m\]"
#unset _T

# --- Aliases ---
alias dps="docker ps --format 'table {{.Image}} \t {{.ID}} \t {{.Names}} \t {{.Status}} \t {{.Ports}}'"
alias dpsa="docker ps -a --format 'table {{.Image}} \t {{.ID}} \t {{.Names}} \t {{.Status}} \t {{.Ports}}'"
alias lh="sed -rn 's/^\s*Host\s+(.*)\s*/\1/ip' ~/.ssh/config"
alias sshlist="sed -rn 's/^\s*Host\s+(.*)\s*/\1/ip' ~/.ssh/config"

#bash hi5

#export PATH="$PATH:/home/yosu/.modular/bin"
#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
#[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="/usr/local/Gambit/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export LC_COLLATE=C

# --- Custom ls Configuration ---
unalias ls 2>/dev/null
unset -f ls 2>/dev/null

ls() {
  if [[ $# -eq 0 ]]; then
    (
      shopt -s nullglob
      export LC_ALL=en_US.UTF-8
      local items=( _* [!_]* )
      command ls -U -d --color=auto --width=85 "${items[@]}" 2>/dev/null
    )
  else
    LC_ALL=en_US.UTF-8 command ls --color=auto --width=85 "$@"
  fi
}

# Disable history expansion to prevent ! interpretation
set +H 2>/dev/null

set +H 2>/dev/null

# --- DEFAULTS ---
SYNC_CACHE="/tmp/git-sync"
SYNC_THROTTLE=5

# Symbols
SYM_OK="\[\033[1;38;5;46m\]✓"
SYM_DIFF="\[\033[1;33m\]!"
SYM_FAIL="\[\033[1;38;5;196m\]≠"
SYM_NOREMOTE="\[\033[1;38;5;196m\]✗"
SYM_DEFAULT="\[\033[1;33m\]?"

_T=""

function __has_sudo() {
    [[ $EUID -eq 0 ]] && return 0
    groups | grep -qE '\b(sudo|wheel)\b' && return 0
    return 1
}

function __generate_prompt() {
    local RESET="\[\033[0m\]"
    local HOST_BG="\[\033[48;5;25m\]"
    local HOST_FG="\[\033[38;5;253m\]"
    local TRI1="\[\033[0;38;5;25;48;5;13m\]${_T}"

    if [[ -f /.dockerenv ]] || grep -q 'lxc\|docker\|containerd' /proc/1/cgroup 2>/dev/null; then
        HOST_BG="\[\033[48;5;28m\]"
        TRI1="\[\033[0;38;5;28;48;5;13m\]${_T}"
    elif [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        HOST_BG="\[\033[48;5;130m\]"
        TRI1="\[\033[0;38;5;130;48;5;13m\]${_T}"
    fi

    local USER_BG="\[\033[48;5;13m\]"
    local USER_FG=$(__has_sudo && echo "\[\033[1;33m\]" || echo "\[\033[38;5;244m\]")
    local TRI2="\[\033[0;38;5;13;48;5;239m\]${_T}"

    local DIR_BG="\[\033[48;5;239m\]"
    local DIR_FG="\[\033[38;5;253m\]"
    local GIT_STATUS=""

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        DIR_FG="\[\033[1;38;5;166m\]"
        [[ -n $(git status --porcelain 2>/dev/null) ]] && DIR_FG="\[\033[1;38;5;178m\]"

        local REMOTE=$(git remote get-url origin 2>/dev/null)
        if [[ "$REMOTE" =~ github\.com ]]; then
            local ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            local FRESH=0

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
                    
                    # FIXED: Removed 'if' gate. Fetch exit code 1 breaks logic.
                    # || true ensures comparison always runs after fetch attempt.
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

    local TRI3="\[\033[0;38;5;239;49m\]${_T}"
    PS1="\n${HOST_FG}${HOST_BG} \h ${TRI1}${USER_FG}${USER_BG} \u ${TRI2}${DIR_FG}${DIR_BG} \w ${GIT_STATUS}${TRI3}${RESET}"
}

PROMPT_COMMAND=__generate_prompt
