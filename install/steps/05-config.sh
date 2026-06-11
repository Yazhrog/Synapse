#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
#|-/ /--| Hypr Config         |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 6 — Hyprland & Ghostty Config
# Deploys the merged Lua WM config to ~/.config/hypr/ and places the
# ghostty config if one is bundled. Does not overwrite existing files.

step 6 "Hyprland Config"

HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$HYPR_DIR/modules" "$HYPR_DIR/scripts"

# hyprland.lua entry point
if cp -n "$REPO_DIR/config/hypr/hyprland.lua" "$HYPR_DIR/hyprland.lua" 2>/dev/null; then
    log_ok "hyprland.lua → ~/.config/hypr/"
else
    log_warn "hyprland.lua already exists — not overwritten"
    log_info "To update: cp $REPO_DIR/config/hypr/hyprland.lua $HYPR_DIR/hyprland.lua"
fi

# Modules
if spin "  Copying modules..." cp -r "$REPO_DIR/config/hypr/modules/." "$HYPR_DIR/modules/"; then
    log_ok "modules/ → ~/.config/hypr/modules/"
else
    log_warn "modules/ copy failed"
fi

# Scripts
if spin "  Copying scripts..." cp -r "$REPO_DIR/config/hypr/scripts/." "$HYPR_DIR/scripts/"; then
    chmod +x "$HYPR_DIR/scripts/"*.sh 2>/dev/null || true
    log_ok "scripts/ → ~/.config/hypr/scripts/"
else
    log_warn "scripts/ copy failed"
fi

# Hypridle config
if spin "  Copying Hypridle config..." cp -r "$REPO_DIR/config/hypr/hypridle.conf" "$HYPR_DIR/hypridle.conf"; then
    log_ok "hypridle.conf → ~/.config/hypr/"
else
    log_warn "hypridle.conf copy failed"
fi

# Hyprlock config
if spin "  Copying Hyprlock config..." cp -n "$REPO_DIR/config/hypr/hyprlock.conf" "$HYPR_DIR/hyprlock.conf"; then
    log_ok "hyprlock.conf → ~/.config/hypr/"
else
    log_info "hyprlock.conf already exists — not overwritten"
fi

# Screenshots directory
mkdir -p "$HOME/Pictures/Screenshots"
log_ok "~/Pictures/Screenshots/ ready"

# Ghostty config (non-overwrite)
GHOSTTY_SRC="$REPO_DIR/config/ghostty/config"
if [[ -f "$GHOSTTY_SRC" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    if cp -n "$GHOSTTY_SRC" "$HOME/.config/ghostty/config" 2>/dev/null; then
        log_ok "ghostty config → ~/.config/ghostty/config"
    else
        log_info "ghostty config already exists — not overwritten"
    fi
else
    log_info "No ghostty config bundled — place yours at ~/.config/ghostty/config"
fi

# MPV config
MPV_SRC="$REPO_DIR/config/mpv"
if [[ -d "$MPV_SRC" ]]; then
    mkdir -p "$HOME/.config/mpv"
    if spin "  Copying mpv config..." cp -r -n "$MPV_SRC/." "$HOME/.config/mpv/" 2>/dev/null; then
        log_ok "mpv config → ~/.config/mpv/"
    else
        log_info "mpv config already exists — not overwritten"
    fi
fi

# Fastfetch config
FASTFETCH_SRC="$REPO_DIR/config/fastfetch"
if [[ -d "$FASTFETCH_SRC" ]]; then
    mkdir -p "$HOME/.config/fastfetch"
    if spin "  Copying fastfetch config..." cp -r -n "$FASTFETCH_SRC/." "$HOME/.config/fastfetch/" 2>/dev/null; then
        log_ok "fastfetch config → ~/.config/fastfetch/"
    else
        log_info "fastfetch config already exists — not overwritten"
    fi
fi

# Starship config
STARSHIP_SRC="$REPO_DIR/config/starship/configs/config-default.toml"
if [[ -f "$STARSHIP_SRC" ]]; then
    mkdir -p "$HOME/.config/starship"
    if cp -n "$STARSHIP_SRC" "$HOME/.config/starship/starship.toml" 2>/dev/null; then
        log_ok "starship config → ~/.config/starship/starship.toml"
    else
        log_info "starship config already exists — not overwritten"
    fi
fi

# Zsh config
ZSH_SRC="$REPO_DIR/config/zsh"
if [[ -d "$ZSH_SRC" ]]; then
    if cp -n "$ZSH_SRC/.zshenv" "$HOME/.zshenv" 2>/dev/null; then
        log_ok ".zshenv → ~/"
    else
        log_info ".zshenv already exists — not overwritten"
    fi
    mkdir -p "$HOME/.config/zsh"
    if spin "  Copying zsh config..." cp -r -n "$ZSH_SRC/." "$HOME/.config/zsh/" 2>/dev/null; then
        log_ok "zsh config → ~/.config/zsh/"
    else
        log_info "zsh config already exists — not overwritten"
    fi
fi

echo ""
log_warn "ACTION REQUIRED: Edit ~/.config/hypr/modules/monitors.lua"
log_info "Replace DP-1 / HDMI-A-1 with your actual monitor names."
log_info "Run: hyprctl monitors"
