#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Validator           |-/ /--|#
#|/ /---+---------------------+/ /---|#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTALLED=0
MISSING=0
OPTIONAL_MISSING=0

log_installed() { echo -e "${GREEN}[✓]${NC} $1"; ((INSTALLED++)); }
log_missing()   { echo -e "${RED}[✗]${NC} $1 ${YELLOW}(MISSING)${NC}"; ((MISSING++)); }
log_optional()  { echo -e "${YELLOW}[○]${NC} $1 ${YELLOW}(optional)${NC}"; ((OPTIONAL_MISSING++)); }
log_info()      { echo -e "${BLUE}[i]${NC} $1"; }

check_cmd() {
    if command -v "$1" &>/dev/null; then log_installed "$1"
    else log_missing "$1"; fi
}
check_opt() {
    if command -v "$1" &>/dev/null; then log_installed "$1 (optional)"
    else log_optional "$1"; fi
}

clear
echo -e "${BOLD}Synapse — Post-Installation Validator${NC}"
echo ""

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    log_info "Distribution: $ID"
fi
echo ""

echo "── CORE RUNTIME ─────────────────────────────────────────────────"
check_cmd "quickshell"
check_cmd "hyprland"
check_cmd "hyprctl"
check_cmd "hyprpm"

echo ""
echo "── TERMINAL ─────────────────────────────────────────────────────"
check_cmd "ghostty"

echo ""
echo "── QT6 & RENDERING ──────────────────────────────────────────────"
check_cmd "qt6ct"
if command -v qdbus6 &>/dev/null || command -v qdbus &>/dev/null; then
    log_installed "qt6-base (qdbus)"
else
    log_missing "qt6-base (qdbus / qdbus6)"
fi

echo ""
echo "── AUDIO ────────────────────────────────────────────────────────"
if command -v pactl &>/dev/null || command -v pacmd &>/dev/null; then
    log_installed "pipewire/pulseaudio (pactl)"
else
    log_missing "pipewire-pulse (pactl)"
fi
check_cmd "pamixer"
check_cmd "playerctl"

echo ""
echo "── SYSTEM TOOLS ─────────────────────────────────────────────────"
check_cmd "bluetoothctl"
check_cmd "brightnessctl"
check_cmd "upower"
check_cmd "notify-send"
check_cmd "pkexec"
check_cmd "python"
check_cmd "wl-copy"
check_cmd "slurp"
check_cmd "grim"
check_cmd "rfkill"
check_cmd "sensors"

echo ""
echo "── SCREENSHOT ───────────────────────────────────────────────────"
check_cmd "grim"
check_cmd "slurp"
check_opt "satty"

echo ""
echo "── SCREEN RECORDING ─────────────────────────────────────────────"
check_cmd "wf-recorder"
check_cmd "cava"

echo ""
echo "── WALLPAPER & THEMING ──────────────────────────────────────────"
check_cmd "magick"
check_opt "awww"
check_opt "matugen"

echo ""
echo "── CLIPBOARD ────────────────────────────────────────────────────"
check_cmd "wtype"
check_opt "cliphist"

echo ""
echo "── POWER & HARDWARE ─────────────────────────────────────────────"
check_opt "envycontrol"
check_opt "auto-cpufreq"
check_opt "nbfc"
check_opt "hyprshutdown"

echo ""
echo "── HYPRLAND ECOSYSTEM ───────────────────────────────────────────"
check_cmd "hyprlock"
check_cmd "hypridle"
check_cmd "sunsetr"
check_opt "wayland-idle-inhibitor"

echo ""
echo "── HYPRLAND PLUGINS ─────────────────────────────────────────────"
if command -v hyprpm &>/dev/null; then
    plugin_list=$(hyprpm list 2>/dev/null)
    if echo "$plugin_list" | grep -qi "hymission"; then
        log_installed "plugin: hymission"
    else
        log_missing "plugin: hymission  (run: hyprpm add https://github.com/gfhdhytghd/hymission && hyprpm enable hymission)"
    fi
else
    log_missing "hyprpm (needed to check hymission status)"
fi

if [[ -f "$HOME/.config/hypr/plugin/hyprselect/hyprselect.so" ]]; then
    log_installed "plugin: hyprselect (built)"
else
    log_missing "plugin: hyprselect  (built by install step 6 — re-run the installer or build it manually)"
fi

echo ""
echo "── FONTS ────────────────────────────────────────────────────────"
if fc-list | grep -qi "JetBrains Mono"; then
    log_installed "JetBrains Mono Nerd Font"
else
    log_missing "JetBrains Mono Nerd Font"
fi

echo ""
echo "── CONFIGURATION FILES ──────────────────────────────────────────"

if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    log_installed "~/.config/hypr/hyprland.lua"
else
    log_missing "~/.config/hypr/hyprland.lua"
fi

if [[ -d "$HOME/.config/hypr/modules" ]]; then
    log_installed "~/.config/hypr/modules/"
else
    log_missing "~/.config/hypr/modules/"
fi

if [[ -d "$HOME/.config/hypr/scripts" ]]; then
    log_installed "~/.config/hypr/scripts/"
else
    log_missing "~/.config/hypr/scripts/"
fi

if [[ -f "$HOME/.config/ghostty/config" ]]; then
    log_installed "~/.config/ghostty/config"
else
    log_optional "~/.config/ghostty/config"
fi

if [[ -d "$HOME/.local/src/Synapse" ]]; then
    log_installed "~/.local/src/Synapse  (source)"
else
    log_missing "~/.local/src/Synapse  (source)"
fi

if [[ -d "$HOME/.config/Synapse" ]]; then
    log_installed "~/.config/Synapse  (user config)"
else
    log_missing "~/.config/Synapse  (user config)"
fi

echo ""
echo "── BACKUPS ──────────────────────────────────────────────────────"
mapfile -t backups < <(ls -d "$HOME"/.config.backup-*-Synapse 2>/dev/null)
if [[ ${#backups[@]} -gt 0 ]]; then
    log_info "Found ${#backups[@]} Synapse backup(s):"
    for b in "${backups[@]}"; do echo -e "    ${BLUE}→${NC} ${b##*/}"; done
else
    log_optional "No Synapse config backups found"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo -e "${GREEN}✓ Installed:  $INSTALLED${NC}"
echo -e "${RED}✗ Missing:    $MISSING${NC}"
echo -e "${YELLOW}○ Optional:   $OPTIONAL_MISSING${NC}"
echo ""

if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All required dependencies are installed!${NC}"
    exit 0
else
    echo -e "${YELLOW}${BOLD}Some required dependencies are missing.${NC}"
    echo ""
    echo "  Re-run the installer:  bash boot.sh"
    echo "  Or install manually:   sudo pacman -S <pkg>  /  yay -S <pkg> / paru -S <pkg>"
    echo ""
    exit 1
fi
