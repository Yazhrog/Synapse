#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Plugins             |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 6 — Hyprland Plugins
# Registers and enables scrolloverview via hyprpm.
# Plugins activate on the next Hyprland start (hyprpm reload -n in autostart).

step 6 "Hyprland Plugins"

if ! command -v hyprpm &>/dev/null; then
    log_warn "hyprpm not found — skipping plugin setup."
    log_info "Install Hyprland ≥ 0.55 (which ships hyprpm), then run:"
    log_info "  hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git"
    log_info "  hyprpm enable scrolloverview"
    return 0
fi

_hyprpm_add() {
    local repo="$1" label="$2"
    if spin "  Adding $label..." hyprpm add "$repo" --no-cache; then
        log_ok "$label"
    else
        log_warn "$label  (already added or fetch failed)"
    fi
}

_hyprpm_enable() {
    local plugin="$1"
    if spin "  Enabling $plugin..." hyprpm enable "$plugin"; then
        log_ok "enabled $plugin"
    else
        log_warn "$plugin  (will activate on next Hyprland start)"
    fi
}

_hyprpm_add "https://github.com/yayuuu/hyprland-scroll-overview.git" "yayuuu/hyprland-scroll-overview"

echo ""
hyprpm update
_hyprpm_enable scrolloverview
hyprpm reload

echo ""

# ── hyprselect (manual .so plugin) ───────────────────────────────────────────
PLUGIN_DIR="$HOME/.config/hypr/plugin"
HYPRSELECT_DIR="$PLUGIN_DIR/hyprselect"

mkdir -p "$PLUGIN_DIR"

if [[ -d "$HYPRSELECT_DIR" ]]; then
    spin "  Updating hyprselect..." git -C "$HYPRSELECT_DIR" pull --ff-only
else
    spin "  Cloning hyprselect..." git clone https://github.com/jmanc3/hyprselect "$HYPRSELECT_DIR"
fi

if spin "  Building hyprselect..." make -C "$HYPRSELECT_DIR"; then
    log_ok "hyprselect built → $HYPRSELECT_DIR/hyprselect.so"
else
    log_warn "hyprselect build failed — check build deps (make, g++, hyprland headers)"
fi

echo ""
log_ok "Plugin setup complete. Plugins activate on next Hyprland start."
