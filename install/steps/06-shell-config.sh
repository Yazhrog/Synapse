#!/usr/bin/env bash
#|---/ /+---------------------+---/ /|#
#|--/ /-| Synapse             |--/ /-|#
#|-/ /--| Shell Config        |-/ /--|#
#|/ /---+---------------------+/ /---|#
# Step 8 — Synapse Config
#
# Seeds ~/.config/Synapse, the one directory Synapse owns at runtime and never
# links: user data, generated keybinds, and the monitor override file.
#
# Everything here is seed-if-missing. Re-running the installer must never cost
# a user their keybinds, their monitor layout, or their wallpaper choice.

step 8 "Synapse Config"

USER_DATA="$HOME/.config/Synapse/src/user_data"

spin "  Creating config dirs..." \
    mkdir -p "$USER_DATA" "$USER_DATA/wallpapers"

# Synapse always uses Lua; this file exists for ShellState to read at startup.
[[ -f "$USER_DATA/config_Provider.json" ]] || printf '{"configProvider": "lua"}\n' > "$USER_DATA/config_Provider.json"
# Keybind overrides — deltas against keybind-defaults.json. Never clobber.
[[ -f "$USER_DATA/keybinds.json" ]]        || printf '{}\n'                        > "$USER_DATA/keybinds.json"

log_ok "Config dirs ready"

# Seed the color files so hyprlock and appearance.lua have something to source
# before the first wallpaper apply runs matugen.
[[ -f "$USER_DATA/colors.json" ]]          || touch "$USER_DATA/colors.json"
[[ -f "$HOME/.config/hypr/colors.conf" ]]  || touch "$HOME/.config/hypr/colors.conf"
log_ok "Color seed files ready"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Monitor override                                                      │
# ╰───────────────────────────────────────────────────────────────────────╯
# modules/monitors.lua is a symlink into the repo and dofile()s this at the end,
# so a user's display layout stays out of the repo's history.

MONITORS_OVERRIDE="$HOME/.config/Synapse/monitors.lua"
if [[ ! -f "$MONITORS_OVERRIDE" ]]; then
    cat > "$MONITORS_OVERRIDE" <<'LUAEOF'
-- Your monitor layout. Loaded after Synapse's auto-detect default, so anything
-- declared here wins. Run `hyprctl monitors` for your display names.
--
-- Format: hl.monitor({ output = "NAME", mode = "WxH@Hz", position = "XxY", scale = 1 })
-- Position is a pixel offset from the top-left. scale = 1 is 1:1, 2 is HiDPI.
--
-- Examples:
--   hl.monitor({ output = "DP-1",     mode = "2560x1440@144.0", position = "0x0",    scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.0",  position = "2560x0", scale = 1 })
--   hl.monitor({ output = "eDP-1",    mode = "1920x1080@60.0",  position = "0x0",    scale = 1 })
--
-- A single display usually needs nothing here.
LUAEOF
    log_ok "Monitor override seeded → ~/.config/Synapse/monitors.lua"
else
    log_info "Monitor override already exists — kept"
fi

log_ok "Wallpapers initialised"

# ╭───────────────────────────────────────────────────────────────────────╮
# │ Keybind Conflict Detection                                            │
# ╰───────────────────────────────────────────────────────────────────────╯
echo ""

# Runs on every install AND every re-run/update — not just the first one — so
# a default keybind added by a later update still gets checked against the
# user's own Hyprland binds. The catch: once Synapse's own binds are loaded,
# `hyprctl binds -j` reports ours and the user's identically as dispatcher
# "__lua" with an opaque numeric arg, so the usual "qs ipc" substring check
# can't tell them apart anymore. The Python script below works around this by
# only evaluating actions that are NEW since the last generated
# SynapseKeybinds.lua (never bound by Synapse before, so any hyprctl bind at
# that mod+key can't be one of Synapse's own), and by treating any mod+key
# combo already occupied by the old SynapseKeybinds.lua as "ours" rather than
# a real conflict.
log_info "Checking new keybind actions for conflicts with the active Hyprland session..."

export SYNAPSE_DEFAULTS_JSON="$REPO_DIR/config/quickshell/src/config/keybind-defaults.json"

python3 << 'PYEOF' || log_warn "Keybind check skipped (Python error or no Hyprland session)."
import re, subprocess, json, os, sys

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

config_path = os.path.expanduser("~/.config/Synapse/src/user_data/keybinds.json")

# Load what the user already chose. Their overrides supersede the defaults, so
# an action they have already remapped can't be in conflict via its default.
try:
    with open(config_path) as f:
        existing = json.load(f)
    if not isinstance(existing, dict):
        existing = {}
except Exception:
    existing = {}

# What Synapse already generated last time — empty on a fresh install, which
# makes "new_actions" reduce to "every action not already in existing", i.e.
# today's first-install behavior, unchanged.
lua_path = os.path.expanduser("~/.config/Synapse/SynapseKeybinds.lua")
try:
    with open(lua_path) as f:
        old_lua = f.read()
except FileNotFoundError:
    old_lua = ""

old_actions = set(re.findall(r'qs ipc call (\S+) toggle', old_lua))

ours_combos = set()
for mods_key in re.findall(r'hl\.bind\(\s*"([^"]+)"', old_lua):
    parts = [p.strip() for p in mods_key.split("+")]
    ours_combos.add((mods_to_mask("+".join(parts[:-1])), parts[-1].lower()))

new_actions = [a for a in DEFAULTS if a not in existing and a not in old_actions]

if not new_actions:
    print("  \033[2m(no new keybind actions to check)\033[0m")
    sys.exit(0)

conflicts = {}
for action in new_actions:
    data = DEFAULTS[action]
    mask = mods_to_mask(data["mods"])
    key  = data["key"].lower()
    if (mask, key) in ours_combos:
        continue
    for hb in hypr_binds:
        if hb.get("submap", "") or hb.get("mouse"):
            continue
        # Our own generated binds shell out to `qs ipc` — never a real conflict.
        if "qs ipc" in str(hb.get("arg", "")):
            continue
        if hb.get("modmask") == mask and str(hb.get("key", "")).lower() == key:
            conflicts[action] = {
                "bind":    f"{data['mods']} + {data['key']}",
                "label":   data["label"],
                "used_by": f"{hb.get('dispatcher', '')} {hb.get('arg', '')}".strip(),
            }
            break

if not conflicts:
    print(f"  \033[0;32m✓\033[0m  {len(new_actions)} new action(s) checked — no keybind conflicts detected.")
    sys.exit(0)

print(f"\n  \033[0;31m✗\033[0m  {len(conflicts)} conflict(s) found:\n")
for action, info in conflicts.items():
    print(f"    \033[1m{info['bind']:<24}\033[0m  {info['label']}")
    print(f"    {'':24}  already used by: {info['used_by']}\n")
    existing[action] = {"mods": "", "key": ""}

# Merge, never replace — anything the user set stays exactly as it was.
with open(config_path, "w") as f:
    json.dump(existing, f, indent=2)

print("  \033[1;33m⚠\033[0m  Conflicting binds left unbound.")
print("       Re-assign them: Dashboard → Config → Keybinds\n")
PYEOF
