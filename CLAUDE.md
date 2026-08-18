# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Synapse is a Wayland desktop shell for Hyprland: a Quickshell/QML shell UI (`config/quickshell/`) paired with a Lua-based Hyprland configuration (`config/hypr/`), plus dotfiles for a few other apps (ghostty, mpv, starship, zsh, fastfetch, qt6ct, sunsetr) and a bash installer for Arch-based distros. There is no application build, package manager, or test suite — this is a configuration/dotfiles project deployed onto a live Linux desktop session.

**This checkout (`~/Project/Synapse-Dev`) is a separate, unlinked dev copy — it is not the live deployment.** The actual deploy source that `~/.config/hypr`, `~/.config/quickshell`, etc. symlink into is `~/.local/src/Synapse` (see `~/.config/Synapse/repo-path`). Always make edits here in `~/Project/Synapse-Dev` and never touch `~/.local/src/Synapse` or the `~/.config/*` deploy paths directly — changes made there won't be reflected here, and this repo exists purely to give a simpler, non-live editing experience.

## Commands

There is no build/lint/test tooling (no package.json, no CI). The only "commands" are the installer and manual verification on a running Hyprland+Quickshell session:

- `./boot.sh` — top-level entry point. Detects distro, resolves the repo location, backs up every deploy destination, then runs `install/install.sh`.
- `install/install.sh` — Arch-specific installer, sources `install/steps/01..06-*.sh` in order (AUR helper → pacman/AUR packages → services → Hyprland plugins → configs → shell config).
- `install/link.sh` — re-applies the deploy manifest and nothing else (no packages, no sudo). `--dry-run` to preview. Run it after adding a **new** config file; existing files need nothing.
- `install/validate.sh` — post-install sanity check; verifies CLI tools are on `PATH` and that every manifest destination is still a symlink into the repo.
- **Deployment is by symlink, but this checkout is not the deployed one.** In the live deployment, `~/.config/hypr`, `~/.config/quickshell`, `~/.config/nvim` etc. are symlinks into the repo at `~/.local/src/Synapse` (see `install/lib/manifest.sh` and `~/.config/Synapse/repo-path`), so editing a file *there* changes the running system with no install step. This checkout (`~/Project/Synapse-Dev`) is a separate, unlinked copy — editing here does **not** affect the running session.
- Testing a QML change: apply/port the change in `~/.local/src/Synapse/config/quickshell/`, then restart quickshell (`pkill quickshell` and re-launch, or `hyprctl dispatch exit` to relaunch Hyprland). `~/.config/quickshell` symlinks to that checkout, which also makes it Synapse quickshell's `default` config — so `quickshell` and `qs ipc call ...` work with no `-c`.
- Testing a Hyprland Lua change: apply/port the change in `~/.local/src/Synapse/config/hypr/`, then `hyprctl reload`.
- Adding a **new** file that should be deployed: add it to `install/lib/manifest.sh` (if it isn't covered by a recursive `dir/` entry), update `DEPLOY-MAP.md`, and run `install/link.sh` from `~/.local/src/Synapse`.
- There's no automated way to exercise the QML UI outside a real Hyprland session; when asked to verify shell UI changes, say so explicitly rather than claiming to have tested them.

## Architecture

### Repo layout vs. deployed layout

`install/lib/manifest.sh` is the machine-readable source→destination map and `DEPLOY-MAP.md` is its human-readable twin — **update both together** whenever you add a file the installer should deploy. Three tiers:

1. **`dir`** — whole directory symlinked into the repo (`config/quickshell/`, `config/mpv/`, `config/fastfetch/`, `config/starship/configs/`). Only for directories nothing writes into at runtime.
2. **`file`** — per-file symlinks inside a *real* directory (`config/hypr/`, `config/nvim/`, `config/ghostty/`, `config/zsh/`). Used wherever runtime output has to sit alongside repo files: matugen writes `~/.config/hypr/modules/colors.lua` and `~/.config/nvim/colors/nvim-colors.json`, zsh writes its history. Keeping those directories real is why no runtime path had to move.
3. **`copy`** — copied once, never overwritten, because another tool rewrites it in place (`sunsetr.toml`, `qt6ct.conf`, `nvim/lazy-lock.json`).

The repo location is resolved once by `boot.sh` and written to `~/.config/Synapse/repo-path`. Read that file rather than hardcoding a path — and note it **cannot** be derived from `Quickshell.shellDir`, because `~/.config/quickshell` is a symlink and quickshell reports the link path, not the checkout behind it.

Runtime state lives under `~/.config/Synapse/` (never symlinked): `src/user_data/*.json` plus the generated `SynapseKeybinds.lua` and the user's own `monitors.lua`. See the "Summary tree" at the bottom of `DEPLOY-MAP.md`.

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

Wallpaper change → `WallpaperService.qml` runs `awww img` to set the wallpaper, symlinks `curr_wall`, then invokes `matugen` using `src/config/matugen.toml`. Matugen renders seven templates:

- `synapse` → `~/.config/Synapse/src/user_data/colors.json` (consumed by `ColorLoader.qml`/`Theme.qml` at runtime, hot-reloaded via `FileView.watchChanges`)
- `hyprland_colors_lua` → `~/.config/hypr/modules/colors.lua` (`dofile()`'d by `modules/appearance.lua`)
- `hyprland_colors` → `~/.config/hypr/colors.conf` (sourced by `hyprlock.conf`)
- `neovim` → `~/.config/nvim/colors/nvim-colors.json`, then `pkill -SIGUSR1 nvim`
- `ghostty` → `~/.config/ghostty/ghostty.colors.conf`
- `vscode-raw` / `vscode-json` → `~/.cache/matugen/vscode-colors*`

So a full color scheme update touches the running QML shell, the Hyprland config, the lock screen, the terminal and the editor simultaneously, without a reinstall.

**A template whose `input_path` is missing makes matugen abort the entire run** — every output is skipped, not just that one. This silently killed all theming between commits `b081c56` and the fix. If colors stop updating, first check that every `input_path` in `matugen.toml` exists under `src/config/templates/`.

### Keybinds (Synapse's own shell shortcuts, e.g. `SUPER+D` for the dashboard)

These are a *different* mechanism from `binds.lua` and are generated at runtime, not hand-written:

1. `config/quickshell/src/config/keybind-defaults.json` is the single source of truth for the 18 default shell actions (mods/key/label/group per action). Its keys must exactly match the `target:` strings in `IpcManager.qml`'s `IpcHandler`s — nothing enforces this at edit time, so double check when adding an action.
2. `KeybindService.qml` loads that JSON, overlays the user's saved overrides from `~/.config/Synapse/src/user_data/keybinds.json`, and from the merged result generates `~/.config/Synapse/SynapseKeybinds.lua` (and `.conf`, for parity) — real `hl.bind(...)` lines, one per action, each shelling out to `qs ipc call <action> toggle`.
3. `config/hypr/modules/synapse-keybinds.lua` — a static module, `require()`'d from `hyprland.lua` right after `binds.lua` — unconditionally `dofile()`s the generated `SynapseKeybinds.lua` (wrapped in `pcall` since it may not exist yet on a brand new install before Quickshell has run once). Quickshell does **not** self-modify `hyprland.lua`/`hyprland.conf` to wire this up; the `require()` ships in the repo like any other module.
4. Changing a bind in the Config → Keybinds page rewrites `keybinds.json`, regenerates `SynapseKeybinds.lua`, and runs `hyprctl reload` — so it needs to survive Hyprland reparsing its config from scratch on every `hyprctl reload`, which is why step 2/3 always materializes the *full* resolved bind set rather than doing anything incremental.
5. `install/steps/06-shell-config.sh` runs a live conflict check (`hyprctl binds -j`) against the same `keybind-defaults.json` at install time, and pre-unbinds (in `keybinds.json`) any default that collides with an existing Hyprland bind.

If you add/rename a shell action: update `keybind-defaults.json` and the matching `IpcHandler` target in `IpcManager.qml` together — they're the two ends of the same string and nothing type-checks the match between them.
