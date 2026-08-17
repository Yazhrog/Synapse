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
# Non-fatal: these need a live Hyprland session, and boot.sh explicitly supports
# installing from a TTY. Plugins are re-activated by `hyprpm reload -n` in
# autostart.lua on the next Hyprland start anyway.
hyprpm update || log_warn "hyprpm update failed — plugins activate on next Hyprland start."
_hyprpm_enable scrolloverview
hyprpm reload || log_warn "hyprpm reload skipped (no Hyprland session)."

echo ""

# ── hyprselect (manual .so plugin) ───────────────────────────────────────────
PLUGIN_DIR="$HOME/.config/hypr/plugin"
HYPRSELECT_DIR="$PLUGIN_DIR/hyprselect"

mkdir -p "$PLUGIN_DIR"

# Every outcome here is non-fatal: hyprselect is one optional plugin, and a
# stale clone, a force-push upstream or an offline machine must not take down
# an otherwise good install.
if [[ -d "$HYPRSELECT_DIR/.git" ]]; then
    if ! spin "  Updating hyprselect..." git -C "$HYPRSELECT_DIR" pull --ff-only; then
        log_warn "hyprselect update failed — keeping the existing checkout."
    fi
elif [[ -d "$HYPRSELECT_DIR" ]]; then
    log_warn "$HYPRSELECT_DIR exists but is not a git clone — leaving it alone."
else
    if ! spin "  Cloning hyprselect..." git clone https://github.com/jmanc3/hyprselect "$HYPRSELECT_DIR"; then
        log_warn "hyprselect clone failed — skipping (window selection will be unavailable)."
    fi
fi

if [[ -f "$HYPRSELECT_DIR/Makefile" ]] || [[ -f "$HYPRSELECT_DIR/makefile" ]]; then
    if spin "  Building hyprselect..." make -C "$HYPRSELECT_DIR"; then
        log_ok "hyprselect built → $HYPRSELECT_DIR/hyprselect.so"
    else
        log_warn "hyprselect build failed — check build deps (make, g++, hyprland headers)"
    fi
else
    log_warn "hyprselect sources not present — skipping build."
fi

echo ""
log_ok "Plugin setup complete. Plugins activate on next Hyprland start."
