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
check_cmd "rfkill"
check_cmd "sensors"

echo ""
echo "── SCREENSHOT ───────────────────────────────────────────────────"
if [[ -x "$HOME/.local/share/rishot/bin/rishot" ]]; then
    log_installed "rishot"
else
    log_missing "rishot  (installed by install step 4 — re-run the installer)"
fi

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
    if echo "$plugin_list" | grep -qi "scrolloverview"; then
        log_installed "plugin: scrolloverview"
    else
        log_missing "plugin: scrolloverview  (run: hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git && hyprpm enable scrolloverview)"
    fi
else
    log_missing "hyprpm (needed to check scrolloverview status)"
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

REPO_PATH_FILE="$HOME/.config/Synapse/repo-path"
if [[ -f "$REPO_PATH_FILE" ]]; then
    REPO_DIR="$(< "$REPO_PATH_FILE")"
    if [[ -d "$REPO_DIR/config" ]]; then
        log_installed "repo-path → $REPO_DIR"
    else
        log_missing "repo-path points at $REPO_DIR, which has no config/ — re-run boot.sh"
        REPO_DIR=""
    fi
else
    log_missing "~/.config/Synapse/repo-path  (run boot.sh to create it)"
    REPO_DIR=""
fi

if [[ -d "$HOME/.config/Synapse" ]]; then
    log_installed "~/.config/Synapse  (user config)"
else
    log_missing "~/.config/Synapse  (user config)"
fi

echo ""
echo "── SYMLINK HEALTH ───────────────────────────────────────────────"

# Every deployed config should be a symlink resolving into the repo. A plain
# file here means the link was replaced by a copy, and `git pull` silently
# stopped updating it — exactly the failure this deployment model exists to
# prevent, so it is worth reporting loudly.
if [[ -n "$REPO_DIR" && -f "$REPO_DIR/install/lib/manifest.sh" ]]; then
    # shellcheck source=install/lib/manifest.sh
    source "$REPO_DIR/install/lib/manifest.sh"

    LINK_OK=0; LINK_BAD=0; LINK_GONE=0
    declare -a LINK_PROBLEMS=()

    _check_link() {
        local dest="$HOME/$1"
        if [[ -L "$dest" ]]; then
            local tgt; tgt="$(readlink -f "$dest" 2>/dev/null)"
            if [[ "$tgt" == "$(readlink -f "$REPO_DIR")"/* ]]; then
                LINK_OK=$((LINK_OK + 1))
            else
                LINK_BAD=$((LINK_BAD + 1))
                LINK_PROBLEMS+=("~/$1 → ${tgt:-<broken>} (outside the repo)")
            fi
        elif [[ -e "$dest" ]]; then
            LINK_BAD=$((LINK_BAD + 1))
            LINK_PROBLEMS+=("~/$1 is a real file, not a symlink — updates won't reach it")
        else
            LINK_GONE=$((LINK_GONE + 1))
            LINK_PROBLEMS+=("~/$1 is missing")
        fi
    }

    for _entry in "${SYNAPSE_LINK_DIRS[@]}"; do
        _check_link "${_entry#*|}"
    done
    for _entry in "${SYNAPSE_LINK_FILES[@]}"; do
        _src="${_entry%%|*}"; _dst="${_entry#*|}"
        if [[ "$_src" == */ ]]; then
            # Recursive entry: verify each file the repo currently ships, minus
            # the ones the manifest deliberately hands over as copies.
            while IFS= read -r _f; do
                _rel="${_f#"$REPO_DIR/${_src%/}/"}"
                _skip=0
                for _ex in "${SYNAPSE_LINK_EXCLUDE[@]}"; do
                    if [[ "${_src%/}/$_rel" == "$_ex" ]]; then _skip=1; break; fi
                done
                if [[ $_skip -eq 1 ]]; then continue; fi
                _check_link "${_dst%/}/$_rel"
            done < <(find "$REPO_DIR/${_src%/}" -type f 2>/dev/null)
        else
            _check_link "$_dst"
        fi
    done

    if [[ $LINK_BAD -eq 0 && $LINK_GONE -eq 0 ]]; then
        log_installed "$LINK_OK deployed path(s), all linked into the repo"
    else
        log_installed "$LINK_OK deployed path(s) correctly linked"
        for _p in "${LINK_PROBLEMS[@]}"; do
            log_missing "$_p"
        done
        log_info "Fix with:  $REPO_DIR/install/link.sh"
    fi
else
    log_optional "manifest not available — skipping symlink checks"
fi

# Synapse should be quickshell's "default" config, which is what lets
# `qs ipc call ...` work without -c in the generated keybinds.
if [[ -f "$HOME/.config/quickshell/shell.qml" ]]; then
    log_installed "quickshell 'default' config resolves"
else
    log_missing "~/.config/quickshell/shell.qml — keybinds calling 'qs ipc' will fail"
fi

echo ""
echo "── PACKAGES (from install/steps/02-packages.sh) ────────────────"

# Read PACMAN_DEPS/AUR_DEPS straight out of 02-packages.sh as plain text rather
# than sourcing it — that script installs packages at the top level (pacman -Syu,
# pacman_install, aur_install), which is not something a validator should trigger.
extract_array() {  # $1=file $2=ARRAY_NAME -> newline-separated package names
    awk -v n="$2" '$0 ~ "^"n"=\\(" {f=1; next} f && /^\)/{f=0} f' "$1" \
      | sed -e 's/#.*$//' | tr -s ' \t' '\n' | sed '/^[[:space:]]*$/d'
}

if [[ -n "$REPO_DIR" && -f "$REPO_DIR/install/steps/02-packages.sh" ]]; then
    PKG_FILE="$REPO_DIR/install/steps/02-packages.sh"
    mapfile -t PACMAN_PKGS < <(extract_array "$PKG_FILE" PACMAN_DEPS)
    mapfile -t AUR_PKGS    < <(extract_array "$PKG_FILE" AUR_DEPS)

    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        AUR_HELPER=""
    fi

    # Packages already reported above via a CLI-based check — skip so they
    # aren't flagged twice under two different names.
    SKIP_PKG_CHECK=(quickshell ghostty hyprland hyprlock hypridle hyprpolkitagent
        wf-recorder cava wtype brightnessctl upower playerctl rfkill sunsetr
        awww matugen cliphist envycontrol auto-cpufreq nbfc-linux
        wayland-idle-inhibitor-git bibata-cursor-theme whitesur-icon-theme)

    _pkg_skipped() {
        local p="$1"
        for s in "${SKIP_PKG_CHECK[@]}"; do [[ "$p" == "$s" ]] && return 0; done
        return 1
    }

    for pkg in "${PACMAN_PKGS[@]}"; do
        _pkg_skipped "$pkg" && continue
        if pacman -Qi "$pkg" &>/dev/null; then
            log_installed "$pkg (pacman)"
        else
            log_missing "$pkg (pacman)"
        fi
    done

    if [[ -n "$AUR_HELPER" ]]; then
        for pkg in "${AUR_PKGS[@]}"; do
            _pkg_skipped "$pkg" && continue
            if "$AUR_HELPER" -Q "$pkg" &>/dev/null; then
                log_installed "$pkg (AUR)"
            else
                log_missing "$pkg (AUR)"
            fi
        done
    else
        log_missing "no AUR helper (yay/paru) found — cannot verify ${#AUR_PKGS[@]} AUR package(s)"
    fi
else
    log_optional "install/steps/02-packages.sh not available — skipping package checks"
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
