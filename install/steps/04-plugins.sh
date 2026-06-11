#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
#|-/ /--| Plugins             |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 5 — Hyprland Plugins
# Registers and enables the four HyprShell plugins via hyprpm.
# Plugins activate on the next Hyprland start (hyprpm reload -n in autostart).

step 5 "Hyprland Plugins"

if ! command -v hyprpm &>/dev/null; then
    log_warn "hyprpm not found — skipping plugin setup."
    log_info "Install Hyprland ≥ 0.55 (which ships hyprpm), then run:"
    log_info "  hyprpm add https://github.com/hyprwm/hyprland-plugins"
    log_info "  hyprpm add https://github.com/Vortex-Basis-LLC/hyprfocus"
    log_info "  hyprpm enable hyprexpo borders-plus-plus hyprbars hyprfocus"
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

_hyprpm_add "https://github.com/hyprwm/hyprland-plugins" \
    "hyprwm/hyprland-plugins  (hyprexpo, borders-plus-plus, hyprbars)"
_hyprpm_add "https://github.com/Vortex-Basis-LLC/hyprfocus" \
    "Vortex-Basis-LLC/hyprfocus"

echo ""
_hyprpm_enable hyprexpo
_hyprpm_enable borders-plus-plus
_hyprpm_enable hyprbars
_hyprpm_enable hyprfocus

echo ""
log_ok "Plugin setup complete. Plugins activate on next Hyprland start."
