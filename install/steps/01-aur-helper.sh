#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| AUR Helper          |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 1 — AUR Helper
# Detects yay or paru; offers to bootstrap one if neither is present.
# Sets AUR_HELPER ("yay", "paru", or "none") for use by later steps.
step 1 "AUR Helper"
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    log_ok "yay detected"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    log_ok "paru detected"
else
    log_warn "No AUR helper found (yay / paru)."
    echo ""
    _choice=$(choose "Select an AUR helper to install:" \
        "yay  — widely used, interactive" \
        "paru — faster builds, more features" \
        "skip — pacman-only (quickshell will be missing)")

    _bootstrap_aur_helper() {
        local name="$1"

        # Warm up sudo BEFORE every privileged block, in the open,
        # so the password prompt is never hidden behind spin().
        sudo -v || die "sudo authentication failed."
        spin "Installing git + base-devel..." \
            sudo pacman -S --needed --noconfirm git base-devel

        local tmp; tmp=$(mktemp -d)
        spin "Cloning $name from AUR..." \
            git clone "https://aur.archlinux.org/${name}.git" "$tmp/$name"

        # No sudo needed for the build itself (-s = syncdeps, -c = clean up)
        spin "Building $name..." \
            makepkg -D "$tmp/$name" -sc --noconfirm

        # Refresh sudo again before the install step — a long build can
        # outlast the cached credential, so don't assume it's still valid.
        sudo -v || die "sudo authentication failed."
        spin "Installing $name..." \
            sudo pacman -U --noconfirm "$tmp/$name"/*.pkg.tar.zst

        rm -rf "$tmp"
        log_ok "$name installed."
    }

    case "$_choice" in
        yay*)  _bootstrap_aur_helper yay;  AUR_HELPER="yay"  ;;
        paru*) _bootstrap_aur_helper paru; AUR_HELPER="paru" ;;
        skip*)
            log_warn "Skipping AUR helper."
            log_warn "quickshell is required — install yay or paru later and re-run."
            AUR_HELPER="none"
            ;;
        *) die "No selection made." ;;
    esac
fi
