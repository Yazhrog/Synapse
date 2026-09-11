#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Boot Script         |-/ /--|#
#|/ /---+---------------------+/ /---|#

set -eo pipefail

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Bootstrap                                                             │
# ╰───────────────────────────────────────────────────────────────────────╯

# Under `curl | bash` BASH_SOURCE[0] is empty, so this resolves to the working
# directory rather than a checkout. That's fine — SYNAPSE_IS_CHECKOUT below is
# what decides whether to trust it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd)" || SCRIPT_DIR="$PWD"

# git is NOT part of Arch's `base`, and step 3 clones with it — on a fresh
# install this is the difference between working and aborting on line one.
if ! command -v git &>/dev/null; then
    echo "  Installing git..."
    sudo pacman -Sy --needed --noconfirm git || {
        echo "  Could not install git — install it and re-run: sudo pacman -S git" >&2
        exit 1
    }
fi

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
echo -e "  ${DIM}v0.2.0  ·  Synapse Shell + Hyprland LUA config${NC}"
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

# Hyprland config. Synapse deploys hyprland.lua itself, so a missing config is
# a fresh install, not an error — only an existing hyprland.conf is worth a word.
HYPR_DIR="$HOME/.config/hypr"

if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    log_ok "Hyprland config: hyprland.lua"
elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
    log_warn "Found hyprland.conf — Synapse installs hyprland.lua, which Hyprland loads first."
    log_info "Your hyprland.conf will be backed up and then ignored."
else
    log_info "No Hyprland config yet — Synapse will install one."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 2 — Repository                                                   │
# ╰───────────────────────────────────────────────────────────────────────╯
# The repo checkout is the live source: ~/.config is symlinked into it, so
# wherever this ends up is what the running desktop reads from.

step 2 "Repository"

# Only adopt $SCRIPT_DIR when it is unmistakably a Synapse checkout. Under
# `curl | bash` it is just the working directory, so checking for .git alone
# would happily adopt whatever unrelated repo the user happened to be sitting in.
if [[ -d "$SCRIPT_DIR/.git" \
   && -f "$SCRIPT_DIR/boot.sh" \
   && -f "$SCRIPT_DIR/install/lib/manifest.sh" \
   && -f "$SCRIPT_DIR/config/quickshell/shell.qml" ]]; then
    # Run from a clone the user manages themselves. Use it as-is and never pull
    # on their behalf — they may be mid-work or on a branch.
    REPO_DIR="$SCRIPT_DIR"
    log_ok "Using this checkout: $REPO_DIR"
    log_info "Synapse will run from here — 'git pull' updates your desktop directly."
else
    # curl | bash bootstrap: no local checkout to adopt.
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
fi

# The one place that records where the repo lives. autostart.lua, UpdateService
# and install/link.sh all read this instead of hardcoding a path.
mkdir -p "$HOME/.config/Synapse"
printf '%s\n' "$REPO_DIR" > "$HOME/.config/Synapse/repo-path"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 3 — Backup                                                       │
# ╰───────────────────────────────────────────────────────────────────────╯
# Snapshot every directory the manifest is about to touch, before it changes.
# The linker later files individually displaced files at the top level of the
# same backup dir; these whole-directory copies live under pre-install/.

step 3 "Backup"

BACKUP_TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config.backup-${BACKUP_TS}-Synapse"
mkdir -p "$BACKUP_DIR/pre-install"

# shellcheck source=install/lib/manifest.sh
source "$REPO_DIR/install/lib/manifest.sh"

# Every distinct destination directory named by the manifest, plus ~/.zshenv.
_backup_targets=()
for _entry in "${SYNAPSE_LINK_DIRS[@]}" "${SYNAPSE_LINK_FILES[@]}" "${SYNAPSE_COPY_ONCE[@]}"; do
    _dest="${_entry#*|}"
    case "$_dest" in
        .config/*/*) _dest=".config/$(echo "$_dest" | cut -d/ -f2)" ;;  # collapse to ~/.config/<app>
        .config/*)   _dest="${_dest%/}" ;;
    esac
    _backup_targets+=("$_dest")
done
_backup_targets+=(".zshenv")

_backed_up=0
while IFS= read -r _t; do
    [[ -e "$HOME/$_t" ]] || continue
    mkdir -p "$BACKUP_DIR/pre-install/$(dirname "$_t")"
    # -a preserves symlinks as symlinks, so the snapshot records what was
    # actually there rather than silently following links into the repo.
    cp -a "$HOME/$_t" "$BACKUP_DIR/pre-install/$_t" 2>/dev/null || true
    _backed_up=$((_backed_up + 1))
done < <(printf '%s\n' "${_backup_targets[@]}" | sort -u)

if [[ $_backed_up -gt 0 ]]; then
    log_ok "Backed up $_backed_up path(s) → $BACKUP_DIR/pre-install"
else
    log_info "Nothing to back up — clean system."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 4 — Distro-Specific Install                                      │
# ╰───────────────────────────────────────────────────────────────────────╯

step 4 "Arch Linux Installer"
echo ""

DISTRO_INSTALLER="$REPO_DIR/install/install.sh"
[[ -f "$DISTRO_INSTALLER" ]] || die "Installer not found: $DISTRO_INSTALLER"

chmod +x "$DISTRO_INSTALLER"
bash "$DISTRO_INSTALLER" "$BACKUP_DIR" "$REPO_DIR"

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
log_info "Multi-monitor? Set your layout in ~/.config/Synapse/monitors.lua"
log_info "${DIM}(a single display is auto-detected — nothing to do)${NC}"
log_info "Set your night-light location:  sunsetr geo"
echo ""
echo -e "  ${BOLD}Paths:${NC}"
log_info "Source repo:   $REPO_DIR   ${DIM}← ~/.config links here${NC}"
log_info "Your settings: ~/.config/Synapse"
echo ""
echo -e "  ${BOLD}Updating:${NC}"
log_info "git -C $REPO_DIR pull    ${DIM}(then reload — configs are symlinked)${NC}"
log_info "$REPO_DIR/install/link.sh  ${DIM}(only if an update adds a new file)${NC}"
echo ""

exit 0
