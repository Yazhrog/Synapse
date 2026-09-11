# Synapse — Deployment Map

All filesystem locations touched by the installer or at runtime.

`$REPO` = wherever your Synapse checkout lives. The machine-readable version of
everything below is [`install/lib/manifest.sh`](install/lib/manifest.sh) —
**update both together.**

---

## Where the repo lives

Synapse deploys by **symlinking `~/.config` into the repo**, so the checkout is
the live source: editing a file there changes the running desktop, and
`git pull` ships updates without a reinstall.

`boot.sh` picks the repo location once:

- Run from a clone (`./boot.sh` inside a checkout) → **that checkout** becomes
  the live source. It is never pulled on your behalf.
- Run via `curl | bash` → clones/pulls `~/.local/src/Synapse`.

The resolved path is written to **`~/.config/Synapse/repo-path`**, the single
source of truth. `install/link.sh` and `UpdateService.qml` both read it.

> It cannot be derived from `Quickshell.shellDir`: `~/.config/quickshell` is a
> symlink and quickshell reports the link path, not the checkout behind it.

---

## Deployment tiers

| Tier | Meaning | Why |
|------|---------|-----|
| **dir** | Whole directory is a symlink into `$REPO` | Directory is 100% repo-owned; nothing writes into it at runtime |
| **file** | Per-file symlinks inside a **real** directory | Runtime-generated files must sit alongside repo files |
| **copy** | Copied once, never overwritten | You or another tool own the file after install |

The **file** tier is why no runtime output had to move: `~/.config/hypr`,
`~/.config/nvim`, `~/.config/ghostty` and `~/.config/zsh` stay real directories,
so matugen output, lazy state and zsh history keep landing exactly where they did.

### Manifest

