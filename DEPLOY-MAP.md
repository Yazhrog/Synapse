# Synapse — Deployment Map

All filesystem locations touched by the installer or at runtime.
`$REPO` = `~/.local/src/Synapse` — see "Repository clone" below for why this is fixed, not wherever you happen to `git clone` this yourself.

---

## Repository clone

`boot.sh` is the entry point and always clones/pulls into a fixed path, `~/.local/src/Synapse` (`REPO_PARENT="$HOME/.local/src"`, `REPO_DIR="$REPO_PARENT/Synapse"`):

- If `$REPO_DIR/.git` already exists, it runs `git -C "$REPO_DIR" pull origin main` (updates in place, always tracking `main`).
- Otherwise it runs `git clone -b main <repo-url> "$REPO_DIR"`.

`$REPO_DIR` is then passed down to `install/install.sh` and every step under `install/steps/`, so all install-time deployments below read from that path — regardless of where you originally ran `boot.sh` from or where any other working checkout of this repo lives on disk. `config/hypr/modules/autostart.lua` also hardcodes this same path when it launches quickshell (see "Run in place from the repo" below), so a local checkout elsewhere (e.g. a dev clone under `~/Projects/`) is invisible to the running shell until it's synced into `~/.local/src/Synapse`.

---

## Install-time deployments

### `install/steps/05-config.sh`  (displayed as step 7/8, "Hyprland Config")

| Source (repo)                              | Destination                                  | Overwrite? |
|--------------------------------------------|----------------------------------------------|------------|
| `config/hypr/hyprland.lua`                 | `~/.config/hypr/hyprland.lua`                | Yes        |
| `config/hypr/modules/`                     | `~/.config/hypr/modules/`                    | Yes        |
| `config/hypr/scripts/`                     | `~/.config/hypr/scripts/`                    | Yes        |
| `config/hypr/hypridle.conf`                | `~/.config/hypr/hypridle.conf`               | Yes        |
| `config/hypr/hyprlock.conf`                | `~/.config/hypr/hyprlock.conf`               | No (`-n`)  |
| `config/ghostty/config` *(if present)*     | `~/.config/ghostty/config`                   | No (`-n`)  |
| `config/mpv/` *(if present)*               | `~/.config/mpv/`                             | No (`-n`)  |
| `config/fastfetch/` *(if present)*         | `~/.config/fastfetch/`                       | No (`-n`)  |
| `config/starship/`                             | `~/.config/starship/`                        | No (`-n`)  |
| *(symlink created)*                            | `~/.config/starship/starship.toml` → `configs/config-default.toml` | No |
| `config/zsh/.zshenv`                       | `~/.zshenv`                                  | No (`-n`)  |
| `config/zsh/`                              | `~/.config/zsh/`                             | No (`-n`)  |
| `config/nvim/` *(if present)*               | `~/.config/nvim/`                            | No (`-n`)  |
| `config/sunsetr/sunsetr.toml` *(if present)*   | `~/.config/sunsetr/sunsetr.toml`             | No (`-n`)  |
| `config/qt6ct/qt6ct.conf` *(if present)*       | `~/.config/qt6ct/qt6ct.conf`                 | No (`-n`)  |

Directories created unconditionally:
- `~/.config/hypr/modules/`
- `~/.config/hypr/scripts/`
- `~/Pictures/Screenshots/`

---

### `install/steps/06-shell-config.sh`  (displayed as step 8/8, "Synapse Config")

| Source (repo)                                       | Destination                                        | Overwrite? |
|-----------------------------------------------------|----------------------------------------------------|------------|
| `config/quickshell/src/assets/wallpapers/`          | `~/Pictures/Wallpapers/`                           | No (`-n`)  |

Directories created unconditionally:
- `~/.config/Synapse/src/user_data/`
- `~/.config/Synapse/src/user_data/wallpapers/`
- `~/.config/hypr/shaders/`
- `~/.config/matugen/templates/`
- `~/Pictures/Wallpapers/`

Seed files written (overwritten by runtime on first wallpaper apply):
- `~/.config/Synapse/src/user_data/config_Provider.json` — `{"configProvider": "lua"}`
- `~/.config/Synapse/src/user_data/keybinds.json` — `{}`
- `~/.config/Synapse/src/user_data/colors.json` — empty
- `~/.config/hypr/colors.conf` — empty

After seeding, this step also runs a live `hyprctl binds -j` conflict check against Synapse's default keybind set. If any default collides with an existing Hyprland bind, that entry is immediately rewritten into `keybinds.json` as unbound (`{"mods": "", "key": ""}`) instead of staying `{}` — so a fresh install's `keybinds.json` is not always the empty-object seed shown above.

---

## Runtime paths (written by Quickshell services)

These are created/updated while Synapse is running, not during install.

### Wallpaper & theming  (`WallpaperService.qml`)

| Path | What it is |
|------|------------|
| `~/.config/Synapse/src/user_data/wallpapers/curr_wall` | Symlink → current wallpaper file |
| `~/.config/Synapse/src/user_data/wallpapers/curr_wall_static.jpg` | Static JPEG copy of current wall (for hyprlock background) |
| `~/.config/Synapse/src/user_data/wallpaper.json` | Persisted wallpaper path + color scheme |

Matugen is invoked at wallpaper-change time using `$SHELL_DIR/src/config/matugen.toml`.
It writes three outputs (defined in `matugen.toml`):

