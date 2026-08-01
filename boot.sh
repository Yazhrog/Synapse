#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Boot Script         |-/ /--|#
#|/ /---+---------------------+/ /---|#

set -eo pipefail

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Bootstrap                                                             │
# ╰───────────────────────────────────────────────────────────────────────╯

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Best-effort gum install before utils.sh is sourced
if ! command -v gum &>/dev/null; then
    echo "  Installing gum for a better install experience..."
    sudo pacman -S --needed --noconfirm gum 2>/dev/null || true
fi

# shellcheck source=install/utils.sh
if [[ -f "$SCRIPT_DIR/install/utils.sh" ]]; then
    source "$SCRIPT_DIR/install/utils.sh"
else
    # Fallback for the curl | bash bootstrap, which only downloads boot.sh.
    source <(curl -fsSL https://raw.githubusercontent.com/Yazhrog/Synapse/refs/heads/main/install/utils.sh)
fi

TOTAL_STEPS=5

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Trap                                                                  │
# ╰───────────────────────────────────────────────────────────────────────╯

trap 'echo ""; log_error "Installation aborted unexpectedly (line $LINENO)."; exit 1' ERR

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Banner                                                                │
# ╰───────────────────────────────────────────────────────────────────────╯

clear
echo -e "${BOLD}"
echo "   ▄████████ ▄██   ▄   ███▄▄▄▄      ▄████████    ▄███████▄    ▄████████    ▄████████" 
echo "  ███    ███ ███   ██▄ ███▀▀▀██▄   ███    ███   ███    ███   ███    ███   ███    ███" 
echo "  ███    █▀  ███▄▄▄███ ███   ███   ███    ███   ███    ███   ███    █▀    ███    █▀ " 
echo "  ███        ▀▀▀▀▀▀███ ███   ███   ███    ███   ███    ███   ███         ▄███▄▄▄    " 
echo "▀███████████ ▄██   ███ ███   ███ ▀███████████ ▀█████████▀  ▀███████████ ▀▀███▀▀▀    " 
echo "         ███ ███   ███ ███   ███   ███    ███   ███                 ███   ███    █▄ " 
echo "   ▄█    ███ ███   ███ ███   ███   ███    ███   ███           ▄█    ███   ███    ███" 
echo " ▄████████▀   ▀█████▀   ▀█   █▀    ███    █▀   ▄████▀       ▄████████▀    ██████████" 
echo -e "${NC}"
echo -e "  ${DIM}v0.1.0  ·  Synapse Shell + Hyprland LUA config${NC}"
echo ""

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 1 — Pre-Flight Checks                                            │
# ╰───────────────────────────────────────────────────────────────────────╯

step 1 "Pre-Flight Checks"

# OS
[[ "$OSTYPE" =~ ^linux ]] || die "This installer only supports Linux."
log_ok "Linux confirmed"

# Distro
DISTRO_TYPE=""
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    case "${ID:-}" in
        arch|manjaro|garuda|cachyos|endeavouros)
            log_ok "Distro: ${ID} (Arch-based)"
            DISTRO_TYPE="arch"
            ;;
        *)
            die "Unsupported distro: ${ID:-unknown}. Supported: Arch-based (arch, manjaro, garuda, cachyos, endeavouros)."
            ;;
    esac
else
    die "Cannot detect distro — /etc/os-release not found."
fi

# Hyprland session (warn only, don't abort)
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    log_warn "Not running inside a Hyprland session."
    log_info "Changes will apply after you restart Hyprland."
else
    log_ok "Hyprland session active"
fi

# Hyprland config
HYPR_DIR="$HOME/.config/hypr"
HYPRLAND_CONF=""
CONFIG_TYPE=""

# Hyprland loads .lua first when both exist; mirror that priority here so
# the installer always targets the file Hyprland is actually reading.
if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    HYPRLAND_CONF="$HYPR_DIR/hyprland.lua"
    CONFIG_TYPE="lua"
    if [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
        log_ok "Hyprland config: hyprland.lua  ${DIM}(hyprland.conf also present but ignored by Hyprland)${NC}"
    else
        log_ok "Hyprland config: hyprland.lua"
    fi
elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
    HYPRLAND_CONF="$HYPR_DIR/hyprland.conf"
    CONFIG_TYPE="conf"
    log_ok "Hyprland config: hyprland.conf"
    log_warn "hyprland.conf support is deprecated as of 0.55 and will be removed in a future release."
    log_info "Consider migrating to hyprland.lua — see https://wiki.hypr.land/Configuring/Start/"
else
    die "No Hyprland config found in $HYPR_DIR. Set up Hyprland first."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 2 — Backup                                                       │
# ╰───────────────────────────────────────────────────────────────────────╯

step 2 "Backup"

BACKUP_TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config.backup-${BACKUP_TS}-Synapse"
mkdir -p "$BACKUP_DIR"

if [[ -d "$HYPR_DIR" ]]; then
    spin "Backing up ~/.config/hypr..." cp -r "$HYPR_DIR" "$BACKUP_DIR/"
    log_ok "Backed up: ~/.config/hypr → $BACKUP_DIR"
else
    log_warn "~/.config/hypr not found — nothing to back up."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 3 — Repository                                                   │
# ╰───────────────────────────────────────────────────────────────────────╯

step 3 "Repository"

REPO_PARENT="$HOME/.local/src"
REPO_DIR="$REPO_PARENT/Synapse"
mkdir -p "$REPO_PARENT"

if [[ -d "$REPO_DIR/.git" ]]; then
    log_info "Existing clone found — updating..."
    spin "Fetching latest changes..." \
        git -C "$REPO_DIR" pull origin main
    log_ok "Repository updated: $REPO_DIR"
else
    # TODO: update this URL once the Synapse repo is published
    spin "Cloning Synapse..." \
        git clone -b main https://github.com/Yazhrog/Synapse.git "$REPO_DIR"
    log_ok "Repository cloned: $REPO_DIR"
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 4 — Distro-Specific Install                                      │
# ╰───────────────────────────────────────────────────────────────────────╯

step 4 "Arch Linux Installer"
echo ""

DISTRO_INSTALLER="$REPO_DIR/install/install.sh"
[[ -f "$DISTRO_INSTALLER" ]] || die "Installer not found: $DISTRO_INSTALLER"

chmod +x "$DISTRO_INSTALLER"
bash "$DISTRO_INSTALLER" "$HYPRLAND_CONF" "$BACKUP_DIR" "$REPO_DIR"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 5 — Done                                                         │
# ╰───────────────────────────────────────────────────────────────────────╯

step 5 "Done"

echo ""
log_ok "Synapse is installed."
echo ""
echo -e "  ${BOLD}Restart Hyprland to activate Synapse:${NC}"
log_info "Log out and log back in  ${DIM}(recommended)${NC}"
log_info "hyprctl dispatch exit"
log_info "Ctrl+Alt+Q               ${DIM}(if configured)${NC}"
echo ""
echo -e "  ${BOLD}First-run checklist:${NC}"
log_info "Edit ~/.config/hypr/modules/monitors.lua — set your monitor names"
log_info "Drop your ghostty config into ~/.config/ghostty/config if needed"
echo ""
echo -e "  ${BOLD}Paths:${NC}"
log_info "Shell config:  ~/.config/Synapse"
log_info "Hypr config:   ~/.config/hypr/"
log_info "Source:        $REPO_DIR"
echo ""

exit 0
