#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| HyprShell           |--/ /-|#
#|-/ /--| Shell Config        |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 7 — HyprShell Config
# Creates user config dirs, seeds cache, copies default wallpapers, and runs
# a live keybind conflict check against the active Hyprland session.

step 7 "HyprShell Config"

USER_DATA="$HOME/.config/HyprShell/src/user_data"

spin "  Creating config dirs..." \
    mkdir -p "$USER_DATA" \
            "$HOME/.config/hypr/shaders" \
            "$HOME/.config/matugen/templates"

# hypridle config (non-overwrite)
if cp -n "$REPO_DIR/config/quickshell/src/config/hypridle.conf" "$HOME/.config/hypr/" 2>/dev/null; then
    log_ok "hypridle.conf → ~/.config/hypr/"
else
    log_info "hypridle.conf already exists — not overwritten"
fi

# HyprShell always uses Lua
printf '{"configProvider": "lua"}\n' > "$USER_DATA/config_Provider.json"
printf '{}\n'                        > "$USER_DATA/keybinds.json"

log_ok "Config dirs created"

# Cache and wallpapers
spin "  Initialising cache..." \
    bash -c "mkdir -p '$HOME/.cache/brain-shell' && touch '$HOME/.cache/brain-shell/colors.json'"

mkdir -p "$HOME/Pictures/Wallpapers"
spin "  Copying default wallpapers..." \
    cp -r -n "$REPO_DIR/config/quickshell/src/assets/wallpapers/." "$HOME/Pictures/Wallpapers/" || true

log_ok "Cache and wallpapers initialised"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Keybind Conflict Detection                                            │
# ╰───────────────────────────────────────────────────────────────────────╯
echo ""
log_info "Checking for keybind conflicts with the active Hyprland session..."

python3 << 'PYEOF' || log_warn "Keybind check skipped (Python error or no Hyprland session)."
import subprocess, json, os, sys

# Default keybinds registered internally by HyprShell (Quickshell/QML)
DEFAULTS = {
    "dashboard-home":      {"mods": "SUPER",        "key": "D",      "label": "Dashboard: Home"},
    "dashboard-stats":     {"mods": "CTRL + SHIFT", "key": "ESCAPE", "label": "Dashboard: Stats"},
    "dashboard-kanban":    {"mods": "SUPER",        "key": "Z",      "label": "Dashboard: Tasks"},
    "dashboard-launcher":  {"mods": "SUPER",        "key": "Q",      "label": "Dashboard: Apps"},
    "dashboard-config":    {"mods": "SUPER",        "key": "C",      "label": "Dashboard: Config"},
    "PowerMenu-toggle":    {"mods": "SUPER",        "key": "ESCAPE", "label": "Power Menu"},
    "notification-toggle": {"mods": "SUPER",        "key": "N",      "label": "Notifications"},
    "wallpaper-toggle":    {"mods": "SUPER",        "key": "W",      "label": "Wallpaper"},
    "clipboard-toggle":    {"mods": "SUPER",        "key": "V",      "label": "Clipboard"},
    "wifi-toggle":         {"mods": "SUPER + ALT",  "key": "W",      "label": "Network: Wi-Fi"},
    "bluetooth-toggle":    {"mods": "SUPER + ALT",  "key": "B",      "label": "Network: Bluetooth"},
    "vpn-toggle":          {"mods": "SUPER + ALT",  "key": "G",      "label": "Network: VPN"},
    "hotspot-toggle":      {"mods": "SUPER + ALT",  "key": "H",      "label": "Network: Hotspot"},
    "audioOut-toggle":     {"mods": "SUPER",        "key": "A",      "label": "Audio: Output"},
    "audioIn-toggle":      {"mods": "SUPER + ALT",  "key": "I",      "label": "Audio: Input"},
    "audioMix-toggle":     {"mods": "SUPER",        "key": "M",      "label": "Audio: Mixer"},
    "focus-toggle":        {"mods": "SUPER",        "key": "B",      "label": "Focus Mode"},
    "screenrec-on":        {"mods": "ALT",          "key": "F9",     "label": "Screen Record"},
}

MOD_BITS = {"SHIFT": 1, "CTRL": 4, "ALT": 8, "SUPER": 64}

def mods_to_mask(mods_str):
    mask = 0
    for part in mods_str.upper().split("+"):
        mask |= MOD_BITS.get(part.strip(), 0)
    return mask

try:
    raw = subprocess.check_output(["hyprctl", "binds", "-j"], stderr=subprocess.DEVNULL).decode()
    hypr_binds = json.loads(raw)
except Exception:
    print("  \033[2m(not inside Hyprland — skipping live conflict check)\033[0m")
    sys.exit(0)

conflicts = {}
for action, data in DEFAULTS.items():
    mask = mods_to_mask(data["mods"])
    key  = data["key"].lower()
    for hb in hypr_binds:
        if hb.get("submap", "") or hb.get("mouse"):
            continue
        if hb.get("modmask") == mask and str(hb.get("key", "")).lower() == key:
            conflicts[action] = {
                "bind":    f"{data['mods']} + {data['key']}",
                "label":   data["label"],
                "used_by": f"{hb.get('dispatcher', '')} {hb.get('arg', '')}".strip(),
            }
            break

if not conflicts:
    print("  \033[0;32m✓\033[0m  No keybind conflicts detected.")
    sys.exit(0)

print(f"\n  \033[0;31m✗\033[0m  {len(conflicts)} conflict(s) found:\n")
unbound = {}
for action, info in conflicts.items():
    print(f"    \033[1m{info['bind']:<24}\033[0m  {info['label']}")
    print(f"    {'':24}  already used by: {info['used_by']}\n")
    unbound[action] = {"mods": "", "key": ""}

config_path = os.path.expanduser("~/.config/HyprShell/src/user_data/keybinds.json")
with open(config_path, "w") as f:
    json.dump(unbound, f, indent=2)

print("  \033[1;33m⚠\033[0m  Conflicting binds left unbound.")
print("       Re-assign them: Dashboard → Config → Keybinds\n")
PYEOF