| Matugen output | Path |
|----------------|------|
| `synapse` template | `~/.config/Synapse/src/user_data/colors.json` |
| `hyprland_colors` template | `~/.config/hypr/colors.conf` |
| `hyprland_colors_lua` template | `~/.config/hypr/modules/colors.lua` |

`colors.lua` is `dofile()`'d by `~/.config/hypr/modules/appearance.lua` on Hyprland startup/reload — it's the only one of the three matugen outputs the Lua Hyprland config actually reads (`colors.conf` is sourced by `hyprlock.conf` instead).

> `$SHELL_DIR` = the directory quickshell was launched from — a fixed path hardcoded in `config/hypr/modules/autostart.lua`, `~/.local/src/Synapse/config/quickshell` (the same clone `boot.sh` manages), not `~/.config/quickshell`.

---

### User data / persistent state  (various services)

| Path | Service | What it stores |
|------|---------|----------------|
| `~/.config/Synapse/src/user_data/wallpaper.json` | WallpaperService | Current wallpaper path + scheme |
| `~/.config/Synapse/src/user_data/clipboard_pins.json` | ClipboardService | Pinned clipboard entries |
| `~/.config/Synapse/src/user_data/tasks.json` | KanbanBoard | Kanban task cards |
| `~/.config/Synapse/src/user_data/hotspot.json` | QuickSettings | Hotspot config |
| `~/.config/Synapse/src/user_data/update_prefs.json` | UpdateService | Auto-update preferences |
| `~/.config/Synapse/src/user_data/screenrec.json` | ScreenRecService | Screen recording settings |
| `~/.config/Synapse/src/user_data/keybinds.json` | KeybindService | Custom keybind overrides |
| `~/.config/Synapse/src/user_data/config_Provider.json` | Shell bootstrap | Config provider selection (`lua`) |

---

### Keybinds  (`KeybindService.qml`)

| Path | What it is |
|------|------------|
| `~/.config/Synapse/SynapseKeybinds.lua` | Generated Hyprland binds (all 18 shell actions, defaults ⊕ `keybinds.json` overrides). Rewritten on every save. |
| `~/.config/Synapse/SynapseKeybinds.conf` | Same, `.conf` syntax. Written for parity but not sourced by anything the installer ships — `.conf`-provider users must add `source = ~/.config/Synapse/SynapseKeybinds.conf` to their own `hyprland.conf` manually. |

`SynapseKeybinds.lua` is loaded unconditionally by `~/.config/hypr/modules/synapse-keybinds.lua` (deployed by step 05 with the rest of `config/hypr/modules/`, `require()`'d from `hyprland.lua`) — via `pcall(dofile, ...)` since the generated file doesn't exist until Quickshell has run at least once. Nothing auto-edits `hyprland.lua`/`hyprland.conf` at runtime; the `require()` line ships as part of the repo like any other module.

The default combos/labels/groups for those 18 actions live in `config/quickshell/src/config/keybind-defaults.json` — read directly by `KeybindService.qml` and by the install-time conflict check in `06-shell-config.sh` (see above), so there's one canonical copy instead of two hand-maintained ones.

---

### Shader search paths  (`QuickSettings.qml`)

Synapse looks for shaders in these locations (in order):

1. `~/.config/hypr/shaders/`
2. `~/.local/share/hypr/shaders/`
3. `/usr/share/hyprshade/shaders/`
4. `~/.config/quickshell/src/config/shaders/`

---

### Hyprland lock screen  (`hypridle.conf`)

| Invocation | Config used |
|------------|-------------|
| `hyprlock` (via `SUPER+L` or hypridle `lock_cmd`) | `~/.config/hypr/hyprlock.conf` (default) |

---

## Summary tree

```
~/
├── .config/
│   ├── hypr/
│   │   ├── hyprland.lua
│   │   ├── hypridle.conf
│   │   ├── hyprlock.conf
│   │   ├── modules/
│   │   │   └── colors.lua           ← matugen output (runtime)
│   │   ├── scripts/
│   │   ├── shaders/
│   │   └── colors.conf              ← matugen output (runtime)
│   ├── Synapse/src/user_data/
│   │   ├── config_Provider.json
│   │   ├── keybinds.json
│   │   ├── wallpaper.json
│   │   ├── clipboard_pins.json
│   │   ├── tasks.json
│   │   ├── hotspot.json
│   │   ├── update_prefs.json
│   │   ├── screenrec.json
│   │   ├── colors.json              ← matugen output (runtime)
│   │   └── wallpapers/
│   │       ├── curr_wall            ← symlink (runtime)
│   │       └── curr_wall_static.jpg ← jpeg copy (runtime)
│   ├── matugen/templates/
│   ├── ghostty/config
│   ├── mpv/
│   ├── fastfetch/
│   ├── starship/
│   │   ├── configs/
│   │   │   ├── config-default.toml
│   │   │   ├── catpuccin.toml
│   │   │   ├── prezto.toml
│   │   │   └── tokyo-night.toml
│   │   └── starship.toml            ← symlink → configs/config-default.toml
│   ├── zsh/
│   ├── nvim/
│   ├── sunsetr/
│   │   └── sunsetr.toml
│   └── qt6ct/
│       └── qt6ct.conf
├── .zshenv
└── Pictures/
    ├── Wallpapers/
    └── Screenshots/
```
