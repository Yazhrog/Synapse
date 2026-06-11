#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
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
    qt6-base qt6-declarative qt6-multimedia qt6-5compat qt6ct

    # Audio / PipeWire
    pipewire pipewire-pulse wireplumber

    # Media & player control
    playerctl mpv mpv-mpris mpd-mpris

    # Network / Bluetooth
    networkmanager bluez bluez-utils

    # System services
    brightnessctl upower libnotify polkit
    python wl-clipboard slurp xdg-user-dirs

    # Screen recording
    wf-recorder cava

    # Wallpaper / theming
    imagemagick

    # Input simulation
    wtype

    # Hardware sensors
    lm_sensors rfkill

    # Hyprland ecosystem
    hyprland hyprsunset hyprlock hyprpolkitagent hypridle
    xdg-desktop-portal-hyprland

    # Fonts
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-common

    # Other utilities
    starship fastfetch btop bat zsh exa fd ripgrep fzf

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
    awww             # animation daemon (Brain_Shell wallpaper/color system)
    matugen          # Material You color generation
    envycontrol      # GPU switching (optional, for NVIDIA/Intel laptops)
    auto-cpufreq     # CPU power management (optional, for laptops)
    nbfc-linux       # fan control (optional, for supported laptops)
    cliphist         # clipboard history
    hyprshutdown     # power menu backend
    grimblast-git    # screenshot helper
    bibata-cursor-theme  # animated cursor themes
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
    die "quickshell failed to install. HyprShell cannot run without it."
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Step 4 — Icon Theme                                                   │
# ╰───────────────────────────────────────────────────────────────────────╯
step 4 "Icon Theme"

ICON_THEME_DIR="/usr/share/icons/Mkos-Big-Sur"

if [[ -d "$ICON_THEME_DIR" ]]; then
    log_ok "Mkos-Big-Sur already installed — skipping."
else
    if spin "Downloading Mkos-Big-Sur icon theme..." \
            curl -fsSL https://github.com/zayronxio/Mkos-Big-Sur/archive/refs/heads/master.zip \
            -o /tmp/mkos-big-sur.zip; then

        if spin "Extracting to /usr/share/icons..." \
                sudo unzip -q /tmp/mkos-big-sur.zip -d /usr/share/icons/; then

            sudo mv /usr/share/icons/Mkos-Big-Sur-master "$ICON_THEME_DIR"
            rm -f /tmp/mkos-big-sur.zip

            spin "Updating icon cache..." \
                sudo gtk-update-icon-cache -f -t "$ICON_THEME_DIR" || true

            log_ok "Mkos-Big-Sur installed."
        else
            log_error "Failed to extract icon theme."
            rm -f /tmp/mkos-big-sur.zip
            FAILED_PKGS+=("icons:Mkos-Big-Sur")
        fi
    else
        log_error "Failed to download Mkos-Big-Sur."
        FAILED_PKGS+=("icons:Mkos-Big-Sur")
    fi
fi
