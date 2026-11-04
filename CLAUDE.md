# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Synapse is a Wayland desktop shell for Hyprland: a Quickshell/QML shell UI (`config/quickshell/`) paired with a Lua-based Hyprland configuration (`config/hypr/`), plus dotfiles for a few other apps (ghostty, mpv, starship, zsh, fastfetch, qt6ct, sunsetr) and a bash installer for Arch-based distros. There is no application build, package manager, or test suite — this is a configuration/dotfiles project deployed onto a live Linux desktop session.

**This checkout (`~/Project/Synapse-Dev`) is a separate, unlinked dev copy — it is not the live deployment.** The actual deploy source that `~/.config/hypr`, `~/.config/quickshell`, etc. symlink into is `~/.local/src/Synapse` (see `~/.config/Synapse/repo-path`). Always make edits here in `~/Project/Synapse-Dev` and never touch `~/.local/src/Synapse` or the `~/.config/*` deploy paths directly — changes made there won't be reflected here, and this repo exists purely to give a simpler, non-live editing experience.

## Commands

There is no build step. Two automated checks run in CI (`.github/workflows/quickshell.yml`) and locally:

- `node config/quickshell/tests/surface-path.test.mjs` — unit tests of the surface frame path (`shapes/surfacePath.js`).
- `config/quickshell/tests/smoke.sh` — loads the singletons and the shared UI components offscreen against throwaway data and fails on any QML error. Layer-shell windows can't be created offscreen, so the surface itself still needs a live session.

Everything else is the installer and manual verification on a running Hyprland+Quickshell session:

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

The repo location is resolved once by `boot.sh` and written to `~/.config/Synapse/repo-path`. In QML, use `Paths.repoDir`, which reads that file, rather than hardcoding a path — and note it **cannot** be derived from `Quickshell.shellDir`, because `~/.config/quickshell` is a symlink and quickshell reports the link path, not the checkout behind it.

Runtime state lives under `~/.config/Synapse/` (never symlinked): `src/user_data/*.json` plus the generated `SynapseKeybinds.lua` and the user's own `monitors.lua`. See the "Summary tree" at the bottom of `DEPLOY-MAP.md`.

### Hyprland config (`config/hypr/`)

