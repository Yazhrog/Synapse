#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Packages            |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 2 & 3 — Packages
# Installs all pacman and AUR dependencies.
# Appends failures to FAILED_PKGS (defined in install.sh) rather than aborting.

# ╭───────────────────────────────────────────────────────────────────────╮
# │ pacman_install                                                        │
# ╰───────────────────────────────────────────────────────────────────────╯
# Three-attempt strategy:
#   1. Bulk install (fastest; skips already-present via --needed)
#   2. Per-package retry (isolates the one conflicting package)
#   3. Per-package with --overwrite (resolves file-ownership conflicts)
pacman_install() {
    local -a pkgs=("$@")
    local total=${#pkgs[@]}

    if spin "Installing $total packages via pacman..." \
            sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
        log_ok "All $total packages installed."
        return 0
    fi

    echo ""
    log_warn "Bulk install hit a conflict — retrying individually..."
    echo ""

    local installed=0 already=0

    for pkg in "${pkgs[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            already=$(( already + 1 ))
            continue
        fi

        if spin "  $pkg" sudo pacman -S --needed --noconfirm "$pkg"; then
            log_ok "$pkg"
            installed=$(( installed + 1 ))
            continue
        fi

        if spin "  $pkg (overwrite)" sudo pacman -S --needed --noconfirm --overwrite='*' "$pkg"; then
            log_warn "$pkg  (installed with --overwrite)"
            installed=$(( installed + 1 ))
            continue
        fi

        log_error "$pkg  (hard conflict — see summary)"
        FAILED_PKGS+=("pacman:$pkg")
    done

    echo ""
    log_ok "$installed installed,  $already already present"
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ aur_install                                                           │
# ╰───────────────────────────────────────────────────────────────────────╯
# Installs AUR packages individually; failures are tracked but non-fatal.
aur_install() {
    local helper="$1"; shift
    local -a pkgs=("$@")

    echo ""
    for pkg in "${pkgs[@]}"; do
        if $helper -Q "$pkg" &>/dev/null; then
            log_ok "$pkg  ${DIM}(already installed)${NC}"
            continue
        fi

        if spin "  $pkg" $helper -S --noconfirm "$pkg"; then
            log_ok "$pkg"
        else
            log_error "$pkg  (AUR build failed)"
            FAILED_PKGS+=("aur:$pkg")
        fi
    done

    echo ""

    local aur_failed=0
    for entry in "${FAILED_PKGS[@]}"; do
        [[ "${entry%%:*}" == "aur" ]] && aur_failed=$(( aur_failed + 1 ))
    done

    if [[ $aur_failed -eq 0 ]]; then
        log_ok "All AUR packages installed."
    fi
}

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 2 — Pacman Packages                                              │
# ╰───────────────────────────────────────────────────────────────────────╯
step 2 "Pacman Packages"

PACMAN_DEPS=(
    # UI toolkit
    gum

    # Qt6 runtime
    qt6-base qt6-declarative qt6-multimedia qt6-5compat qt6-svg qt6-wayland qt6ct

    # Audio / PipeWire
    pipewire pipewire-pulse wireplumber

    # Media & player control
    playerctl mpv mpv-mpris mpd-mpris

    # Network / Bluetooth
    networkmanager bluez bluez-utils

    # System services
    brightnessctl upower libnotify polkit
    python wl-clipboard slurp xdg-user-dirs curl

    # Screen recording
    wf-recorder cava

    # Wallpaper / theming
    imagemagick

    # Input simulation
    wtype

    # Hardware sensors
    lm_sensors rfkill

    # Hyprland ecosystem
    hyprland hyprlock hyprpolkitagent hypridle
    xdg-desktop-portal-hyprland

    # Fonts
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common ttf-cascadia-mono-nerd

    # Other utilities
    starship fastfetch btop bat zsh exa fd ripgrep neovim fzf zed cmake nwg-look

)

spin "Syncing package database..." sudo pacman -Syu --noconfirm || {
    log_warn "System update failed — continuing with current DB. Some packages may be stale."
}

pacman_install "${PACMAN_DEPS[@]}"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 3 — AUR Packages                                                 │
# ╰───────────────────────────────────────────────────────────────────────╯
step 3 "AUR Packages"

AUR_DEPS=(
    quickshell       # REQUIRED — the shell runtime
    ghostty          # terminal emulator
    awww             # animation daemon (Synapse wallpaper/color system)
    matugen          # Material You color generation
    envycontrol      # GPU switching (optional, for NVIDIA/Intel laptops)
    auto-cpufreq     # CPU power management (optional, for laptops)
    nbfc-linux       # fan control (optional, for supported laptops)
    cliphist         # clipboard history
    hyprshutdown     # power menu backend
    bibata-cursor-theme  # animated cursor themes
    whitesur-icon-theme  # icon theme
    mactahoe-icon-theme  # icon theme
    wayland-idle-inhibitor-git  # Wayland idle inhibitor for caffeine mode (inhibits hypridle)
    sunsetr                     # schedule-aware color temperature daemon (night light)
)

if [[ "$AUR_HELPER" == "none" ]]; then
    log_warn "No AUR helper — skipping all AUR packages."
    for pkg in "${AUR_DEPS[@]}"; do
        FAILED_PKGS+=("aur:$pkg (no helper)")
    done
else
    log_info "Using: $AUR_HELPER"
    aur_install "$AUR_HELPER" "${AUR_DEPS[@]}"
fi

if [[ "$AUR_HELPER" != "none" ]] && ! "$AUR_HELPER" -Q quickshell &>/dev/null 2>&1; then
    die "quickshell failed to install. Synapse cannot run without it."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 4 — rishot (Screenshot Tool)                                     │
# ╰───────────────────────────────────────────────────────────────────────╯
# rishot (https://github.com/Gakuseei/rishot) has no AUR package yet, so it's
# vendored the same way as hyprselect in 04-plugins.sh: git clone/pull straight
# from upstream. No build step — it's a shell launcher next to QML that
# quickshell reads directly. Its required deps (quickshell, wl-clipboard,
# qt6-declarative/svg/5compat/wayland) are already covered above; its default
# save dir (~/Pictures/Screenshots) is the one SYNAPSE_USER_DIRS already seeds.
step 4 "rishot (Screenshot Tool)"

RISHOT_DIR="$HOME/.local/share/rishot"
RISHOT_BINDIR="$HOME/.local/bin"

mkdir -p "$RISHOT_BINDIR"

if [[ -d "$RISHOT_DIR/.git" ]]; then
    if ! spin "  Updating rishot..." git -C "$RISHOT_DIR" pull --ff-only; then
        log_warn "rishot update failed — keeping the existing checkout."
    fi
elif [[ -d "$RISHOT_DIR" ]]; then
    log_warn "$RISHOT_DIR exists but is not a git clone — leaving it alone."
else
    if ! spin "  Cloning rishot..." git clone https://github.com/Gakuseei/rishot.git "$RISHOT_DIR"; then
        log_warn "rishot clone failed — skipping (screenshot tool will be unavailable)."
    fi
fi

if [[ -f "$RISHOT_DIR/bin/rishot" ]]; then
    chmod +x "$RISHOT_DIR/bin/rishot"
    ln -sf "$RISHOT_DIR/bin/rishot" "$RISHOT_BINDIR/rishot"
    log_ok "rishot ready → $RISHOT_DIR  (launcher: $RISHOT_BINDIR/rishot)"

    # App-launcher integration, mirroring upstream's own installer.
    DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    if [[ -f "$RISHOT_DIR/packaging/rishot.svg" ]]; then
        mkdir -p "$DATA_HOME/icons/hicolor/scalable/apps"
        cp "$RISHOT_DIR/packaging/rishot.svg" "$DATA_HOME/icons/hicolor/scalable/apps/rishot.svg"
    fi
    if [[ -f "$RISHOT_DIR/rishot.desktop" ]]; then
        mkdir -p "$DATA_HOME/applications"
        cp "$RISHOT_DIR/rishot.desktop" "$DATA_HOME/applications/rishot.desktop"
    fi
else
    log_warn "rishot binary not found after clone — skipping."
fi
