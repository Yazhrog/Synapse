# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Synapse is a Wayland desktop shell for Hyprland: a Quickshell/QML shell UI (`config/quickshell/`) paired with a Lua-based Hyprland configuration (`config/hypr/`), plus dotfiles for a few other apps (ghostty, mpv, starship, zsh, fastfetch, qt6ct, sunsetr) and a bash installer for Arch-based distros. There is no application build, package manager, or test suite — this is a configuration/dotfiles project deployed onto a live Linux desktop session.

**This checkout (`~/Project/Synapse-Dev`) is a separate, unlinked dev copy — it is not the live deployment.** The actual deploy source that `~/.config/hypr`, `~/.config/quickshell`, etc. symlink into is `~/.local/src/Synapse` (see `~/.config/Synapse/repo-path`). Always make edits here in `~/Project/Synapse-Dev` and never touch `~/.local/src/Synapse` or the `~/.config/*` deploy paths directly — changes made there won't be reflected here, and this repo exists purely to give a simpler, non-live editing experience.

## Commands

There is no build step. These checks run in CI (`.github/workflows/quickshell.yml`) and locally:

- `config/quickshell/tests/unit.sh` — node unit tests of the pure JS modules (`tests/unit/*.test.mjs`: the surface frame path, the hyprctl builder, the nmcli / cliphist / sysinfo parsers, the keybind generator, the screen-recording and update scripts, the player labels).
- `config/quickshell/tests/smoke.sh` — offscreen against throwaway data, fails on any QML error: the singletons and shared components (`tests/smoke.qml`), every popup through `app/PopupManifest.qml`'s imports only (`tests/smoke-imports.qml`), **every scene** of `tests/lib/SceneList.qml` on its own (`tests/smoke-registries.qml`: the popups, the bar zones, and every entry of the registries — dashboard pages, config tabs, network tabs, audio pages, bar widgets, notch items — generated from them), the contracts (`tests/contracts.qml`: `keybind-defaults.json` keys = action keys, and the shape of every registry: unique keys, components, zones, regions…), the behaviour of the core toolkit (`tests/core.qml`), of the popup lifecycle and `Dialogs` (`tests/lifecycle.qml`), of `Prefs` (`tests/prefs.qml`) and of the design tokens and colour source (`tests/theme.qml`). Layer-shell windows (the surface itself, `ConfirmDialog`, `BatteryCriticalDialog`, `UpdatePopup`) can't be created offscreen and still need a live session. A registry entry gets its scene automatically; any other new view goes into `SceneList.qml`.
- `config/quickshell/tests/golden.sh diff [<base-ref>]` — **proves "no visible change"**: captures every scene offscreen for the base commit and the working tree and compares them pixel by pixel. CI runs it on every PR (label a PR `visual-change` when the look changes on purpose). Scenes showing the time are only compared with libfaketime installed (`pacman -S libfaketime`).
- `config/quickshell/tests/layers.py` — the dependency rules of `ARCHITECTURE.md` §11 and the size budgets of §9, **enforced in CI** (exit 1 on any violation; files over their view/service budget are warnings, over 500 lines a violation). There is no allowlist. `--report` never fails, `--self-test` plants one violation per rule in a copy of `src/` and checks each is caught (CI runs it too).
- **Imports: `import qs.src.<folder>` only** (e.g. `import qs.src.services.network`), one line per folder whose types or singletons the file uses; files in the same folder need no import. There is no `qmldir`: a file with `pragma Singleton` (root `Singleton {}`) is a singleton automatically. Relative imports are only for a `.js` file next to the file (`import "keynames.js" as KeyNames`); `tests/layers.py` flags any `import "../…"`. This also removed the old folder-scanning trap (folders listed only in a `qmldir` weren't scanned).

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

The shell is built in layers, and **`ARCHITECTURE.md` is the reference**: layers §4, patterns §5, final tree §6, contracts of the core types §8, conventions and size budgets §9, recipes §10, tests §11. `tests/layers.py` enforces the dependency rules in CI (no allowlist: a violation fails the PR).

#### Layers

A file imports only its own layer and the layers below it.

| Layer | Folder | Holds | Never |
|---|---|---|---|
| Root | `shell.qml`, `app/` | `App.qml` (eager services, the manifests, `ShellHost`), `PopupManifest.qml` (every `PopupSpec`), `ActionManifest.qml` | logic of its own |
| Hosts | `surface/`, `dialogs/` | the per-screen frame engine and the modal windows | import a `features/` folder (they get features through the manifests) |
| Views | `features/<feature>/` | containers that bind to services and state, plus feature-local parts | run a command or read a file (`Process`, `FileView`, `Socket`) |
| Commands | `actions/` | `Actions` registry, `IpcBridge` | views |
| UI state | `state/` | `SurfaceState`, `Popups`, `PopupLifecycle`, `Dialogs`, `ToastState`, `ShellModes` | views |
| Pure UI | `components/{base,inputs,feedback,settings}` | presentational widgets: inputs as properties, outputs as signals | any singleton but `Theme` and `core/`; any import but `theme/`, `core/` and other `components/` folders |
| Domain | `services/<domain>/` (`system`, `network`, `media`, `desktop`, `data`, `notifications`, `time`) | non-visual singletons, one per external system or data set; pure parsers as `.js` next to them | import `state/`, `actions/`, `features/`, `surface/`, `dialogs/`; name `Popups` or `SurfaceState`; have a visual root |
| Foundation | `theme/`, `core/` | design tokens and the colour source; `Exec`, `JsonStore`, `Poller`/`Lease`, `Hypr`, `Paths`, `Log`, the spec types (`core/specs/`) | depend on anything above |

Everywhere: no relative import except a `.js` file next to the file, and no shell script element (after `-c`) with a value concatenated or interpolated into it.

#### Boot and the Dynamic Surface

`shell.qml` only creates `src/app/App.qml`, the composition root. It force-instantiates the singletons that need startup side effects (`KeybindService`, `UpdateService`, `IpcBridge`, `BatteryWarningService`, …) and hands the manifests to the framework: `PopupManifest` → `SurfaceState` and the surface, `ActionManifest` → `Actions`, `BarWidgets` → the bar. It also creates `surface/ShellHost.qml`, the **Dynamic Surface** root (#37). Per screen (`Variants` over `Quickshell.screens`) that creates:

- **`surface/DynamicSurface.qml`** — one fullscreen transparent layer surface (layer `Overlay`, namespace `synapse-frame`).
  - It draws the whole frame as a single `surface/shape/SurfaceShape.qml` path, built by `surfacePath.js` (pure JS, non-zero fill, one path for every region; run `tests/unit.sh` after touching it).
  - It hosts the bar, every popup, the passive toast and OSD, the click shield and the border triggers. Each popup grows a *region* of the frame: `top`, `right`, `leftCenter`, `rightCenter`, `bottomCenter` or `bottomRight`.
  - It never imports a popup's feature: it reads the manifest that `App` → `ShellHost` hand it.
  - Its parts sit next to it, each taking the surface as `surface`:
    - `Regions`: target sizes, collision rules, the animated geometry and `rect(region)`.
    - `SurfaceBar`: the notch contents, laid out per zone by `BarZone`.
    - `SurfacePopupHost`: the popup loaders, their focus and `afterClose`.
    - `SurfaceTriggers`, `SurfaceClickShield`, `SurfaceInputMask`.
    - `SurfaceFullscreen`: over a real fullscreen window the frame hides unless it shows something.
  - The input mask covers only the visible frame, so clicks elsewhere reach apps.
- **`surface/StrutWindow.qml`** — an invisible window that only reserves space along one edge. The bar's is at the top. At the default border width the sides and bottom reserve nothing and `gaps_out` keeps windows clear of the borders; a wider border (Config → Appearance) reserves the extra width there.
- **The modal windows** in `dialogs/` (`ConfirmDialog`, `BatteryCriticalDialog`, `UpdatePopup`) stay separate windows.

**Keyboard focus** (decided by the #38 spike):
- `DynamicSurface` sets `WlrKeyboardFocus.Exclusive` only while an interactive popup (or the screen-recording setup) is open on its screen, and `None` otherwise. The surface is never unmapped, so the "freshly-mapped layer surface" focus problem doesn't apply.
- A spec's `focus(item)` picks the item to focus once the popup is opening. Escape is handled by the surface's focus scope. Passive content (OSD, toast) never takes the keyboard.
- The modal windows use `dialogs/PopupFocusGrab.qml`, a delayed `HyprlandFocusGrab`:
  - Bind `active` to the open flag, `forceActiveFocus()` the target in `onFocused`, close in `onDismissed`.
  - The grab must whitelist **only** the dialog window, because Hyprland gives the keyboard to an arbitrary whitelisted surface.
  - While it's live, outside clicks and Escape only reach the dialog, so the dialog handles Escape itself.

The old window stack (`TopBar`, `Border`, `PopupLayer`, per-popup windows) was removed in #43; the last release with it is v0.3.0.

To run the dev checkout: `qs -p <checkout>/config/quickshell`. Keybinds (`qs ipc call …`) only reach the default config, so with `-p` use `qs ipc -p <checkout>/config/quickshell call <target> toggle`.

#### Patterns and where they live

- **Gateways** (`core/`, `import qs.src.core`):
  - `Exec` runs one command:
    - `command` is an **argument list**, and data is always its own element. A script that needs a shell takes it as `"$1"`: `["bash", "-c", 'nmcli con up "$1"', "--", name]`.
    - `run()` (restarts if busy), `cancel()`, `busy`, an optional pure `parse(stdout)`, `timeout`, `stdinText`, `stream` (one `line(text)` per stdout line).
    - It ends with `succeeded(result)` or `failed(code, stderr)` (-2 = couldn't start, 124 = timeout, -1 = parse error), then `finished(ok)`.
    - `ExecQueue` runs commands one at a time.
  - `JsonStore` owns one JSON file:
    - `data`, `update(fn)`, `set()`, `clear()` (writes first, then resets), `flush()`, `defaults` merged into what's read.
    - Atomic writes, and nothing written before the first load. An unreadable file is kept as `<path>.broken`.
    - Also `version` + `migrate()`, `watch` and `readOnly`.
  - `Hypr` runs hyprctl changes with the right syntax for the Lua or conf provider (`setOptions`, `submap`, `evalLua`, `reload`; the commands are built by the unit-tested `hypr.js`). `Hypr.provider` says which is in use.
  - `Log` prefixes messages.
- **`core/Paths.qml`** — every directory the shell uses: `configDir`, `userDataDir` (with `Paths.userData("file.json")`), `wallpaperDir`, `shellDir`, `repoDir`, `cacheDir`.
  - Never hardcode `~/.config/Synapse` in QML.
  - `SYNAPSE_CONFIG_DIR` points `configDir` somewhere else, so the dev checkout can run against throwaway data: `SYNAPSE_CONFIG_DIR=/tmp/synapse-test qs -p <checkout>/config/quickshell`.
  - `matugen.toml` and the installer can't read it and keep their own paths.
- **Services as models** — state as `readonly` properties, intents as functions, events as signals, all on the gateways.
  - A service never reads UI state. What it needs from the UI comes as:
    - a **lease** (`LeaseCount` + `Poller` in the service, `Lease { service: X; active: … }` in the view; e.g. the System page leases the stats services);
    - a call;
    - or a signal that `app/App.qml` wires (`BatteryWarningService.critical` → the battery dialog).
  - **Views never run a command.** What a view needs done is a service intent: `PowerService`, `GpuModeService` (with its pkexec switch), `AppsService`, `KeyboardLayoutService`, `ProfileService`, `SystemInfoService`, `AudioService` (Pipewire), `MediaService` (MPRIS), `ClipboardService.decodePreview()`, …
  - Output parsers and other pure logic are `.js` files next to their service (`nmcli.js`, `cliphist.js`, `sysinfo.js`, `profile.js`, `keybindLua.js`, `screenrec.js`, `update.js`), each with node tests in `tests/unit/`.
  - The network and Quick Settings services (`WifiService`, `BluetoothService`, `VpnService`, `HotspotService`, `BrightnessService`, `ScreenFilterService`, `QuickToggleService` for Night Light, Caffeine and Airplane) feed the bar indicators, the tiles and the network tabs alike.
- **Popup state machine + facade** (`state/`):
  - `SurfaceState` knows which popup is open (`activeContent`), in which region (`activeRegion`) and on which screen (`activeScreen`, the focused monitor by default). There is one popup at a time globally, and the keys and regions come from the manifest (`popups`, `regionOf`, `specOf(key)`).
  - It is also the popup **lifecycle**: per popup and screen `closed → opening → open → closing → closed`, with signals `opening` / `opened` / `closing` / `closed(key, screen)` and `phaseOf(key, screen)`. Views react with `PopupLifecycle { popup: "network"; onOpening: … }`.
  - It gives the per-screen `scaleFor(screen)` from `Prefs.data.surfaceScale`:
    - `off` = 1, the default;
    - `auto` = screen height / 1080, clamped to 0.75–1.5;
    - or a fixed factor.
    It's set in Config → Misc, and `SYNAPSE_SURFACE_SCALE` overrides it. Only frame and region sizes scale.
  - `Popups` is the API the rest of the code uses: `open("dashboard")`, `close(...)` (a no-op if another popup replaced it), `toggle(...)`, `togglePage("dashboard", "stats")`, `closeAll()`.
    - `Popups.dashboardOpen` etc. are **read-only** views of `SurfaceState`; never assign them.
    - Per-page state (`dashboardPage`, `audioPage`, `networkPage`) lives here, wired through the spec's `pageProp` / `defaultPagePref`.
    - The OSD and the toast are separate flags (`showQuick()` / `hideQuick()`, `showToast()` / `hideToast()`), so they never close a popup.
  - `ToastState` is the notification toast queue: one toast at a time, 5 s each, on the monitor focused when it arrived. It's rendered by `components/feedback/ToastCard.qml` in the grown right notch.
  - `ShellModes` holds read-only mirrors for the surface and bar: `focusMode`, `dnd`, `screenRecord`, `airplane`. Change them through their service. The pass-through submap used while capturing a keybind is `KeybindService.setCapturing()`.
- **Command registry** (`actions/`):
  - `Actions` holds every user-triggerable command as `{ key, label, group, run }`. `Actions.run(key)` is what IPC, keybinds and buttons call.
  - The list is `app/ActionManifest.qml`: one toggle per popup with an `action`, and one per page with a `PageSpec.action`, generated from the manifest, plus its own entries (focus mode, screen recording).
  - `IpcBridge` creates one `IpcHandler { target: key; toggle() }` per action, plus `quickcontrols-show reveal` for the volume/brightness OSD.
- **Registries** (extension points, spec types in `core/specs/`) are plain `QtObject` lists, instantiated where they're read:

  | Registry | Spec | Feeds |
  |---|---|---|
  | `features/dashboard/DashboardPages.qml` | `PageSpec` | dashboard tab bar, `components/base/PageStack.qml`, popup width, toggle action, Config → General's default-page options |
  | `features/audio/AudioPages.qml` | `PageSpec` | same, for the audio popup |
  | `features/network/NetworkTabs.qml` | `PageSpec` | same, for the network popup |
  | `features/dashboard/config/ConfigTabs.qml` | `TabSpec` | Config tabs |
  | `features/dashboard/home/QuickTiles.qml` | `TileSpec` | Quick Settings grid |
  | `features/bar/BarWidgets.qml` | `BarWidgetSpec` | each bar zone, in `Prefs.data.barLayout`'s order or `defaultOrder` |
  | `features/bar/center/NotchItems.qml` | `NotchItemSpec` | center carousel (`active`, `priority`, `autoScroll`) |

  - They aren't singletons on purpose: a component declared in a singleton outlives its context at shutdown.
  - A registry must not instantiate a type that instantiates it back (QML can't load a type cycle). That's why Config → General reads the page lists through `SurfaceState.specOf(popup).pages`.
- **Mediator for modals** — `state/Dialogs.qml`:
  - `Dialogs.confirm({ title, message, label, icon, onAccept })` and `Dialogs.alert({ title, message, label })`. Requests are queued and shown one at a time; showing one closes the dashboard.
  - `ConfirmDialog` and `BatteryCriticalDialog` only render the request and report the choice; the callback runs the service intent.
- **Strategies:**

  | What varies | Where | Implementations |
  |---|---|---|
  | Frame style (`barStyle`) | `surfacePath.js` | `frame`, `bar`, `pills` |
  | Hyprland config provider | `Hypr` | Lua, conf |
  | Colour source | `theme/sources/ColorSource` | `MatugenSource` |
  | Screen recorder | `services/media/recorders/RecorderBackend` (`command({ file, geometry, audioDevice })`, `stopCommand`) | `WfRecorder` |

- **Design tokens** (`theme/`, `import qs.src.theme`) — `Theme` is the only theme import a view needs:
  - `Theme.color`:
    - roles `background`, `surface` (the frame fill), `surfaceRaised`, `accent`, `text`, `textMuted`, `border`, `danger`, `warning`, `success`;
    - state layers `hairline`, `fillSubtle`, `fillHover`, `fillPressed`, made from the foreground;
    - `scrim` (fixed black), `alpha(c, a)` and the workspace `ws*` colours.
  - `Theme.font` (families `ui` / `mono` / `icon`, sizes `caption` 9 … `display` 32, weights), `Theme.space` (`xxs` 2 … `xxl` 24), `Theme.radius` (`sm` / `md` / `lg`, `card` = the corner pref, `notch`).
  - `Theme.motion`: `instant` 80, `fast` 150, `normal` 200, `slow` 320 (the frame animation); curves `standard`, `emphasized`, `overshoot`. Animate with `theme/Anim.qml` and `Fade.qml`.
  - `Theme.frame`: every frame / notch / region size, `borderWidth`, `opacity`, `barStyle`.
  - The groups are `theme/tokens/*Tokens.qml`.
  - Colours come from `MatugenSource`, which reads `user_data/colors.json` through a watched read-only `JsonStore` and only replaces the colours present.
  - Views still hold ~1 400 literal colours, sizes and durations. They move to tokens in v0.8.0's per-area passes (decision D1, mapping table in `ARCHITECTURE.md` §5.12); new code uses the tokens.
- **Preferences** — `services/data/Prefs.qml` + `PrefSchema.qml`, stored in `shell_prefs.json` through a `JsonStore`:
  - `PrefSchema.keys` holds every pref as `{ default, type, options | min/max, label, description }`.
  - Values are validated on read and write: a wrong type gets the default, numbers are clamped, and `strict` options such as `barStyle` reject anything else.
  - Read `Prefs.data.<key>` (bindable), write `Prefs.set(key, v)`. Also `reset(key)`, `resetAll()`, `isDefault(key)`, `defaults`.
  - Saving is debounced, hand edits are picked up live, and unknown keys are kept. Wait for `Prefs.ready` (or `loaded`) before acting on a pref at startup.
  - User data (tasks, pins, wallpaper, keybinds) keeps its own files.
  - **Appearance prefs:**
    - `borderWidth`, `cornerRadius` and `backgroundOpacity` feed `Theme.frame.borderWidth`, `Theme.radius.card` (and `notch`, in proportion) and `Theme.frame.opacity`. The frame is filled with `Theme.color.surface` (background × opacity).
    - `barStyle` is `frame` (notches + borders), `bar` (full-width top bar, no borders) or `pills` (floating capsules, `Theme.frame.pillGap` from the edges). `DynamicSurface.borderWidth` is 0 in bar and the gap in pills, so the region rects work unchanged in all three.
    - Background blur is the `SynapseFrameBlur` layer rule in `config/hypr/modules/rules.lua`, enabled from `shell_prefs.json` at load and flipped live by `services/desktop/AppearanceService.qml` through `hyprctl eval`.
  - `services/data/DataService.qml` runs Config → Data & Storage's actions, each ending with `finished(action, ok)`:
    - reset prefs, wallpaper or avatar;
    - export or clear tasks;
    - wipe the clipboard, clear the cache;
    - factory reset: deletes `user_data/` (keeping the installer's `config_Provider.json`) from a detached shell after quickshell exits, then relaunches it.
- **Containers and presentational controls:**
  - `components/settings/Settings*.qml` only show `value` and report `edited(v)` (`SettingsRow` adds a reset button while `value` differs from `defaultValue`, emitting `resetRequested()`).
  - Config pages use the containers in `features/dashboard/config/controls/`: `PrefToggle { key: "myPref" }`, `PrefSlider`, `PrefDropdown`, `PrefTextField`. These take their label, range, options and default from `PrefSchema` and write through `Prefs`. `GeneralPage` and `AppearancePage` are the reference usage.
  - The same split holds for `ToastCard`, `BrightnessSlider`, `PillButton`, `AppTile`, … : inputs as properties, outputs as signals.

#### Recipes

Each one is detailed in `ARCHITECTURE.md` §10.

| To add | Do |
|---|---|
| A popup | `features/<feature>/<Feature>Content.qml` + `<Feature>Popup.qml` (a `PopupSpec`: `key`, `region`, `size(s, item)`, `place(s, w, h)`, optional `focus` / `afterClose` / `pageProp` / `defaultPagePref` / `action`) + one line in `app/PopupManifest.qml`. Sizes go in `theme/tokens/FrameTokens.qml`. Region, click-outside, Escape, focus, lifecycle and toggle action come with it. |
| A dashboard page, audio page or network tab | Its view + one `PageSpec` in the registry, and its action in `keybind-defaults.json` (empty `mods` / `key` for no default bind). |
| A bar widget, notch item or Quick Settings tile | Its view + one `BarWidgetSpec` / `NotchItemSpec` / `TileSpec` in the registry. |
| A preference | One `PrefSchema` entry + one `Pref*` control on a config page. |
| A service around a CLI tool | `services/<domain>/<Name>Service.qml` on `Exec` (argument lists), a `Poller` gated by its `LeaseCount` if it polls, parsers in a `.js` next to it + `tests/unit/<tool>.test.mjs` with real output. If it must start at boot, add it to `App.qml`'s eager list. |
| An action and its keybind | One `Action` in `app/ActionManifest.qml` (or an `action` on a spec) + one line in `config/keybind-defaults.json`. The contract test checks the two key sets. |
| A persisted data file | A `JsonStore` inside the owning service, plus Config → Data & Storage if the user should be able to reset it, and `DEPLOY-MAP.md`'s runtime tree. |
| A new view outside a registry | A scene in `tests/lib/SceneList.qml`, so smoke and golden cover it. Registry entries get their scene automatically. |

Files stay within budget: views 300 lines, services, state and pure `.js` modules 350, any file 500 (that one fails CI).

### Theming pipeline (Material You via matugen)

Wallpaper change → `WallpaperService.qml` runs `awww img` to set the wallpaper, symlinks `curr_wall`, then invokes `matugen` using `src/config/matugen.toml`. Matugen renders seven templates:

- `synapse` → `~/.config/Synapse/src/user_data/colors.json` (consumed by `theme/sources/MatugenSource.qml` → `Theme.color` at runtime, hot-reloaded by its watched `JsonStore`)
- `hyprland_colors_lua` → `~/.config/hypr/modules/colors.lua` (`dofile()`'d by `modules/appearance.lua`)
- `hyprland_colors` → `~/.config/hypr/colors.conf` (sourced by `hyprlock.conf`)
- `neovim` → `~/.config/nvim/colors/nvim-colors.json`, then `pkill -SIGUSR1 nvim`
- `ghostty` → `~/.config/ghostty/ghostty.colors.conf`
- `vscode-raw` / `vscode-json` → `~/.cache/matugen/vscode-colors*`

So a full color scheme update touches the running QML shell, the Hyprland config, the lock screen, the terminal and the editor simultaneously, without a reinstall.

**A template whose `input_path` is missing makes matugen abort the entire run** — every output is skipped, not just that one. This silently killed all theming between commits `b081c56` and the fix. If colors stop updating, first check that every `input_path` in `matugen.toml` exists under `src/config/templates/`.

### Keybinds (Synapse's own shell shortcuts, e.g. `SUPER+D` for the dashboard)

These are a *different* mechanism from `binds.lua` and are generated at runtime, not hand-written:

1. `config/quickshell/src/config/keybind-defaults.json` is the single source of truth for the default binds of the 18 shell actions (mods/key/label/group per action; empty mods/key for an action without a default bind). Its keys must exactly match the action keys of the Actions registry — `tests/contracts.qml` fails otherwise.
2. `KeybindService.qml` (its pure parts in `keybindLua.js`, unit-tested) loads that JSON, overlays the user's saved overrides from `~/.config/Synapse/src/user_data/keybinds.json`, and from the merged result generates `~/.config/Synapse/SynapseKeybinds.lua` (and `.conf`, for parity) — real `hl.bind(...)` lines, one per action, each shelling out to `qs ipc call <action> toggle`.
3. `config/hypr/modules/synapse-keybinds.lua` — a static module, `require()`'d from `hyprland.lua` right after `binds.lua` — unconditionally `dofile()`s the generated `SynapseKeybinds.lua` (wrapped in `pcall` since it may not exist yet on a brand new install before Quickshell has run once). Quickshell does **not** self-modify `hyprland.lua`/`hyprland.conf` to wire this up; the `require()` ships in the repo like any other module.
4. Changing a bind in the Config → Keybinds page rewrites `keybinds.json`, regenerates `SynapseKeybinds.lua`, and runs `hyprctl reload` — so it needs to survive Hyprland reparsing its config from scratch on every `hyprctl reload`, which is why step 2/3 always materializes the *full* resolved bind set rather than doing anything incremental.
5. `install/steps/06-shell-config.sh` runs a live conflict check (`hyprctl binds -j`) against the same `keybind-defaults.json` at install time, and pre-unbinds (in `keybinds.json`) any default that collides with an existing Hyprland bind.

If you add/rename a shell action: update `keybind-defaults.json` and the action (in `app/ActionManifest.qml`, or the `action` of its PopupSpec / PageSpec) together; the contract test checks the two key sets.

## Project workflow

Planning lives on the **Synapse Roadmap** GitHub Project (board columns: Backlog → Ready → In progress → In review → Done), with one **milestone per release** (`v0.3.0` = #27 config foundation, `v0.4.0` = #37 Dynamic Surface, `v0.5.0` = #31 config pages, `v0.6.0` = #73 monolith split, `v0.7.0` = #111 architecture). Until v0.6.x, parent issues used a `stack/<issue>-<slug>` integration branch merged into `dev` in one PR; from #111 on they use native stacked PRs.

Branches:
- `main` — released code; what the in-shell updater pulls. Only `dev` → `main` release PRs land here.
- `dev` — integration branch and the **trunk of every stack**; must stay releasable.
- `fix/…`, `feat/…`, `chore/…`, `docs/…`, `refactor/…`, `test/…` — one per PR, named `<keyword>/<issue>-<slug>` when there is an issue. Standalone bugs and small features are one PR into `dev`.
- **Merge methods:** PRs into `dev` (stacked or not) are **squash-merged**, so `dev` gets one CI-tested commit per PR, titled by the PR (the branch's own commits stay on the PR). The `dev` → `main` release PR is merged with a **merge commit**, never squashed: `main` must keep `dev`'s commits as they are, or the next release PR would carry duplicates and conflicts. GitHub deletes a merged PR's branch; `git fetch --prune` drops the stale remote refs.

**Stacked pull requests** (GitHub's native stacks, `gh stack` extension). A parent issue (label `epic`) whose sub-issues build on each other ships as a stack: one branch and one PR per sub-issue, each PR based on the branch of the one below it, the bottom one on `dev`. GitHub shows the whole stack on every PR and each PR shows only its own layer's diff. Parts that don't depend on each other are separate PRs into `dev`, not a stack.

- Create: `gh stack init --base dev <branch>` for the first layer (it adopts an existing branch), commit, then `gh stack add <branch>` for each next layer, then `gh stack submit --auto` (opens the new PRs as drafts and links the stack on GitHub; a stack needs at least two PRs). Then give each PR its real title and body (`gh pr edit`), list the whole stack in merge order under `## Stack`, and `gh pr ready` it.
- Always pass the arguments that keep `gh stack` non-interactive: `init <branch>`, `add <branch>`, `submit --auto`, `view --json`, `checkout <branch-or-pr>` / `up` / `down` / `top`, `merge <pr> --yes --squash`. Never run bare `gh stack init`, `add`, `submit`, `view`, `checkout`, `switch` or `modify` (they open an editor or a picker), and never `gh pr merge` a stacked PR.
- Fix a lower layer in its own branch, never on the top one: `gh stack checkout <branch>`, commit, `gh stack rebase --upstack`, `gh stack push`, `gh stack top`.
- `gh stack sync` fetches, rebases every layer on the updated `dev`, pushes (with lease) and refreshes the stack on GitHub; run it after `dev` moves (a release, a standalone fix). On a conflict it restores every branch and exits 3: `gh stack rebase`, resolve, `git add`, `gh stack rebase --continue`.
- Merge only when the user asks: `gh stack merge <pr> --yes --squash` merges that PR **and every unmerged one below it** into `dev`, all or nothing (each PR must be ready, not draft, with its checks green); then `gh stack sync`. A stack can land part by part, bottom first.
- Exit code 9 means stacked PRs aren't enabled on the repo: say so and don't fall back to plain PRs on your own.
- Claude's shell can't push over SSH (`origin` is `git@github.com:…`). Without touching the repo config, give `gh stack` (and `git`) an environment that rewrites it to HTTPS with the `gh` credentials:
  ```sh
  export GIT_CONFIG_COUNT=3 \
    GIT_CONFIG_KEY_0=url.https://github.com/.insteadOf GIT_CONFIG_VALUE_0=git@github.com: \
    GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1= \
    GIT_CONFIG_KEY_2=credential.helper GIT_CONFIG_VALUE_2='!gh auth git-credential'
  ```
  Pushing a change to `.github/workflows/` also needs the `workflow` scope on the `gh` token (`gh auth refresh -h github.com -s workflow`, run by the user).

Rules:
- Finish one stack before starting the next when they touch the same files.
- **Done ≠ Closed.** Done (board Status) means merged into `dev`; Closed (issue state) means released to `main`. `.github/workflows/roadmap.yml` moves the board for you: a PR opened, edited, drafted or marked ready moves the issues its body closes to In progress (draft) or In review (ready), leaving Done ones alone; and for the two last steps, a push to `dev` moves the issues named by `Closes #N` in its merged PRs' bodies to Done and leaves them open, a push to `main` closes every open Done issue with a "released in vX.Y.Z" comment. So put `Closes #N` in every PR body (stacked PRs included: GitHub only links issues for PRs into `main`, so the workflow reads the body itself) and don't close or move issues by hand; `GITHUB_REPOSITORY=Yazhrog/Synapse GH_TOKEN=$(gh auth token) .github/scripts/roadmap.sh status <pr>` re-syncs one PR's issues. A sub-issue is ticked in its parent's list when it's closed, i.e. at release. Board settings that go with it: "Auto-close issue" off; "Item closed" and "Pull request merged" → Done. The workflow uses the `ROADMAP_TOKEN` secret (classic PAT, `repo` + `project`); when it expires the Roadmap runs fail until it's replaced. `DRY_RUN=1 GITHUB_REPOSITORY=Yazhrog/Synapse .github/scripts/roadmap.sh close` previews a release's closures locally, as does running the workflow by hand (dry run by default).
- Shell changes are tested on the live install (`~/.local/src/Synapse`) by applying the PR's diff there as uncommitted edits (for a stack layer, the diff from `dev` up to that layer: `git diff origin/dev...<branch>`); once confirmed, `git restore .` it so the updater's `git pull` keeps working.
- Releasing: `VERSION` (repo root, plain `X.Y.Z`) is the only place the version is written: `boot.sh` reads it for its banner (from `main` under `curl | bash`), the README badge shows the latest GitHub Release, `roadmap.sh` uses it in its closing comment. 1) Bump `VERSION` in a `chore(release)` PR to `dev`, labelled `skip-changelog`. 2) Open the `dev` → `main` release PR, also `skip-changelog`; the Version check fails unless `VERSION` is above the latest `v*` tag. 3) Merge it with a merge commit (`gh pr merge <n> --merge`): `.github/workflows/version.yml` tags `vX.Y.Z` (annotated) on the merge commit and opens a **draft** GitHub Release with the generated notes (What's Changed as `<PR title> by @user in #N`, New Contributors when there are any, Full Changelog) under a Summary / Upgrading stub, and the Roadmap workflow closes the Done issues. 4) Fill in Summary and Upgrading (no install instructions: the README has them) with `gh release edit vX.Y.Z --notes-file …` or on GitHub, publish (`gh release edit vX.Y.Z --draft=false`), close the milestone. `.github/release.yml` leaves the `skip-changelog` PRs out of the notes. Preview them with `gh api repos/Yazhrog/Synapse/releases/generate-notes -f tag_name=vX.Y.Z -f target_commitish=dev -f previous_tag_name=<last tag> --jq .body`; `DRY_RUN=1 .github/scripts/version.sh check|release` runs the version logic locally.

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