`hyprland.lua` is the entry point and just `require()`s modules in a fixed order: `monitors → env → autostart → appearance → animations → input → plugins → binds → synapse-keybinds → rules`. Hyprland v0.55+ prefers `.lua` over `.conf` if both exist (see the priority logic duplicated in `boot.sh`'s pre-flight check). Binds use the `hl.bind(...)` / `hl.dsp.*` Lua API (custom to this Hyprland Lua config system, not plain hyprland.conf syntax). `binds.lua` deliberately excludes Synapse's own popup keybinds (Super+D, Super+V, etc.) to avoid conflicts — see "Keybinds" below for where those actually come from.

### Quickshell shell (`config/quickshell/`)

Entry point `shell.qml` force-instantiates a few global singletons that need startup side effects (`KeybindService`, `UpdateService`, `IpcManager`, `BatteryWarningService`) and loads `windows/ShellHost.qml`, the **Dynamic Surface** root (#37). Per screen (`Variants` over `Quickshell.screens`) it creates:

- `windows/DynamicSurface.qml` — one fullscreen transparent layer surface (layer `Overlay`, namespace `synapse-frame`) that draws the whole frame as a single `shapes/SurfaceShape.qml` path and hosts the bar, every popup (each grows a *region* of the frame: `top`, `right`, `leftCenter`, `rightCenter`, `bottomCenter`, `bottomRight`), the passive toast and OSD, the click shield and the border triggers. Over a fullscreen window the frame hides unless it shows something. Its input mask covers only the visible frame, so clicks elsewhere reach apps.
- `windows/StrutWindow.qml` — an invisible window that only reserves space (exclusive zone) along one edge: the bar's at the top; at the default border width the sides and bottom reserve nothing and `gaps_out` keeps windows clear of the borders, a wider border (Config → Appearance) reserves the extra width there.
- The centered modals (`ConfirmDialog`, `BatteryCriticalDialog`, `UpdatePopup`) stay separate windows.

The old window stack (`TopBar`, `Border`, `PopupLayer`, per-popup windows) was removed in #43; the last release with it is v0.3.0. To run the dev checkout: `qs -p <checkout>/config/quickshell` — keybinds (`qs ipc call …`) only reach the default config, so with `-p` use `qs ipc -p <checkout>/config/quickshell call <target> toggle`.

Global singletons are declared in `src/qmldir` (`singleton Name path`) and are the backbone of shared state — a file in `src/` or a subdirectory reaches them by importing `src` (e.g. `import "../"`), then can reference `Theme`, `Popups`, `ShellState`, `IpcManager`, `ClockState`, `ScreenRecService`, `CavaService`, `ClipboardService`, `KeybindService`, `UpdateService` and the others directly:

- **`utils/Paths.qml`** — every directory the shell uses: `configDir`, `userDataDir` (with `Paths.userData("file.json")`), `wallpaperDir`, `shellDir`, `repoDir`, `cacheDir`. Never hardcode `~/.config/Synapse` in QML. Setting `SYNAPSE_CONFIG_DIR` points `configDir` somewhere else, so the dev checkout can run against throwaway data: `SYNAPSE_CONFIG_DIR=/tmp/synapse-test qs -p <checkout>/config/quickshell`. `matugen.toml` and the installer can't read it and keep their own paths. A file in a subdirectory of `src/` must import `src` itself (e.g. `import "../"`) to see the singletons.
- **`services/PrefsService.qml`** — shell preferences (how the shell behaves), stored in `shell_prefs.json` through a `JsonAdapter`. Bind to `PrefsService.<pref>` and assign to change it: saving (debounced) and hot reload are automatic, `reset(key)` / `resetAll()` / `isDefault(key)` serve the settings widgets. Wait for `PrefsService.ready` (or its `loaded` signal) before acting on a pref at startup. To add a pref, follow the 3 steps at the top of the file. User data (tasks, pins, wallpaper, keybinds) keeps its own files.
- **Appearance prefs** — `borderWidth`, `cornerRadius` and `backgroundOpacity` are `PrefsService` keys that `Metrics` reads, so `Theme.borderWidth` / `Theme.cornerRadius` follow them; the frame is filled with `Theme.surfaceBackground` (background × opacity). Background blur is the `SynapseFrameBlur` layer rule in `config/hypr/modules/rules.lua` (enabled from `shell_prefs.json` at load), flipped live by `services/AppearanceService.qml` through `hyprctl eval`.
- **`services/DataService.qml`** — the actions of Config → Data & Storage (reset prefs / wallpaper / avatar, export or clear tasks, wipe the clipboard, clear the cache, factory reset). Each ends with `finished(action, ok)`; the factory reset deletes `user_data/` (keeping the installer's `config_Provider.json`) from a detached shell after quickshell has exited, then relaunches it.
- **`state/SurfaceState.qml`** — which interactive popup is open (`activeContent`), in which surface region (`activeRegion`) and on which screen (`activeScreen`, the focused monitor by default). One popup at a time globally; `regionOf` maps each content to its region. It also gives the per-screen `scaleFor(screen)` factor from `PrefsService.surfaceScale` (`off` = 1 by default, `auto` = screen height / 1080 clamped to 0.75–1.5, or a fixed factor; set in Config → Misc; `SYNAPSE_SURFACE_SCALE` overrides it). Only the frame and region sizes scale; popup contents don't yet.
- **`state/Popups.qml`** — the API the rest of the code uses: `Popups.open("dashboard")`, `close("dashboard")` (no-op if another popup replaced it), `toggle(...)`, `togglePage("dashboard", "stats")`, `closeAll()`. `Popups.dashboardOpen` etc. are **read-only** views of `SurfaceState`; never assign them. Per-page state (`dashboardPage`, `audioPage`, `networkPage`) stays here. The passive OSD and notification toast are separate flags (`showQuick()`/`hideQuick()`, `showToast()`/`hideToast()`) so they never close a popup.
- **`state/ToastState.qml`** — the notification toast queue (one toast at a time, 5 s each, shown on the monitor focused when it arrived). The surface renders it with `components/ToastCard.qml` in the grown right notch; the Quick Controls OSD sliders live in `components/QuickControlContent.qml`, in the right-center region.
- **`state/ShellState.qml`** — misc global toggles owned by other components (wifi/bluetooth/DND/focus mode/etc — see the ownership comment at the top of the file) plus the Hyprland "submap" passthrough mechanism used while capturing a new keybind.
- **`state/IpcManager.qml`** — centralizes every `IpcHandler` (external `hyprctl dispatch` / `qs ipc` entry point) in one place, so that with one surface per screen only one handler reacts to a given signal. New IPC-triggerable actions should be added here, not on a per-window component.
- **`theme/Theme.qml`** — flattens `Colors.qml` (from `theme/ColorLoader.qml`, a `FileView` that watches `~/.config/Synapse/src/user_data/colors.json`) and `Metrics.qml` into one property surface. QML singletons can't alias another singleton's properties directly, hence the manual re-binding of every property.
- **`services/`** — one QML object per external integration, mostly thin wrappers around CLI tools driven via `Quickshell.Io` `Process`/`SplitParser` (nmcli, bluetoothctl, playerctl, wf-recorder, cava, etc.). Some are qmldir singletons (audio/network/etc. don't need to be — check `src/qmldir` for which ones are global vs. instantiated per-use).
- **Settings widgets** (`components/Settings*.qml`) — build config pages from `SettingsGroup` (titled card), `SettingsToggle`, `SettingsSlider`, `SettingsDropdown`, `SettingsTextField` (commits on Enter / focus loss), `SettingsButton` (`destructive` asks for confirmation), `SettingsRow` (read-only row, base of the others) and `SettingsDivider`. Give a control a `prefKey` and it reads/writes that `PrefsService` key and shows a reset button when it differs from the default. `MiscPage.qml` and `GeneralPage.qml` are the reference usage.
- **`popups/`, `windows/`, `modules/`, `components/`** — the UI layer. A popup's UI lives in a content component (`DashboardContent`, `NetworkContent`, `WallpaperContent`, `PowerMenu`, `AudioControl`, `NotificationList`, `HistoryTab`…); a new popup is **one entry in `DynamicSurface.contents`** (region, `size()`, `place()`, `focus()`, optional `afterClose()`, component) plus its key in `SurfaceState.regionOf`; sizes are named in `Metrics` ("Dynamic Surface regions"). The frame path itself is built by `shapes/surfacePath.js` (pure JS, non-zero fill, one path for every region) — run `node config/quickshell/tests/surface-path.test.mjs` after touching it.
- **Keyboard focus** — decided by the #38 spike: `DynamicSurface` sets `WlrKeyboardFocus.Exclusive` only while an interactive popup (or the screen-recording setup) is open on its screen, and `None` otherwise; the surface is never unmapped, so the "freshly-mapped layer surface" focus problem doesn't apply. Each content's `focus()` in the `contents` table picks the item to focus; Escape is handled by the surface's focus scope. Passive content (OSD, toast) never takes the keyboard. The separate modal windows use `components/PopupFocusGrab.qml` (a delayed `HyprlandFocusGrab`): bind `active` to the open flag, `forceActiveFocus()` the target in `onFocused`, close in `onDismissed`. The grab must whitelist **only** the dialog window — Hyprland gives the keyboard to an arbitrary whitelisted surface — and while it's live, outside clicks and Escape only reach the dialog, so it handles Escape itself.

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

## Project workflow

Planning lives on the **Synapse Roadmap** GitHub Project (board columns: Backlog → Ready → In progress → In review → Done), with one **milestone per release** (`v0.3.0` = #27 config foundation, `v0.4.0` = #37 Dynamic Surface, `v0.5.0` = #31 config pages).

Branches:
- `main` — released code; what the in-shell updater pulls. Only `dev` → `main` release PRs land here.
- `dev` — integration branch; must stay releasable.
- `stack/<issue>-<slug>` — one per **parent issue** (label `epic`), cut from `dev`. Each sub-issue is its own branch and PR **into the stack**. A draft PR (label `stack`) from the stack into `dev`, opened after the first sub-PR is merged, tracks progress with a checklist; it's marked ready and merged once every sub-issue is done.
- `fix/…`, `feat/…`, `chore/…`, `docs/…`, `refactor/…` — one per PR. Standalone bugs and small features target `dev` directly.

Rules:
- Merge `dev` into active stacks regularly so they don't drift. Finish one stack before starting the next when they touch the same files.
- `Closes #N` only auto-closes issues on merge into `main`, so close an issue by hand (with a comment pointing to the PR) when its PR is merged into `dev` or a stack. Tick it in the stack PR's checklist and move it to Done on the board.
- Shell changes are tested on the live install (`~/.local/src/Synapse`) by applying the PR's diff there as uncommitted edits; once confirmed, `git restore .` it so the updater's `git pull` keeps working.
- Releasing: bump the version (README badge + note, `boot.sh` banner) in a `chore(release)` PR to `dev`, open the `dev` → `main` release PR, merge it, push an annotated tag `vX.Y.Z` on the merge commit, publish a GitHub Release from the notes, close the milestone.

## Commit conventions for Claude agents

When making commits to this repository, follow these rules:

- **Use conventional commit format**: `<type>(<scope>): <subject>` (one-liner, lowercase)
  - `type`: `fix`, `feat`, `chore`, `refactor`, `docs`, `style`, `test`, etc.
  - `scope`: (optional) affected area, e.g., `wallpaper`, `keybinds`, `colors`, `shell`
  - `subject`: concise description of the change, imperative mood
  - Examples: `fix(wallpaper): enable horizontal touchpad scroll in selector`, `feat(colors): add matugen integration`

- **Do not include "Generated with Claude Code" or similar attribution tags** in commit messages or PR descriptions. These are automated platform messages and clutter the git history. The commit author/date is sufficient attribution.

- **Commit messages should be one-liner** — avoid multi-line commit bodies unless absolutely necessary to explain a non-obvious design decision. Most changes are self-explanatory via the diff and PR description.

- **PR descriptions** (when creating pull requests) should be similarly clean: a brief summary of what changed and why, without platform/tool attribution tags. Focus on the change, not the mechanism that produced it.
