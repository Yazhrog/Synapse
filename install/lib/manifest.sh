#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Deploy Manifest     |-/ /--|#
#|/ /---+---------------------+/ /---|#
#
# The single source of truth for what Synapse deploys and how.
# DEPLOY-MAP.md is the human-readable twin of this file — update both together.
#
# Every entry is "<repo-relative source>|<$HOME-relative destination>" and lives
# in exactly one of three arrays:
#
#   SYNAPSE_LINK_DIRS   whole directory replaced by a symlink into the repo.
#                       Only for directories nothing writes into at runtime.
#
#   SYNAPSE_LINK_FILES  per-file symlink inside a *real* destination directory.
#                       Used wherever runtime-generated files must sit next to
#                       repo files (matugen output, zsh history, lazy state).
#                       A source ending in "/" links every file beneath it,
#                       recursively, preserving the subdirectory layout.
#
#   SYNAPSE_COPY_ONCE   copied if absent, never overwritten. For files the user
#                       or another tool rewrites in place.
#
# Anything linked is owned by the repo: `git pull` updates it live. Anything
# copied is owned by the user: the installer never touches it again.

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Whole-directory symlinks — repo-owned, no runtime writes              │
# ╰───────────────────────────────────────────────────────────────────────╯

SYNAPSE_LINK_DIRS=(
    # Registers Synapse as quickshell's "default" config, so `quickshell` and
    # `qs ipc call ...` work with no -c. Runtime state lives in
    # ~/.config/Synapse, never inside this tree.
    "config/quickshell|.config/quickshell"

    "config/mpv|.config/mpv"
    "config/fastfetch|.config/fastfetch"

    # Only configs/ is linked — starship.toml itself is a user-owned symlink
    # pointing at whichever theme they picked (see SYNAPSE_COPY_ONCE note).
    "config/starship/configs|.config/starship/configs"
)

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Per-file symlinks — runtime output shares these directories           │
# ╰───────────────────────────────────────────────────────────────────────╯

SYNAPSE_LINK_FILES=(
    # ~/.config/hypr also holds: modules/colors.lua and colors.conf (matugen),
    # plugin/hyprselect/ (cloned + built by 04-plugins.sh), shaders/ (user).
    "config/hypr/hyprland.lua|.config/hypr/hyprland.lua"
    "config/hypr/hypridle.conf|.config/hypr/hypridle.conf"
    "config/hypr/hyprlock.conf|.config/hypr/hyprlock.conf"
    "config/hypr/modules/|.config/hypr/modules/"
    "config/hypr/scripts/|.config/hypr/scripts/"

    # ~/.config/ghostty also holds ghostty.colors.conf (matugen).
    "config/ghostty/config|.config/ghostty/config"

    # ~/.config/zsh also holds .zsh_history and .zcompdump (both gitignored).
    "config/zsh/.zshenv|.config/zsh/.zshenv"
    "config/zsh/.zshrc|.config/zsh/.zshrc"
    "config/zsh/aliasrc|.config/zsh/aliasrc"
    "config/zsh/functionrc|.config/zsh/functionrc"
    "config/zsh/.zshenv|.zshenv"

    # ~/.config/nvim also holds colors/nvim-colors.json (matugen) and lazy's
    # own state. lazy-lock.json is excluded — see SYNAPSE_COPY_ONCE.
    "config/nvim/|.config/nvim/"
)

# Sources skipped by the recursive "dir/" entries above, because they are
# listed in SYNAPSE_COPY_ONCE instead.
SYNAPSE_LINK_EXCLUDE=(
    "config/nvim/lazy-lock.json"
)

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Copy once — the user or another tool owns these after install         │
# ╰───────────────────────────────────────────────────────────────────────╯

SYNAPSE_COPY_ONCE=(
    "config/nvim/lazy-lock.json|.config/nvim/lazy-lock.json"  # nvim rewrites on :Lazy sync
    "config/sunsetr/sunsetr.toml|.config/sunsetr/sunsetr.toml" # `sunsetr geo` rewrites it
    "config/qt6ct/qt6ct.conf|.config/qt6ct/qt6ct.conf"         # the qt6ct GUI rewrites it
)

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Directories created on the user's behalf (never linked)               │
# ╰───────────────────────────────────────────────────────────────────────╯

SYNAPSE_USER_DIRS=(
    "Pictures/Screenshots"
    "Pictures/Wallpapers"
    ".config/hypr/shaders"
    ".config/Synapse/src/user_data/wallpapers"
)

# Seeded into ~/Pictures/Wallpapers, which is a user media directory: copied,
# never linked, so deleting a wallpaper doesn't dirty the repo.
SYNAPSE_WALLPAPER_SRC="config/quickshell/src/assets/wallpapers"
SYNAPSE_WALLPAPER_DEST="Pictures/Wallpapers"

# ~/.config/starship/starship.toml selects the active theme by pointing into
# configs/. Created only when absent so a user's choice survives reinstalls.
SYNAPSE_STARSHIP_LINK=".config/starship/starship.toml"
SYNAPSE_STARSHIP_TARGET="configs/config-default.toml"
