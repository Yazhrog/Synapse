#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
#|-/ /--| Shared Utilities    |-/ /--|#
#|/ /---+---------------------+/ /---|#

if [ -z "$BASH_VERSION" ]; then
    echo "Error: Run the installer with bash."
    return 1 2>/dev/null || exit 1
fi

export HAS_GUM=$(command -v gum &>/dev/null && echo 1 || echo 0)

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Colors                                                                │
# ╰───────────────────────────────────────────────────────────────────────╯

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Logging                                                               │
# ╰───────────────────────────────────────────────────────────────────────╯

log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_info()  { echo -e "  ${BLUE}·${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "  ${RED}✗${NC} $1" >&2; }
die()       { echo ""; log_error "$1"; exit 1; }

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step Header                                                           │
# ╰───────────────────────────────────────────────────────────────────────╯

step() {
    local num="$1" label="$2"
    echo ""
    if [[ $HAS_GUM -eq 1 ]]; then
        gum style \
            --foreground=14 --bold \
            --border-foreground=8 --border normal \
            --padding "0 1" \
            "[$num/$TOTAL_STEPS]  $label"
    else
        echo -e "${BOLD}${CYAN}  [$num/$TOTAL_STEPS]  $label${NC}"
        echo -e "  ${DIM}$(printf '%.0s─' {1..50})${NC}"
    fi
    echo ""
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Spinner — wraps a long-running command                                │
# │ Usage: spin "label" cmd [args...]                                     │
# │ Exit code is propagated.                                              │
# ╰───────────────────────────────────────────────────────────────────────╯

spin() {
    local msg="$1"; shift
    if [[ $HAS_GUM -eq 1 ]]; then
        gum spin --spinner dot --title " $msg" -- "$@"
    else
        log_info "$msg"
        "$@" &>/dev/null
    fi
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Confirm — yes/no prompt with fallback                                 │
# │ Usage: confirm "Question?" && do_thing                                │
# ╰───────────────────────────────────────────────────────────────────────╯

confirm() {
    local msg="${1:-Continue?}"
    if [[ $HAS_GUM -eq 1 ]]; then
        gum confirm "$msg"
    else
        read -rp "  $msg [y/N] " _ans < /dev/tty
        [[ "$_ans" =~ ^[Yy]$ ]]
    fi
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Choose — single-select menu with fallback                             │
# │ Usage: result=$(choose "Prompt" "opt1" "opt2" ...)                   │
# ╰───────────────────────────────────────────────────────────────────────╯

choose() {
    local prompt="$1"; shift
    if [[ $HAS_GUM -eq 1 ]]; then
        printf '%s\n' "$@" | gum choose --header "$prompt" --cursor "> "
    else
        echo -e "  ${BOLD}$prompt${NC}"
        local i=1
        for opt in "$@"; do
            echo "    $i) $opt"
            i=$(( i + 1 ))
        done
        echo ""
        read -rp "  Choice: " _idx < /dev/tty
        local _i=1
        for opt in "$@"; do
            [[ "$_i" -eq "$_idx" ]] && { echo "$opt"; return 0; }
            _i=$(( _i + 1 ))
        done
        echo ""
    fi
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Text input with fallback                                              │
# │ Usage: val=$(gum_input "Prompt" "placeholder")                        │
# ╰───────────────────────────────────────────────────────────────────────╯

gum_input() {
    local prompt="$1" placeholder="${2:-}"
    if [[ $HAS_GUM -eq 1 ]]; then
        gum input --prompt "$prompt " --placeholder "$placeholder" --width 50
    else
        read -rp "  $prompt " _val < /dev/tty
        echo "$_val"
    fi
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Divider                                                               │
# ╰───────────────────────────────────────────────────────────────────────╯

divider() {
    if [[ $HAS_GUM -eq 1 ]]; then
        gum style --foreground=8 "  $(printf '%.0s─' {1..50})"
    else
        echo -e "  ${DIM}$(printf '%.0s─' {1..50})${NC}"
    fi
}
