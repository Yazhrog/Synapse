#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Config Deployment   |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 7 — Config Deployment
#
# Symlinks every config Synapse ships into ~/.config, so the repo checkout is
# the live source and `git pull` updates the running system. What goes where is
# declared in install/lib/manifest.sh; install/lib/link.sh does the placing and
# backs up anything it displaces.
#
# This step also owns the two things that aren't file placement: making zsh the
# login shell, and telling the user where to put their monitor layout.

step 7 "Config Deployment"

# Reuse boot.sh's backup directory so one install produces one backup. Set
# before sourcing: lib/link.sh picks its own timestamped default at source time.
export SYNAPSE_BACKUP_DIR="$BACKUP_DIR"

# shellcheck source=install/lib/manifest.sh
source "$INSTALL_DIR/lib/manifest.sh"
# shellcheck source=install/lib/link.sh
source "$INSTALL_DIR/lib/link.sh"

synapse_run_manifest
synapse_link_summary || true

# Shipped scripts are tracked 755, but a tarball or a restrictive umask can
# lose the bit — and the symlink only inherits what the source has.
chmod +x "$REPO_DIR/config/hypr/scripts/"*.sh 2>/dev/null || true
chmod +x "$REPO_DIR/config/quickshell/src/scripts/"*.sh 2>/dev/null || true

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Login shell                                                           │
# ╰───────────────────────────────────────────────────────────────────────╯

echo ""
ZSH_BIN="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
if [[ -n "$ZSH_BIN" && "$CURRENT_SHELL" != "$ZSH_BIN" ]]; then
    log_info "Setting zsh as default shell..."
    if sudo chsh -s "$ZSH_BIN" "$USER"; then
        log_ok "Default shell → zsh (takes effect on next login)"
    else
        log_warn "Failed to set default shell — run manually: chsh -s $ZSH_BIN"
    fi
else
    log_info "zsh already the default shell"
fi

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Follow-ups                                                            │
# ╰───────────────────────────────────────────────────────────────────────╯

echo ""
log_info "Multi-monitor or non-default layout? Edit ~/.config/Synapse/monitors.lua"
log_info "Run 'hyprctl monitors' for your display names. A single display needs nothing."
log_info "Set your location for night light with: sunsetr geo"
