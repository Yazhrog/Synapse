#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
#|-/ /--| Services            |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 5 — Systemd Services
# Enables system-level and user-level services required by HyprShell.

step 5 "Systemd Services"

_svc_system() {
    if spin "  system: $1" sudo systemctl enable --now "$1"; then
        log_ok "system: $1"
    else
        log_warn "system: $1  (failed to enable — may not apply to your setup)"
    fi
}

_svc_user() {
    if spin "  user:   $1" systemctl --user enable --now "$1"; then
        log_ok "user:   $1"
    else
        log_warn "user:   $1  (failed to enable)"
    fi
}

_svc_system NetworkManager
_svc_system bluetooth
_svc_system upower

_svc_user pipewire
_svc_user pipewire-pulse
_svc_user wireplumber
