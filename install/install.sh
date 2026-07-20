#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Arch Installer      |-/ /--|#
#|/ /---+---------------------+/ /---|#
#  Invoked by boot.sh:  $1=HYPRLAND_CONF  $2=BACKUP_DIR  $3=REPO_DIR

set -eo pipefail

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Arguments                                                             │
# ╰───────────────────────────────────────────────────────────────────────╯

HYPRLAND_CONF="${1:?Missing arg: HYPRLAND_CONF path}"
BACKUP_DIR="${2:?Missing arg: BACKUP_DIR}"
REPO_DIR="${3:-$HOME/.local/src/Synapse}"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Utilities                                                             │
# ╰───────────────────────────────────────────────────────────────────────╯

# gum is bootstrapped by boot.sh; this is a safety net for direct invocation
if ! command -v gum &>/dev/null; then
    echo "  Installing gum for a better install experience..."
    sudo pacman -S --needed --noconfirm gum 2>/dev/null || true
fi

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/utils.sh
source "$INSTALL_DIR/utils.sh"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Shared State                                                          │
# ╰───────────────────────────────────────────────────────────────────────╯

declare -a FAILED_PKGS=()
AUR_HELPER=""
TOTAL_STEPS=8

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Steps                                                                 │
# ╰───────────────────────────────────────────────────────────────────────╯

STEPS_DIR="$INSTALL_DIR/steps"

source "$STEPS_DIR/01-aur-helper.sh"
source "$STEPS_DIR/02-packages.sh"
source "$STEPS_DIR/03-services.sh"
source "$STEPS_DIR/04-plugins.sh"
source "$STEPS_DIR/05-config.sh"
source "$STEPS_DIR/06-shell-config.sh"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Summary                                                               │
# ╰───────────────────────────────────────────────────────────────────────╯

echo ""
divider

if [[ ${#FAILED_PKGS[@]} -eq 0 ]]; then
    log_ok "Arch installation complete — no failures."
    echo ""
else
    log_warn "Installation finished with ${#FAILED_PKGS[@]} unresolved package(s)."
    echo ""
    echo -e "  ${BOLD}Retry commands:${NC}"

    for entry in "${FAILED_PKGS[@]}"; do
        _src="${entry%%:*}"
        _pkg="${entry#*:}"
        _pkg_name="${_pkg%% (*}"
        if [[ "$_src" == "pacman" ]]; then
            log_info "sudo pacman -S $_pkg_name"
        else
            log_info "$AUR_HELPER -S $_pkg_name"
        fi
    done

    echo ""
    echo -e "  ${BOLD}Resolving hard package conflicts (ConflictsWith):${NC}"
    log_info "Find what conflicts:  pacman -Si <pkg> | grep Conflicts"
    log_info "Remove the old one:   sudo pacman -Rdd <conflicting-pkg>"
    log_info "Then retry:           sudo pacman -S <pkg>"
    echo ""
fi

exit 0