| Source (`$REPO/`) | Destination | Tier |
|---|---|---|
| `config/quickshell/` | `~/.config/quickshell` | dir |
| `config/mpv/` | `~/.config/mpv` | dir |
| `config/fastfetch/` | `~/.config/fastfetch` | dir |
| `config/starship/configs/` | `~/.config/starship/configs` | dir |
| `config/hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | file |
| `config/hypr/hypridle.conf` | `~/.config/hypr/hypridle.conf` | file |
| `config/hypr/hyprlock.conf` | `~/.config/hypr/hyprlock.conf` | file |
| `config/hypr/modules/` *(recursive)* | `~/.config/hypr/modules/` | file |
| `config/hypr/scripts/` *(recursive)* | `~/.config/hypr/scripts/` | file |
| `config/ghostty/config` | `~/.config/ghostty/config` | file |
| `config/zsh/.zshenv` | `~/.config/zsh/.zshenv` **and** `~/.zshenv` | file |
| `config/zsh/.zshrc`, `aliasrc`, `functionrc` | `~/.config/zsh/` | file |
| `config/nvim/` *(recursive, minus `lazy-lock.json`)* | `~/.config/nvim/` | file |
| `config/nvim/lazy-lock.json` | `~/.config/nvim/lazy-lock.json` | copy — nvim rewrites on `:Lazy sync` |
| `config/sunsetr/sunsetr.toml` | `~/.config/sunsetr/sunsetr.toml` | copy — `sunsetr geo` rewrites it |
| `config/qt6ct/qt6ct.conf` | `~/.config/qt6ct/qt6ct.conf` | copy — the qt6ct GUI rewrites it |
| `config/gtk-3.0/settings.ini` | `~/.config/gtk-3.0/settings.ini` | copy — the nwg-look GUI rewrites it |
| `config/gtk-4.0/settings.ini` | `~/.config/gtk-4.0/settings.ini` | copy — the nwg-look GUI rewrites it |
| `config/quickshell/src/assets/wallpapers/` | `~/Pictures/Wallpapers/` | copy — user media |
| *(generated)* | `~/.config/starship/starship.toml` → `configs/config-default.toml` | copy — selects your theme |

Directories created but never linked: `~/Pictures/Screenshots`,
`~/Pictures/Wallpapers`, `~/.config/hypr/shaders`,
`~/.config/Synapse/src/user_data/wallpapers`.

### `~/.config/quickshell` is the `default` config

Because `~/.config/quickshell/shell.qml` exists (through the symlink),
quickshell registers Synapse as its **`default`** configuration. That is what
lets `autostart.lua` run plain `quickshell`, and the generated keybinds call
`qs ipc call <action> toggle` — both with no `-c` path.

---

## Install steps

| Step | File | What it does |
|---|---|---|
| 1 | `01-aur-helper.sh` | Detects/bootstraps `yay` or `paru` |
| 2–3 | `02-packages.sh` | pacman + AUR packages |
| 4 | `03-services.sh` | Enables NetworkManager, bluetooth, upower, pipewire |
| 5 | `04-plugins.sh` | `hyprpm` scrolloverview; clones + builds `hyprselect` into `~/.config/hypr/plugin/` |
| 7 | `05-config.sh` | Runs the manifest through `install/lib/link.sh`; sets zsh as login shell |
| 8 | `06-shell-config.sh` | Seeds `~/.config/Synapse`; live keybind conflict check |

`install/link.sh` re-applies the manifest on its own — no packages, no sudo.
Run it after a `git pull` that **adds** a file; existing links need nothing.
`--dry-run` shows what it would do.

Anything it displaces is moved to `~/.config.backup-<timestamp>-Synapse/`,
and files that differed from the repo are listed explicitly at the end.
`boot.sh` additionally snapshots every manifest destination into that same
backup under `pre-install/`.

### Seed files (`06-shell-config.sh`) — all seed-if-missing

`~/.config/Synapse/src/user_data/config_Provider.json`, `keybinds.json`,
`colors.json`, `~/.config/hypr/colors.conf`, and `~/.config/Synapse/monitors.lua`.

The live `hyprctl binds -j` conflict check **merges** unbound entries into
`keybinds.json`; it never replaces the file, and it skips actions you have
already remapped.

---

## Runtime paths (written by Quickshell services)

### Wallpaper & theming (`WallpaperService.qml`)

| Path | What it is |
|---|---|
| `~/.config/Synapse/src/user_data/wallpapers/curr_wall` | Symlink → current wallpaper |
| `~/.config/Synapse/src/user_data/wallpapers/curr_wall_static.jpg` | Static JPEG for the hyprlock background |
| `~/.config/Synapse/src/user_data/wallpaper.json` | Wallpaper path + color scheme |

Matugen runs on every wallpaper change using
`$REPO/config/quickshell/src/config/matugen.toml`, which defines **seven**
outputs:

| Template | Output |
|---|---|
| `synapse` | `~/.config/Synapse/src/user_data/colors.json` |
| `hyprland_colors_lua` | `~/.config/hypr/modules/colors.lua` |
| `hyprland_colors` | `~/.config/hypr/colors.conf` |
| `neovim` | `~/.config/nvim/colors/nvim-colors.json` (+ `pkill -SIGUSR1 nvim`) |
| `ghostty` | `~/.config/ghostty/ghostty.colors.conf` |
| `vscode-raw` | `~/.cache/matugen/vscode-colors` |
| `vscode-json` | `~/.cache/matugen/vscode-colors.json` |

`colors.lua` is `dofile()`'d by `modules/appearance.lua`; `colors.conf` is
sourced by `hyprlock.conf`.

> A template whose `input_path` is missing makes matugen abort the **entire**
> run — no outputs at all. If theming stops updating, check that every
> `input_path` in `matugen.toml` exists under `templates/`.

### User data / persistent state

| Path | Service |
|---|---|
| `.../user_data/wallpaper.json` | WallpaperService |
| `.../user_data/clipboard_pins.json` | ClipboardService |
| `.../user_data/tasks.json` | KanbanBoard |
| `.../user_data/hotspot.json` | QuickSettings / HotspotTab |
| `.../user_data/update_prefs.json` | UpdateService |
| `.../user_data/screenrec.json` | ScreenRecService |
| `.../user_data/keybinds.json` | KeybindService |
| `.../user_data/config_Provider.json` | Shell bootstrap |
| `~/.config/Synapse/monitors.lua` | You — `dofile()`'d by `modules/monitors.lua` |

### Keybinds (`KeybindService.qml`)

| Path | What it is |
|---|---|
| `~/.config/Synapse/SynapseKeybinds.lua` | Generated binds (defaults ⊕ `keybinds.json`). Rewritten on every shell start and save. |
| `~/.config/Synapse/SynapseKeybinds.conf` | Same in `.conf` syntax; parity only, sourced by nothing. |

`SynapseKeybinds.lua` is loaded by `modules/synapse-keybinds.lua` via
`pcall(dofile, ...)`. Defaults live in
`config/quickshell/src/config/keybind-defaults.json`, shared with the
installer's conflict check — one canonical copy.

### Other runtime writes

| Path | Written by |
|---|---|
| `~/.config/hypr/plugin/hyprselect/` | `04-plugins.sh` — git clone + `hyprselect.so` build |
| `~/.config/systemd/user/cliphist-wipe.service` | `ClipboardService.qml` |
| `~/Videos/screen_recordings/` | `ScreenRecService.qml` |
| `~/.config/zsh/.zsh_history`, `.zcompdump` | zsh (both gitignored) |
| `~/.cache/matugen/vscode-colors*` | matugen |

### Shader search paths (`QuickSettings.qml`)

1. `~/.config/hypr/shaders/` — yours
2. `~/.local/share/hypr/shaders/`
3. `/usr/share/hyprshade/shaders/`
4. `~/.config/quickshell/src/config/shaders/` — the ones Synapse ships

---

## Summary tree

Symlinks into `$REPO` are marked `→ repo`.

```
~/
├── .config/
│   ├── quickshell/                  → repo  (the whole shell; "default" config)
│   ├── hypr/
│   │   ├── hyprland.lua             → repo
│   │   ├── hypridle.conf            → repo
│   │   ├── hyprlock.conf            → repo
│   │   ├── modules/*.lua            → repo
│   │   │   └── colors.lua           ← matugen output (runtime)
│   │   ├── scripts/*                → repo
│   │   ├── plugin/hyprselect/       ← cloned + built by the installer
│   │   ├── shaders/                 ← your shaders
│   │   └── colors.conf              ← matugen output (runtime)
│   ├── Synapse/                     ← never linked; Synapse owns this at runtime
│   │   ├── repo-path                ← where the repo lives
│   │   ├── monitors.lua             ← your display layout
│   │   ├── SynapseKeybinds.lua      ← generated
│   │   ├── SynapseKeybinds.conf     ← generated (parity)
│   │   └── src/user_data/
│   │       ├── *.json               ← runtime state (see table above)
│   │       └── wallpapers/
│   │           ├── curr_wall            ← symlink (runtime)
│   │           └── curr_wall_static.jpg ← jpeg copy (runtime)
│   ├── ghostty/
│   │   ├── config                   → repo
│   │   └── ghostty.colors.conf      ← matugen output (runtime)
│   ├── nvim/
│   │   ├── **/*.lua                 → repo
│   │   ├── lazy-lock.json           ← copied once; nvim owns it
│   │   └── colors/nvim-colors.json  ← matugen output (runtime)
│   ├── zsh/
│   │   ├── .zshrc, aliasrc, ...     → repo
│   │   └── .zsh_history, .zcompdump ← runtime (gitignored)
│   ├── mpv/                         → repo
│   ├── fastfetch/                   → repo
│   ├── starship/
│   │   ├── configs/                 → repo
│   │   └── starship.toml            ← symlink → configs/config-default.toml
│   ├── sunsetr/sunsetr.toml         ← copied once; `sunsetr geo` owns it
│   ├── qt6ct/qt6ct.conf             ← copied once; the qt6ct GUI owns it
│   ├── gtk-3.0/settings.ini         ← copied once; the nwg-look GUI owns it
│   ├── gtk-4.0/settings.ini         ← copied once; the nwg-look GUI owns it
│   └── systemd/user/cliphist-wipe.service  ← written by ClipboardService
├── .zshenv                          → repo
├── .cache/matugen/                  ← matugen (vscode)
└── Pictures/
    ├── Wallpapers/                  ← seeded, then yours
    └── Screenshots/
```
