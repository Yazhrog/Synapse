# Synapse — Deployment Map

All filesystem locations touched by the installer or at runtime.
`$REPO` = wherever you cloned Synapse (default `~/.local/src/Synapse`).

---

## Install-time deployments

### Step 5 — Hyprland & app configs  (`install/steps/05-config.sh`)

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

Directories created unconditionally:
- `~/.config/hypr/modules/`
- `~/.config/hypr/scripts/`
- `~/Pictures/Screenshots/`

---

### Step 6 — Synapse / Quickshell config  (`install/steps/06-shell-config.sh`)

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
It writes two outputs (defined in `matugen.toml`):

| Matugen output | Path |
|----------------|------|
| `synapse` template | `~/.config/Synapse/src/user_data/colors.json` |
| `hyprland_colors` template | `~/.config/hypr/colors.conf` |

> `$SHELL_DIR` = the directory quickshell was launched from (typically `~/.config/quickshell`).

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
│   └── zsh/
├── .zshenv
└── Pictures/
    ├── Wallpapers/
    └── Screenshots/
```
