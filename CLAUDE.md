# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Synapse is a Wayland desktop shell for Hyprland: a Quickshell/QML shell UI (`config/quickshell/`) paired with a Lua-based Hyprland configuration (`config/hypr/`), plus dotfiles for a few other apps (ghostty, mpv, starship, zsh, fastfetch, qt6ct, sunsetr) and a bash installer for Arch-based distros. There is no application build, package manager, or test suite — this is a configuration/dotfiles project deployed onto a live Linux desktop session.

## Commands

There is no build/lint/test tooling (no package.json, no CI). The only "commands" are the installer and manual verification on a running Hyprland+Quickshell session:

- `./boot.sh` — top-level entry point. Detects distro, backs up `~/.config`, clones/updates the repo into `~/.local/src/Synapse`, then runs `install/install.sh`.
- `install/install.sh` — Arch-specific installer, sources `install/steps/01..06-*.sh` in order (AUR helper → pacman/AUR packages → services → Hyprland plugins → configs → shell config).
- `install/validate.sh` — post-install sanity check; verifies required/optional CLI tools are on `PATH` (quickshell, hyprland, matugen, awww, etc.).
- Testing a QML change: **`config/quickshell` is not copied anywhere** — Hyprland launches quickshell against a fixed, hardcoded path, `~/.local/src/Synapse/config/quickshell` (`quickshell -c ~/.local/src/Synapse/config/quickshell`, see `config/hypr/modules/autostart.lua`). That path is also where `boot.sh` clones/pulls the repo (`REPO_DIR="$HOME/.local/src/Synapse"`) — it is **not** "wherever you happen to have this repo checked out." If your working checkout lives elsewhere (e.g. `~/Projects/Synapse`, as it does here), quickshell will keep reading the old copy at `~/.local/src/Synapse` and won't see your edits at all, until that clone is brought up to date (symlink `~/.local/src/Synapse` to your working checkout, or push and re-run `boot.sh`/`git pull` inside `~/.local/src/Synapse`). Only once your working copy *is* the thing quickshell reads from does editing files under `config/quickshell/` and restarting quickshell (`pkill quickshell` then re-trigger autostart, or `hyprctl dispatch exit` to relaunch Hyprland) become enough to see the change with no separate install step.
- Testing a Hyprland Lua change: `config/hypr/` files **are** copied to `~/.config/hypr/` by install step 5, so changes there require re-running that step (or manually `cp`'ing) before Hyprland will pick them up, since Hyprland reads from `~/.config/hypr`, not the repo.
- There's no automated way to exercise the QML UI outside a real Hyprland session; when asked to verify shell UI changes, say so explicitly rather than claiming to have tested them.

## Architecture

### Repo layout vs. deployed layout

`DEPLOY-MAP.md` is the authoritative source→destination map — consult and update it whenever you add a new file that the installer should deploy. Two deployment models coexist:

1. **Copied at install time**: `config/hypr/`, `config/ghostty/`, `config/mpv/`, `config/fastfetch/`, `config/starship/`, `config/zsh/`, `config/nvim/` are copied into `~/.config/...` by `install/steps/05-config.sh` and `06-shell-config.sh`. Edits here require reinstalling/re-copying to take effect on a live system.
2. **Run in place from the repo**: `config/quickshell/` is *not* copied — Quickshell is launched with `-c` pointing straight at the fixed path `~/.local/src/Synapse/config/quickshell`, hardcoded in `autostart.lua` rather than derived from wherever this repo happens to be checked out (see the "Testing a QML change" note above for what that means during local development). Only the wallpaper assets under `config/quickshell/src/assets/wallpapers/` get seeded into `~/Pictures/Wallpapers/`.

Runtime state (JSON files written by the running shell, not part of the repo) lives under `~/.config/Synapse/src/user_data/` — wallpaper config, clipboard pins, kanban tasks, keybind overrides, colors, etc. See the "Summary tree" at the bottom of `DEPLOY-MAP.md`.

### Hyprland config (`config/hypr/`)

`hyprland.lua` is the entry point and just `require()`s modules in a fixed order: `monitors → env → autostart → appearance → animations → input → plugins → binds → synapse-keybinds → rules`. Hyprland v0.55+ prefers `.lua` over `.conf` if both exist (see the priority logic duplicated in `boot.sh`'s pre-flight check). Binds use the `hl.bind(...)` / `hl.dsp.*` Lua API (custom to this Hyprland Lua config system, not plain hyprland.conf syntax). `binds.lua` deliberately excludes Synapse's own popup keybinds (Super+D, Super+V, etc.) to avoid conflicts — see "Keybinds" below for where those actually come from.

### Quickshell shell (`config/quickshell/`)

Entry point `shell.qml` instantiates windows/overlays once per screen (`Variants` over `Quickshell.screens`) and force-instantiates a few global singletons that need startup side effects (`KeybindService`, `UpdateService`, `IpcManager`).

Global singletons are declared in `src/qmldir` (`singleton Name path`) and are the backbone of shared state — QML doesn't need imports to reach them, any file can reference `Theme`, `Popups`, `ShellState`, `IpcManager`, `ClockState`, `ScreenRecService`, `CavaService`, `ClipboardService`, `KeybindService`, `UpdateService` directly:

- **`state/Popups.qml`** — the single source of truth for which popup/dashboard page is open. All popups toggle through `Popups.closeAll()` + setting their own `xOpen` flag, so only one popup is ever open at a time.
- **`state/ShellState.qml`** — misc global toggles owned by other components (wifi/bluetooth/DND/focus mode/etc — see the ownership comment at the top of the file) plus the Hyprland "submap" passthrough mechanism used while capturing a new keybind.
- **`state/IpcManager.qml`** — centralizes every `IpcHandler` (external `hyprctl dispatch` / `qs ipc` entry point) in one place specifically so multi-monitor setups (where `TopBar`/`PopupLayer` are duplicated per-screen) only ever have one handler reacting to a given signal. New IPC-triggerable actions should be added here, not on a per-window component.
- **`theme/Theme.qml`** — flattens `Colors.qml` (from `theme/ColorLoader.qml`, a `FileView` that watches `~/.config/Synapse/src/user_data/colors.json`) and `Metrics.qml` into one property surface. QML singletons can't alias another singleton's properties directly, hence the manual re-binding of every property.
- **`services/`** — one QML object per external integration, mostly thin wrappers around CLI tools driven via `Quickshell.Io` `Process`/`SplitParser` (nmcli, bluetoothctl, playerctl, wf-recorder, cava, etc.). Some are qmldir singletons (audio/network/etc. don't need to be — check `src/qmldir` for which ones are global vs. instantiated per-use).
- **`popups/`, `windows/`, `modules/`, `components/`** — the UI layer. New popups go through `popups/PopupLayer.qml` (per the comment in `shell.qml`); don't wire a new popup directly into `shell.qml`.

### Theming pipeline (Material You via matugen)

Wallpaper change → `WallpaperService.qml` runs `awww img` to set the wallpaper, symlinks `curr_wall`, then invokes `matugen` using `src/config/matugen.toml`. Matugen renders three templates:

- `synapse` template → `~/.config/Synapse/src/user_data/colors.json` (consumed by `ColorLoader.qml`/`Theme.qml` at runtime, hot-reloaded via `FileView.watchChanges`)
- `hyprland_colors` template → `~/.config/hypr/colors.conf`
- `hyprland_colors_lua` template → `~/.config/hypr/modules/colors.lua`

So a full color scheme update touches both the running QML shell and the Hyprland config simultaneously, without a reinstall.

### Keybinds (Synapse's own shell shortcuts, e.g. `SUPER+D` for the dashboard)

These are a *different* mechanism from `binds.lua` and are generated at runtime, not hand-written:

1. `config/quickshell/src/config/keybind-defaults.json` is the single source of truth for the 18 default shell actions (mods/key/label/group per action). Its keys must exactly match the `target:` strings in `IpcManager.qml`'s `IpcHandler`s — nothing enforces this at edit time, so double check when adding an action.
2. `KeybindService.qml` loads that JSON, overlays the user's saved overrides from `~/.config/Synapse/src/user_data/keybinds.json`, and from the merged result generates `~/.config/Synapse/SynapseKeybinds.lua` (and `.conf`, for parity) — real `hl.bind(...)` lines, one per action, each shelling out to `qs ipc call <action> toggle`.
3. `config/hypr/modules/synapse-keybinds.lua` — a static module, `require()`'d from `hyprland.lua` right after `binds.lua` — unconditionally `dofile()`s the generated `SynapseKeybinds.lua` (wrapped in `pcall` since it may not exist yet on a brand new install before Quickshell has run once). Quickshell does **not** self-modify `hyprland.lua`/`hyprland.conf` to wire this up; the `require()` ships in the repo like any other module.
4. Changing a bind in the Config → Keybinds page rewrites `keybinds.json`, regenerates `SynapseKeybinds.lua`, and runs `hyprctl reload` — so it needs to survive Hyprland reparsing its config from scratch on every `hyprctl reload`, which is why step 2/3 always materializes the *full* resolved bind set rather than doing anything incremental.
5. `install/steps/06-shell-config.sh` runs a live conflict check (`hyprctl binds -j`) against the same `keybind-defaults.json` at install time, and pre-unbinds (in `keybinds.json`) any default that collides with an existing Hyprland bind.

If you add/rename a shell action: update `keybind-defaults.json` and the matching `IpcHandler` target in `IpcManager.qml` together — they're the two ends of the same string and nothing type-checks the match between them.
