#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Shell Config        |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 8 — Synapse Config
# Creates user config dirs, seeds color files, copies default wallpapers, and runs
# a live keybind conflict check against the active Hyprland session.

step 8 "Synapse Config"

USER_DATA="$HOME/.config/Synapse/src/user_data"

spin "  Creating config dirs..." \
    mkdir -p "$USER_DATA" \
            "$USER_DATA/wallpapers" \
            "$HOME/.config/hypr/shaders" \
            "$HOME/.config/matugen/templates"

# Synapse always uses Lua
printf '{"configProvider": "lua"}\n' > "$USER_DATA/config_Provider.json"
printf '{}\n'                        > "$USER_DATA/keybinds.json"

log_ok "Config dirs created"

# Seed color files (matugen will overwrite these on first wallpaper apply)
touch "$USER_DATA/colors.json"
touch "$HOME/.config/hypr/colors.conf"
log_ok "Color seed files created"

mkdir -p "$HOME/Pictures/Wallpapers"
spin "  Copying default wallpapers..." \
    cp -r -n "$REPO_DIR/config/quickshell/src/assets/wallpapers/." "$HOME/Pictures/Wallpapers/" || true

log_ok "Wallpapers initialised"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Keybind Conflict Detection                                            │
# ╰───────────────────────────────────────────────────────────────────────╯
echo ""
log_info "Checking for keybind conflicts with the active Hyprland session..."

export SYNAPSE_DEFAULTS_JSON="$REPO_DIR/config/quickshell/src/config/keybind-defaults.json"

python3 << 'PYEOF' || log_warn "Keybind check skipped (Python error or no Hyprland session)."
import subprocess, json, os, sys

# Single source of truth, shared with KeybindService.qml — keeps the action
# names here in sync with the IpcHandler targets in IpcManager.qml.
try:
    with open(os.environ["SYNAPSE_DEFAULTS_JSON"]) as f:
        DEFAULTS = json.load(f)
except Exception as e:
    print(f"  \033[2m(could not load keybind-defaults.json: {e} — skipping conflict check)\033[0m")
    sys.exit(0)

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

config_path = os.path.expanduser("~/.config/Synapse/src/user_data/keybinds.json")
with open(config_path, "w") as f:
    json.dump(unbound, f, indent=2)

print("  \033[1;33m⚠\033[0m  Conflicting binds left unbound.")
print("       Re-assign them: Dashboard → Config → Keybinds\n")
PYEOF
