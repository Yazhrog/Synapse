# Synapse shell architecture

_Architecture of the Quickshell shell (`config/quickshell/`), reached in **v0.7.0** (#111). Written 2026-11-13 as the plan against `dev` after v0.6.1 (Quickshell 0.3.2); turned into the reference once the last step landed (#117, 2026-11-23)._

**Status:** reference. The shell is built as described here; `tests/layers.py` enforces §4's dependency rules and §9's size budgets in CI (§11). Where the build differs from the original plan, the "Done in" notes of §7 say how, and §6 shows the final tree. §2 and §7 keep the starting point and the moves for history; §12 is the record of the migration. Decisions D1–D7 (§14) were taken as recommended; D1 (literals → tokens) is v0.8.0's work.

---

## Contents

1. [Goals](#1-goals)
2. [Where we are after v0.6.1](#2-where-we-are-after-v061)
3. [Principles](#3-principles)
4. [Layers and the dependency rule](#4-layers-and-the-dependency-rule)
5. [Design patterns](#5-design-patterns)
6. [Tree](#6-tree)
7. [File map: v0.6.1 → v0.7.0](#7-file-map-v061--v070)
8. [Contracts of the core types](#8-contracts-of-the-core-types)
9. [Conventions](#9-conventions)
10. [Recipes: adding a feature](#10-recipes-adding-a-feature)
11. [Tests and CI](#11-tests-and-ci)
12. [Migration record (v0.7.0)](#12-migration-record-v070)
13. [How the roadmap plugs in](#13-how-the-roadmap-plugs-in)
14. [Decisions to confirm](#14-decisions-to-confirm)
15. [Findings to fix outside v0.7.0](#15-findings-to-fix-outside-v070)

---

## 1. Goals

**What v0.7.0 must deliver**

1. **Adding a feature means adding files, not editing the framework.** A new dashboard page, popup, bar widget, Quick Settings tile, config tab, keybind action or notch item is a new folder plus **one line in a registry**. Today a new dashboard page touches 5 files (§2.3).
2. **Every side effect goes through one gateway.** All external commands run through `Exec` (argument lists, no shell strings built from data). All user-data files go through `JsonStore`. All Hyprland calls go through `Hypr`.
3. **Views only show state and send intents.** No `Process`, no file I/O and no output parsing in a view.
4. **One way to do each thing.** One singleton registry, one import style, one persistence pattern, one polling pattern, one popup lifecycle, one dialog mechanism.
5. **The roadmap fits without another refactor.** Scaling and fonts (v0.8.0), Bar & Layout (v0.9.0), theming (F3a/F3b/F17/F27), media (F6/F13/F14), hover popups (F12), the `synapse` CLI (#89) and Notion sync (#109) each land on an extension point that already exists (§13).
6. **The rules are checked in CI**, so the structure doesn't decay again.

**Constraints**

- **No visible change** in v0.7.0. Every PR is a move, an extraction or a replacement with identical behaviour. The safety net (§11) proves it.
- **User data keeps its format.** `shell_prefs.json`, `tasks.json`, `keybinds.json`, `wallpaper.json`, `app_pins.json`, `clipboard_pins.json`, `hotspot.json`, `screenrec.json` and `colors.json` are read as they are today. Any format change goes through a store migration (§5.4).
- **IPC targets don't change.** Users' generated `SynapseKeybinds.lua` calls `qs ipc call <target> toggle`, and `keybinds.json` is keyed by those names.
- Quickshell 0.3.2. Everything below was checked against it where marked _(verified)_.

**Out of scope for v0.7.0** (they get the hooks, not the work): content scaling and the font set (v0.8.0), new features, the Layout & Behavior tab.

---

## 2. Where we are after v0.6.1

### 2.1 What is already right

The **runtime** design is sound and stays:

- One `DynamicSurface` per screen draws the whole frame as a single path (`surfacePath.js`, unit-tested) and hosts every popup in a **region**.
- `SurfaceState` holds the single open popup; `Popups` is the API the rest of the code uses.
- One `IpcManager` owns every `IpcHandler`, so one handler reacts per signal.
- `PrefsService` with a debounced, watched `FileView`.
- v0.6.0 already split the monoliths into services plus view components (#73).

### 2.2 What is wrong (measured on `dev`, 2026-11-13)

| Area | Today | Why it matters |
|---|---|---|
| **Folders** | 32 of the 63 QML files under `services/` are views (`KanbanBoard`, `AudioControl`, `PowerMenu`, `AppLauncher`, `NotificationList`, `config_tab/*Page`, `home/*Card`, `kanban/*`, `SystemStats`, `EnvyControl`, `BatteryStatus`). The dashboard is spread over `popups/`, `services/home/`, `services/config_tab/`, `services/kanban/` and `modules/Center/`. | Folder names don't say what is inside; nobody can tell where a new file goes. |
| **Singleton registry** | Three `qmldir`s (`src/`, `services/`, `theme/`). `ScreenRecService` and `Theme` are declared twice. Roots mix `Singleton {}` and `QtObject {}`, versions mix `1.0` and none. | Adding a singleton means knowing which qmldir; duplicates are fragile. |
| **Imports** | 237 relative `import "../…"` lines. Folders listed only in a `qmldir` are not scanned (the trap documented in `CLAUDE.md`). | Every move breaks imports; the scanning trap breaks at runtime only. |
| **Processes** | 152 `Process` objects in 41 files; 92 `bash -c` strings built by concatenation. 7 views still run their own process (`PowerMenu`, `ConfirmDialog`, `AppLauncher`, `ProfileCard`, `LayoutDisplayer`, `HistoryTab`, `EnvyControl`). The `running = false; running = true` restart idiom everywhere. | Untestable, inconsistent error handling, and **a shell-injection bug** (§15, F-1). |
| **Persistence** | 9 user-data files, **4 different ways**: `FileView` + `JsonAdapter` (prefs), `FileView` + manual parse (colors, keybind defaults, screenrec), `cat` in a `Process` + `printf '%s' … >` (tasks, pins, clipboard pins, keybinds, hotspot, wallpaper), and an installer-written file watched in `ShellState`. None writes atomically. | A crash during a write truncates the file; each store re-implements load-before-save guards. |
| **Polling** | Each service decides when to poll: some always (Wi-Fi, toggles every 5 s), some on `Popups.xxxOpen` (`VpnService`, `ClipboardService`, `EnvyControlService` read UI state), some on an `active` flag set by the view (`DashStats` instantiates 9 system services **per screen**). | Services depend on UI state (wrong direction), polling is duplicated per screen. |
| **Extension points** | Dashboard tabs, config tabs, bar widgets, Quick Settings tiles, notch carousel items, IPC handlers and popup specs are all hard-coded lists inside views. | See §2.3. |
| **Popup lifecycle** | "Popup opened/closed" is detected in 7 files with `Connections { onXxxOpenChanged }` (plus `WallpaperContent.onOpenChanged` and `ConfirmDialog`), and an `afterClose` timer in `SurfacePopupHost`. Popup sizes live in `DynamicSurface.contents`, regions in `SurfaceState.regionOf`, page widths in `Popups`. | One popup = 3 files to keep in sync. |
| **Dialogs** | `Popups` holds the confirm dialog's and the battery dialog's state; the confirm dialog dispatches on an action **string** (`confirmAction` switch) and runs the commands itself. | String dispatch, a view running privileged commands. |
| **Theme** | `Theme` re-binds ~60 properties of `Colors` and `Metrics` one by one. Views use 648 `Qt.rgba(…)` and 80 hex literals, 349 literal font sizes, 323 literal durations, 33 `font.family` strings. Most colours are white with an alpha (`Qt.rgba(1,1,1,0.07)`). | Scaling (v0.8.0), fonts (#102), light mode (F17), presets (F3a) and the animation engine (F3d) all need tokens; white-with-alpha breaks in light mode. |
| **`ShellState`** | Four flags, plus the Hyprland submap controller for keybind capture and the `config_Provider.json` watcher. | Mixed responsibilities; Hyprland calls outside a gateway. |
| **Size** | Still over 380 lines: `PlayerCard` 500, `DynamicSurface` 488, `AppLauncher` 465, `UpdatePopup` 458, `ScreenRecService` 456, `HistoryTab` 442, `UpdateService` 400, `KeybindService` 399, `KanbanDatePicker` 394, `AudioControl` 393, `ConfirmDialog` 383. | Hard to review and to scale area by area. |

### 2.3 The cost of a new feature today

Adding a sixth dashboard page ("Calendar") means editing:

1. `popups/DashboardContent.qml`: the tab model and a new `Item { visible: page === … }` block.
2. `state/Popups.qml`: `_dashboardPageWidths`.
3. `state/IpcManager.qml`: a new `IpcHandler`.
4. `config/keybind-defaults.json`: the default bind (it must match the handler's target; nothing checks it).
5. `services/config_tab/GeneralPage.qml`: the "default dashboard page" dropdown options.

…and remembering the folder-scanning trap if the page has its own subfolder. The same holds for popups (3 files), config tabs, bar widgets and tiles. **Goal 1 removes this.**

---

## 3. Principles

These are the rules every PR is reviewed against.

1. **Unidirectional data flow.** State flows down through bindings; intents flow up through function calls and signals. A view never writes a service's property directly: it calls a function (`WifiService.connect(ssid)`), and the service updates its state, which the view sees through the binding.
2. **Layers with a dependency rule** (§4). A layer may only import the layers below it. In particular, services never depend on UI state, and shared components never depend on services.
3. **Single source of truth.** Each fact lives in exactly one place: a popup's region, size and focus target in its `PopupSpec`; a page's label, icon and width in its `PageSpec`; a pref's default, type and allowed values in the pref schema.
4. **Side effects live at the edges.** Only `core/` gateways (`Exec`, `JsonStore`, `Hypr`) touch the system. Services orchestrate them; parsers are pure JavaScript functions, unit-tested under node.
5. **Open for extension, closed for modification.** Extension points are registries (§5.7). Adding an entry never requires editing the code that consumes the registry.
6. **Composition over inheritance.** Small components with explicit inputs (`required property`) and outputs (signals). Inheritance only for true "is a" (`StatCard`).
7. **Explicit lifecycles.** Popups have phases with signals (§5.8); services poll only while something leases them (§5.5). No component guesses from a boolean changing.
8. **Fail safe.** A missing or broken file gives defaults and never overwrites good data; a failed command reports an error state instead of leaving a spinner.
9. **No visible change during a refactor.** Behaviour changes go in their own PRs.

---

## 4. Layers and the dependency rule

```
                    ┌──────────────────────────────────────────────┐
  composition root  │ shell.qml → app/  (boots services, registers │
                    │ popups, actions; hands them to the surface)  │
                    └───────────────┬──────────────────────────────┘
                                    │ imports everything below
   ┌────────────────────────────────┼──────────────────────────────────┐
   │ surface/   dialogs/            │   features/<feature>/            │  views
   │ (frame engine, hosts)          │   (containers + feature parts)   │
   └──────────────┬─────────────────┴─────────────┬────────────────────┘
                  │                               │
                  ▼                               ▼
          ┌──────────────┐               ┌─────────────────┐
          │ components/  │◄──────────────│ state/ actions/ │  UI state, commands
          │ (pure UI)    │               └────────┬────────┘
          └──────┬───────┘                        │
                 │                                ▼
                 │                       ┌─────────────────┐
                 │                       │ services/       │  domain (non-visual)
                 │                       └────────┬────────┘
                 ▼                                ▼
          ┌──────────────────────────────────────────────────┐
          │ theme/                        core/              │  foundation
          │ (tokens)                      (Exec, JsonStore,  │
          │                               Hypr, Paths, …)    │
          └──────────────────────────────────────────────────┘
```

| Layer | Folder | Contains | May import | Must not |
|---|---|---|---|---|
| Foundation | `core/` | Infrastructure singletons and components: `Paths`, `Exec`, `ExecQueue`, `JsonStore`, `Poller`, `Lease`, `Hypr`, `Log`; pure JS helpers | Quickshell, Qt | anything in `src/` except other `core/` |
| Foundation | `theme/` | Design tokens and the colour source | `core/` | services, state, views |
| Domain | `services/<domain>/` | Non-visual singletons, one per external system or data set. State as properties, intents as functions, events as signals. Pure parsers in `*.js` next to them | `core/`, `theme/` (rarely), other services | `state/`, `actions/`, any visual item, `Popups`, `SurfaceState` |
| UI state | `state/` | `SurfaceState` (popup state machine), `Popups` (facade), `Dialogs`, `ToastState`, `ShellModes` | `core/`, `services/` | views |
| Commands | `actions/` | `Actions` registry, `IpcBridge` | `state/`, `services/`, `core/` | views |
| Pure UI | `components/` | Presentational widgets: inputs as properties, outputs as signals | `theme/`, `core/js` helpers | `services/`, `state/`, `actions/`, `features/` |
| Views | `features/<feature>/` | Containers (bind to services/state, call intents) and feature-local parts | everything below, other features only through registries | `Process`, `FileView`, `Socket`, output parsing |
| Hosts | `surface/`, `dialogs/` | The per-screen windows and the frame engine | everything below; features only through the registries `app/` hands in | `Process`, `FileView`; importing a feature folder directly |
| Root | `app/`, `shell.qml` | Composition root: registries' contents, eager boot list | everything | logic of its own |

**Why `surface/` must not import features:** the frame engine is a framework. If it imports `DashboardContent`, every new popup edits the surface. Instead, `app/Popups.qml` (the popup manifest) imports the features and the surface reads the manifest (dependency inversion).

---

## 5. Design patterns

Each section: the problem in Synapse, the pattern, how it looks in QML.

### 5.1 Service as Model, bindings as Observer

**Problem:** services already exist, but their shape varies (some expose `running` processes, some mutate from views, some read `Popups`).

**Pattern:** a **service** is a non-visual singleton that owns one external system or data set. It is the *Model* (and the *ViewModel* where the view needs derived state) of MVVM; QML property bindings are the *Observer*.

Shape of every service:

```qml
pragma Singleton
import QtQuick
import Quickshell
import qs.src.core

// WifiService — Wi-Fi radio, active network and scan list through nmcli.
Singleton {
    id: root

    // ── State (read-only to views) ──────────────────────────────────────────
    readonly property bool   radioOn:  _radioOn
    readonly property string ssid:     _ssid
    readonly property var    networks: _networks          // [{ ssid, signal, secured, inUse }]
    readonly property bool   busy:     connectExec.busy

    // ── Intents ─────────────────────────────────────────────────────────────
    function setRadio(on: bool) { … }
    function connect(ssid: string) { … }

    // ── Events ──────────────────────────────────────────────────────────────
    signal connectFailed(string ssid, string reason)

    // ── Implementation ──────────────────────────────────────────────────────
    property bool _radioOn: false
    …
}
```

Rules:
- Public state is `readonly property` backed by a private `_` property, so only the service writes it (enforced by convention and review; QML has no private).
- Intents are functions named with verbs; long operations expose `busy` and end with a signal.
- Derived state (`limited`, `available`) is a `readonly property` binding, not a function the view calls.
- A service never reads `Popups`, `SurfaceState` or any view. When it should only work while something is shown, it uses a **lease** (§5.5).

### 5.2 Container / Presentational components (props down, events up)

**Problem:** `components/` contains widgets that read services directly (`WifiNetworkRow` → `WifiService`, `BrightnessSlider` → `BrightnessService`, `Settings*` → `PrefsService`, `ToastCard` → `ToastState`). They can't be reused or tested alone.

**Pattern:** split UI into
- **presentational components** (`components/`): look only, inputs as properties, outputs as signals, no singleton except `Theme`;
- **containers** (`features/`): bind presentational components to services and turn their signals into intents.

```qml
// components/inputs/IconSlider.qml — presentational
Item {
    required property real value        // 0..1
    property string icon: ""
    signal moved(real value)
    …
}

// features/osd/BrightnessControl.qml — container
IconSlider {
    value: BrightnessService.level
    icon:  "󰃠"
    onMoved: v => BrightnessService.setLevel(v)
}
```

A widget that only makes sense with one service (e.g. `WifiNetworkRow`) moves into the feature folder instead (`features/network/wifi/WifiNetworkRow.qml`): it is a feature part, not a shared component.

### 5.3 Gateway / Adapter: `Exec` and `Hypr`

**Problem:** 152 `Process` objects, 92 `bash -c` strings built by concatenation, the restart idiom, ad-hoc stdout collection, and a shell-injection bug with Wi-Fi SSIDs (F-1).

**Pattern:** one **gateway** for external commands, used by every service:

```qml
// in a service
Exec {
    id: scanExec
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list",
              "--rescan", root._rescan ? "yes" : "no"]
    parse: Nmcli.parseWifiList                      // pure JS, unit-tested
    onSucceeded: result => root._networks = result
    onFailed: (code, stderr) => root._networks = []
}

function scan(rescan: bool) { _rescan = rescan; scanExec.run() }
```

- `command` is always an **argument list**; data is never concatenated into a shell string. A pipeline that needs a shell passes data as positional arguments: `["bash", "-c", "nmcli con up id \"$1\" || nmcli dev wifi connect \"$1\"", "_", ssid]`.
- `run()` restarts cleanly (no `running = false; running = true`), `busy` is bindable, `succeeded(result)` / `failed(code, stderr)` replace ad-hoc `onExited` handlers.
- `ExecQueue` runs commands one at a time (what `DataService._run` and `ClipboardService._pinQueue` do by hand).
- **`Hypr`** (`core/Hypr.qml`) is the gateway for Hyprland: `dispatch(…)`, `eval(lua)`, `setOption(…)`, `submap(name)`, `reload()`, `refresh()`. It is also a **Strategy** over the config provider (`lua` vs `conf`, today in `ShellState`), so `FocusModeService`, `AppearanceService`, `KeybindService` and the keybind capture submap never build `hyprctl` lines themselves. Events (`rawEvent`) stay on `Quickshell.Hyprland`.

### 5.4 Repository: `JsonStore`

**Problem:** 9 user-data files, 4 persistence styles, no atomic writes, load-before-save guards re-implemented in each service.

**Pattern:** a **repository** component that owns one JSON document:

```qml
// services/data/TaskService.qml
JsonStore {
    id: store
    path:     Paths.userData("tasks.json")
    defaults: ({ tasks: [], nextId: 0 })
    version:  1
    migrate:  (doc, from) => doc            // no migration yet
}

readonly property var tasks: store.data.tasks

function addTask(column, title) {
    store.update(d => {
        d.tasks.unshift({ id: d.nextId++, title, column, urgency: "", dueDate: "" })
    })
}
```

- Built on `FileView` with `atomicWrites: true` and `setText()` _(verified on 0.3.2)_, so a crash never leaves a half-written file, and no `printf` process is needed.
- **Never saves before the first load finished**; a parse error keeps the file untouched, uses `defaults`, and sets `error` (so a broken file isn't overwritten with an empty one).
- `update(mutator)` copies, mutates, reassigns (so bindings fire) and schedules a debounced save; `flush()` saves now (factory reset, exit).
- `version` + `migrate(doc, fromVersion)` for format changes. The version is stored as `_version` only once a migration exists, so today's files stay byte-compatible.
- `watch: true` reloads on external edits (prefs, colors).
- `clear()` writes the defaults (what `KanbanService.clear()` does with a process today).

Every store in the shell uses it: prefs, tasks, app pins, clipboard pins, keybinds, hotspot, screen recording, wallpaper, colors (read-only), config provider (read-only).

### 5.5 Demand-driven polling: `Poller` + `Lease` (reference counting)

**Problem:** services poll on their own rules; some read `Popups.networkOpen`; `DashStats` creates 9 service instances per screen and gates them with `active: root.visible`.

**Pattern:** **reference-counted subscriptions**. A service declares what it polls and how often; views that need fresh data hold a **lease** while they are visible.

```qml
// service
Singleton {
    readonly property bool watched: _leases > 0
    property int _leases: 0
    function acquire() { _leases++ }
    function release() { _leases = Math.max(0, _leases - 1) }

    Poller { interval: 2000; running: root.watched; onTick: statExec.run() }
}

// view
Lease { service: CpuService; active: root.visible }
```

- `Lease` acquires when `active` becomes true and releases when it becomes false or the view is destroyed, so counts can't leak.
- Services that the bar always shows (Wi-Fi status, battery, toggles) poll unconditionally at their slow rate and add a fast rate while leased (`Poller { interval: watched ? 2000 : 5000 }`).
- All system services become singletons: one poll for the whole shell, whatever the number of screens.
- `Lease` lives in `core/` and knows nothing about popups, so services stay below the UI layer.

### 5.6 Command pattern: the `Actions` registry

**Problem:** the same action ("open the dashboard on Tasks") is written in `IpcManager`, `keybind-defaults.json`, bar buttons and tiles; nothing checks that the keybind keys match the IPC targets.

**Pattern:** every user-triggerable action is a **command** object in one registry:

```qml
Action {
    key:   "dashboard-kanban"           // = IPC target = keybinds.json key (unchanged)
    label: "Dashboard: Tasks"
    group: "Dashboard"
    run:   () => Popups.togglePage("dashboard", "kanban")
}
```

- `Actions.run(key)` is what IPC, keybinds, bar buttons, tiles and the future `synapse` CLI (#89) call.
- **`IpcBridge`** creates one `IpcHandler { target: key; function toggle() }` per action from the registry with an `Instantiator` _(verified on 0.3.2 in #141: `qs ipc call <target> toggle` reaches handlers created this way; the delegate's `modelData` shows up in `qs ipc show`, harmless)_.
- `config/keybind-defaults.json` stays the source of the **default binds** (the installer's conflict check reads it), but labels and groups come from the registry, and a contract test (§11) fails if the two key sets differ.
- Actions derived from other registries are generated: each dashboard page, audio page and network tab produces its `…-toggle` action automatically.

### 5.7 Registries: the extension points (Open/Closed)

**Problem:** §2.3.

**Pattern:** a **registry** (also called a plugin or contribution point) is an ordered list of **spec objects** declared in one manifest file. Consumers iterate the registry; adding a feature adds one entry. QML can't discover files on disk, so the manifest is the one line each feature adds.

| Registry | Manifest | Spec | Consumers |
|---|---|---|---|
| Popups | `app/PopupManifest.qml` | `PopupSpec { key, region, component, size(s), place(s, w, h), focus(item), onClosed(item), pages }` | `SurfaceState` (regions), `SurfacePopupHost`, `Actions` (toggle actions) |
| Dashboard pages | `features/dashboard/DashboardPages.qml` | `PageSpec { key, label, icon, width, component, keybind }` | dashboard tab bar and page stack, `Popups` page widths, `Actions`, Config → General "default page" options |
| Audio pages, network tabs | `features/audio/AudioPages.qml`, `features/network/NetworkTabs.qml` | `PageSpec` | their popup, `Actions` |
| Config tabs | `features/config/ConfigTabs.qml` | `TabSpec { key, label, icon, component }` | `ShellConfig` |
| Bar widgets | `features/bar/BarWidgets.qml` | `BarWidgetSpec { key, label, zone, component, visible }` | `SurfaceBar` (per-zone list from `Prefs.barLayout`, default = today's order), Layout & Behavior tab (#23) |
| Quick Settings tiles | `features/dashboard/home/QuickTiles.qml` | `TileSpec { key, label, icon, on, sublabel, busy, toggle(), secondary(), indicator }` | `QuickSettings` grid, bar indicators (#24) |
| Notch carousel items | `features/bar/center/NotchItems.qml` | `NotchItemSpec { key, active, priority, autoScroll, component }` | `CenterContent` (replaces `_rebuildItems`) |
| Actions | `actions/ActionManifest.qml` (+ generated) | `Action { key, label, group, run }` | `IpcBridge`, keybind page, CLI |
| Pref schema | `services/data/PrefSchema.qml` | `{ default, type, options \| min/max, label }` per key | `Prefs` (validation), config controls (§5.12) |

The spec types live in `core/specs/` (plain `QtObject`s with typed properties), so a registry is type-checked by the QML engine and the smoke test can iterate every entry.

### 5.8 State machine: the popup lifecycle

**Problem:** "popup opened/closed" is inferred in 7 files from `xxxOpen` booleans; the "after the close animation" moment is a timer inside `SurfacePopupHost`; v0.6.1's reset had to find the right hook by hand.

**Pattern:** `SurfaceState` becomes an explicit **state machine** per screen with four phases and transition signals:

```
          open()                animation done
 closed ─────────► opening ─────────────────────► open
   ▲                                                │ close() / another popup / Escape /
   │ animation done                                 │ click outside / workspace change
   └──────────────── closing ◄──────────────────────┘
```

- `SurfaceState.phaseOf(key)`, signals `opening(key, screen)`, `opened(key, screen)`, `closing(key, screen)`, `closed(key, screen)`.
- Views react with a declarative helper instead of `Connections` on booleans:

```qml
PopupLifecycle {
    popup: "dashboard"
    onOpened: searchField.forceActiveFocus()
    onClosed: board.reset()          // after the close animation
}
```

- The spec's `focus(item)` runs on `opened`, `onClosed(item)` on `closed`; the `afterClose` timer and those `Connections` disappear.
- `Popups` stays as the **facade** (`open`, `close`, `toggle`, `togglePage`, `isOpen`) so feature code doesn't change shape.

### 5.9 Facade

`Popups` (over `SurfaceState` + page state), `Theme` (over the token groups) and `Actions` (over the registry) are **facades**: the one import a view needs. Their internals can change without touching views.

### 5.10 Mediator: `Dialogs`

**Problem:** `Popups` holds the confirm and battery dialogs' state; `ConfirmDialog` switches on an action string and runs `pkexec`/`reboot` itself.

**Pattern:** a **mediator** for modal requests:

```qml
Dialogs.confirm({
    title:   "Switch to hybrid graphics?",
    message: "The session restarts.",
    label:   "Switch and reboot",
    destructive: true,
    onAccept: () => GpuModeService.switchTo("hybrid")    // the service does the work
})
```

- `Dialogs` (in `state/`) queues requests; `dialogs/ConfirmDialog.qml` only renders the current one and reports the choice; the action runs in a service (`PowerService`, `GpuModeService`), which exposes `busy` for the "Processing…" card.
- The critical-battery dialog becomes `Dialogs.alert(…)` raised by `BatteryWarningService`'s event, not by the service touching UI state.
- The in-popup confirmations (task delete / clear, from v0.6.1) use the same presentational `ConfirmOverlay` component.

### 5.11 Strategy

Interchangeable algorithms behind one interface:

| Strategy | Interface | Implementations | When |
|---|---|---|---|
| Frame style | `surfacePath.build(style, geometry)` | frame, bar, pills | today (keep) |
| Hyprland config provider | `Hypr.submap()`, `Hypr.setOption()` | lua, conf | v0.7.0 (from `ShellState`) |
| Colour source | `ColorSource { roles }` | matugen (`colors.json`), preset (F3a), override (F3b) | v0.7.0 interface, matugen only |
| Recorder backend | `RecorderBackend { command(opts), supports }` | wf-recorder; gpu-screen-recorder, wl-screenrec (F14) | v0.7.0 interface, wf-recorder only |
| Task sync | `TaskSync { pull(), push(changes) }` | none; Notion (#109) | interface when #109 starts |

A strategy is a small QML object chosen by a pref, so adding an implementation never edits the service using it.

### 5.12 Design tokens

**Problem:** §2.2 "Theme". v0.8.0 (scaling, fonts), F3a/F3b/F17 (themes, light mode) and F3d (animation engine) all need named values; today `Theme` mirrors `Metrics` and `Colors` by hand.

**Pattern:** **design tokens** in groups, behind the `Theme` facade:

| Group | Examples | Replaces | Fed by |
|---|---|---|---|
| `Theme.color` | `background`, `surface`, `surfaceRaised`, `accent`, `text`, `textMuted`, `border`, `danger`, `warning`, `success`; **state layers** `hairline`, `fillSubtle`, `fillHover`, `fillPressed`; `scrim` (fixed black); `alpha(c, a)` | `Colors`, the 648 `Qt.rgba(1,1,1,a)` | `ColorSource` (§5.11) |
| `Theme.font` | families `ui`, `mono`, `icon`; sizes `caption` 9, `small` 10, `body` 11, `bodyLarge` 12, `title` 13, `display` …; weights | 349 `pixelSize`, 33 `font.family` | #104 (families), #79 (scale) |
| `Theme.space` | `xxs` 2, `xs` 4, `sm` 6, `md` 8, `lg` 12, `xl` 16, `xxl` 24 | literal margins/spacings | #79 |
| `Theme.radius` | `sm` 4, `md` 6, `lg` 8, `card` (= corner pref), `notch` | `cornerRadius`, literals | prefs |
| `Theme.motion` | durations `instant` 80, `fast` 150, `normal` 200, `slow` 320; curves `standard`, `emphasized`, `overshoot`; `Anim` / `Fade` components | 323 literal durations, `animDuration` | F3d (speed, style) |
| `Theme.frame` | frame and region sizes (today's `Metrics`), `barStyle`, `borderWidth`, `opacity` | `Metrics` | prefs |

- "State layers" are colours of the **foreground** with a fixed alpha (`Theme.color.alpha(Theme.color.text, 0.07)`), not white, so light mode (F17) works without touching views.
- v0.7.0 creates the token API **with today's values** and renames the existing `Theme.*` reads; replacing the remaining literals is decision D1 (§14).

**Literal → token mapping for the D1 passes** (v0.8.0, #80–#84). The state layers are the foreground (`text`, `#cdd6f4` by default) rather than white, so a pass that applies them shifts those pixels slightly and is labelled `visual-change`.

| Literal in a view | Token |
|---|---|
| `Qt.rgba(1,1,1,0.04)` | `Theme.color.fillSubtle` |
| `Qt.rgba(1,1,1,0.05)` (card fill) | `Theme.color.surfaceRaised` |
| `Qt.rgba(1,1,1,0.07)` (separator, outline) | `Theme.color.hairline` |
| `Qt.rgba(1,1,1,0.08)` | `Theme.color.fillHover` |
| `Qt.rgba(1,1,1,0.12)` | `Theme.color.fillPressed` |
| any other `Qt.rgba(1,1,1,a)` | `Theme.color.alpha(Theme.color.text, a)` |
| `Qt.rgba(Theme.color.accent.r, …g, …b, a)` | `Theme.color.alpha(Theme.color.accent, a)` |
| `"#99000000"`, dark overlays | `Theme.color.scrim` |
| `"#f87171"`, `"#ff4444"`, `"#cc3a3a"`, `"#f38ba8"`, `"#e06c75"` | `Theme.color.danger` |
| `"#f5c47a"`, `"#ffcc00"` | `Theme.color.warning` |
| `"#a6e3a1"` | `Theme.color.success` |
| `pixelSize` 9 / 10 / 11 / 12 / 13 / 15 / 32 | `Theme.font.caption` / `small` / `body` / `bodyLarge` / `title` / `heading` / `display` |
| `"JetBrainsMono Nerd Font"` / `"monospace"` | `Theme.font.icon` / `Theme.font.mono` |
| `Font.Medium`, `Font.DemiBold`, `Font.Bold` | `Theme.font.medium` / `semibold` / `bold` |
| spacing / margin 2, 4, 6, 8, 12, 16, 24 | `Theme.space.xxs` … `xxl` |
| `radius` 4 / 6 / 8 | `Theme.radius.sm` / `md` / `lg` |
| `duration` 80 / 100–160 / 200 / 320 | `Theme.motion.instant` / `fast` / `normal` / `slow` |
| `Easing.OutCubic` / `InOutCubic` / `OutBack` | `Theme.motion.standard` / `emphasized` / `overshoot` |
| `NumberAnimation { duration; easing }` | `Anim { … }`; an opacity cross-fade `Fade {}` |

Sizes in between (14, 130 ms, 10 px gaps…) snap to the nearest token in the pass, where a reviewer looks at the result.

### 5.13 Composition root

`shell.qml` only instantiates `app/App.qml`, which:
- lists the services that must start eagerly (today's `_keybinds`, `_updater`, … properties),
- owns the manifests that cross layers (`PopupManifest`, `ActionManifest`),
- creates `ShellHost` and hands it the popup registry.

Everything that wires features into the framework is in `app/`, so a reader finds every feature from one folder.

### 5.14 Patterns we deliberately avoid

| Avoided | Why | Instead |
|---|---|---|
| A global event bus | Hides who listens to what; QML signals are already typed and traceable | Signals on the owning service; `Actions` for commands |
| Services reading UI state | Inverts the dependency rule, makes services untestable | `Lease`, `PopupLifecycle` in the view |
| String dispatch (`switch (confirmAction)`) | Typos fail at runtime | Callbacks, `Action` objects |
| Deep inheritance of views | Fragile | Composition, `required property` |
| `bash -c` with data in the string | Injection, quoting bugs | `Exec` with argument lists |
| Mutable global "state bags" (`ShellState` today) | Unclear ownership | Each flag owned by one service or `ShellModes` |

---

## 6. Tree

```
config/quickshell/
├── shell.qml                         composition root entry: App {}
├── src/
│   ├── app/                          composition root
│   │   ├── App.qml                   eager services, ShellHost, the manifests
│   │   ├── PopupManifest.qml         every PopupSpec (imports the features), OSD,
│   │   │                             recording options
│   │   └── ActionManifest.qml        actions not derived from a registry
│   ├── core/                         foundation, no domain, no UI
│   │   ├── Paths.qml  Log.qml (S)
│   │   ├── Exec.qml  ExecQueue.qml
│   │   ├── JsonStore.qml
│   │   ├── Poller.qml  LeaseCount.qml  Lease.qml
│   │   ├── Hypr.qml (S)  hypr.js        hyprctl gateway + provider strategy
│   │   └── specs/                    PopupSpec, PageSpec, TabSpec, BarWidgetSpec,
│   │                                 TileSpec, NotchItemSpec, Action
│   ├── theme/
│   │   ├── Theme.qml (S)             facade: color, font, space, radius, motion, frame
│   │   ├── Anim.qml  Fade.qml        motion components
│   │   ├── tokens/                   ColorTokens, FontTokens, SpaceTokens, RadiusTokens,
│   │   │                             MotionTokens, FrameTokens
│   │   └── sources/                  ColorSource, MatugenSource
│   ├── services/                     non-visual singletons only (+ pure .js)
│   │   ├── system/                   Cpu, CpuFreq, Mem, Gpu, GpuMode, Disk, Thermal,
│   │   │                             FanControl, Net, Battery, BatteryWarning,
│   │   │                             Brightness, Power, Update, SystemInfo;
│   │   │                             sysinfo.js, update.js
│   │   ├── network/                  Wifi, Bluetooth, Vpn, Hotspot; nmcli.js
│   │   ├── media/                    Audio, Media (MPRIS), Cava, ScreenRec,
│   │   │                             ScreenFilter; screenrec.js;
│   │   │                             recorders/ (RecorderBackend, WfRecorder)
│   │   ├── desktop/                  ActiveWindow, KeyboardLayout, FocusMode,
│   │   │                             Appearance, Keybind, QuickToggle, Apps, AppPin,
│   │   │                             Wallpaper, Profile; keybindLua.js, profile.js
│   │   ├── data/                     Prefs, PrefSchema, Task, Clipboard, Data;
│   │   │                             cliphist.js
│   │   ├── notifications/            Notification (server)
│   │   └── time/                     Clock
│   ├── state/                        UI state, no side effects
│   │   ├── SurfaceState.qml (S)      popup state machine
│   │   ├── Popups.qml (S)            facade + page state
│   │   ├── PopupLifecycle.qml        helper component
│   │   ├── Dialogs.qml (S)           modal request mediator
│   │   ├── ToastState.qml (S)
│   │   └── ShellModes.qml (S)        focusMode, dnd, screenRecord, airplane mirror
│   ├── actions/
│   │   ├── Actions.qml (S)           registry + run(key)
│   │   └── IpcBridge.qml (S)         IpcHandlers from the registry
│   ├── components/                   presentational only
│   │   ├── base/                     IconBtn, ActionBtn, PillButton, StatCard, StatRow,
│   │   │                             TabSwitcher, PageStack, PopupPage, ProfileButton,
│   │   │                             QuickToggleTile, Speedometer, DiskBar
│   │   ├── inputs/                   BrightnessSlider, TimeInput
│   │   ├── feedback/                 ConfirmOverlay, ToastCard
│   │   └── settings/                 SettingsGroup, SettingsRow, SettingsToggle,
│   │                                 SettingsSlider, SettingsDropdown, SettingsTextField,
│   │                                 SettingsButton, SettingsDivider
│   ├── features/                     views, one folder per feature
│   │   ├── bar/
│   │   │   ├── BarWidgets.qml        registry manifest
│   │   │   ├── left/                 PowerButton, Workspaces, LayoutIndicator
│   │   │   ├── center/               CenterContent, NotchItems.qml, Notch*Item,
│   │   │   │                         Notch*Button, CavaBars
│   │   │   └── right/                NetworkIndicator, AudioIndicator, BatteryIndicator,
│   │   │                             BatteryStatus, Clock, SysTray, NotificationsButton
│   │   ├── dashboard/
│   │   │   ├── DashboardPopup.qml    PopupSpec
│   │   │   ├── DashboardContent.qml
│   │   │   ├── DashboardPages.qml    registry manifest
│   │   │   ├── home/                 HomePage, ProfileCard, CalendarCard, ClockCard,
│   │   │   │                         clock/, PlayerCard (+ PlayerArt, PlayerProgress,
│   │   │   │                         PlayerSourcePicker, player.js), QuickSettings,
│   │   │   │                         QuickTiles.qml, QuickFilterPicker
│   │   │   ├── system/               SystemPage, SystemStats, Disk/Fan/NetStats/
│   │   │   │                         Power/Temp panels
│   │   │   ├── tasks/                TaskBoard, TaskColumn, TaskCard, TaskExtraFields,
│   │   │   │                         TaskKeyHints, TaskDatePicker, TaskCalendar,
│   │   │   │                         TimeSpinner
│   │   │   ├── apps/                 AppLauncher, AppTile, AppSearchBar
│   │   │   └── config/               ShellConfig, ConfigTabs.qml, pages/, controls/
│   │   ├── network/                  NetworkPopup, NetworkContent, NetworkTabs.qml,
│   │   │                             Wifi/Bluetooth/VPN/Hotspot tabs and rows (flat)
│   │   ├── audio/                    AudioPopup, AudioControl, AudioPages.qml,
│   │   │                             OutputPage, InputPage, MixerPage (+ parts)
│   │   ├── notifications/            NotificationsPopup, NotificationList, NotificationCard
│   │   ├── clipboard/                ClipboardPopup, HistoryTab, ClipRow
│   │   ├── wallpaper/                WallpaperPopup, WallpaperContent (+ parts)
│   │   ├── power/                    PowerPopup, PowerMenu
│   │   ├── osd/                      QuickControlContent
│   │   └── screenrec/                ScreenRecOptions
│   ├── surface/                      frame engine, feature-agnostic
│   │   ├── ShellHost.qml  DynamicSurface.qml  StrutWindow.qml
│   │   ├── Regions.qml  BarZone.qml  SurfaceBar.qml  SurfacePopupHost.qml
│   │   ├── SurfaceTriggers.qml  SurfaceClickShield.qml  SurfaceInputMask.qml
│   │   ├── SurfaceFullscreen.qml
│   │   └── shape/                    SurfaceShape.qml, surfacePath.js
│   ├── dialogs/                      ConfirmDialog, BatteryCriticalDialog, UpdatePopup
│   │                                 (+ UpdateHeader, UpdateCommitList), PopupFocusGrab
│   ├── config/                       matugen.toml, templates/, keybind-defaults.json
│   ├── assets/                       default wallpapers
│   └── scripts/                      helper scripts
└── tests/
    ├── unit.sh  unit/                *.test.mjs for every pure JS module
    ├── smoke.sh  smoke.qml  smoke-imports.qml  smoke-registries.qml
    ├── core.qml  lifecycle.qml  prefs.qml  theme.qml   behaviour tests
    ├── contracts.qml                 registry ↔ keybind-defaults ↔ IPC checks
    ├── lib/SceneList.qml             every scene (smoke + golden)
    ├── golden.sh                     base vs head screenshots (§11)
    └── layers.py                     dependency rules and size budgets (§11)
```

Every directory is imported as `import qs.src.<path>` _(verified on 0.3.2: no `qmldir` needed, `pragma Singleton` files are singletons automatically)_. All three `qmldir` files are deleted, which also removes the folder-scanning trap: a file always imports exactly the folders it uses.

---

## 7. File map: v0.6.1 → v0.7.0

Paths relative to `config/quickshell/src/`. This is the plan's map from the v0.6.1 tree, kept as the record of the moves: "Today" is v0.6.1, "Target" the plan. "split" means the file is cut into the parts listed; "→" alone is a move (and rename where the name changes). The "Done in" notes say where the build differs; §6 is the final tree.

**Done in #117 (S12)** — `tests/layers.py` enforced in CI (exit 1 on any violation, no allowlist: `layers-allowlist.txt` deleted), size budgets as CI warnings (GitHub annotations) and failures over 500 lines, `layers.py --self-test` (one planted violation per rule, run in CI). `CLAUDE.md`'s shell section rewritten around the layers, patterns and recipes; this document turned from plan to reference.

**Done in #116 (S11)** — no file over its budget (`tests/layers.py`: views ≤ 300, services, state and pure `.js` modules ≤ 350). Services: `KeybindService` + `services/desktop/keybindLua.js` (merge, conflicts, the generated `.lua` / `.conf`, byte-identical to before), `ScreenRecService` + `services/media/recorders/` (`RecorderBackend` strategy, `WfRecorder` only) + `screenrec.js` (audio routing script, cava frames), `UpdateService` + `services/system/update.js` (the apply script and the reading of its output); each `.js` has node tests. Views: `UpdatePopup` → `UpdateHeader`, `UpdateCommitList` and the shared `components/base/PillButton`; `HistoryTab` → `ClipRow`; `AppLauncher` → `AppTile`, `AppSearchBar`; `PlayerCard` → `PlayerArt`, `PlayerProgress`, `PlayerSourcePicker`, `player.js`; `TaskDatePicker` → `TaskCalendar`, `TimeSpinner`; `TaskBoard` → `TaskKeyHints`; `TaskCard` → `TaskExtraFields`; `KeybindRow` → `KeybindPill`, `KeybindIconBtn`; `NotificationList` → `NotificationCard`; `DynamicSurface` → `SurfaceFullscreen`. `ConfirmDialog` and `AudioControl` were already under budget. New golden scenes for parts that only show with data: `player-card`, `task-date-picker`, `app-tile`, `clip-row`, `update-header`.

**Done in #147 (S10)** — design tokens behind the `Theme` facade (§5.12): `theme/tokens/{Color,Font,Space,Radius,Motion,Frame}Tokens.qml` (plain `QtObject`s instantiated by `Theme`; `FrameTokens` is the old `Metrics`, minus the radii and durations), `theme/sources/ColorSource.qml` + `MatugenSource.qml` (the old `ColorLoader`, on a read-only, watched `JsonStore`; only the keys present in `colors.json` replace a colour, so a broken or half-written file keeps the palette), `theme/Anim.qml` / `Fade.qml`. `Metrics`, `Colors` and `ColorLoader` are deleted and every flat `Theme.*` read renamed (no alias kept): `Theme.active` → `color.accent`, `subtext` → `color.textMuted`, `surfaceBackground` → `color.surface`, `cornerRadius` → `radius.card`, `notchRadius` → `radius.notch`, `animDuration` → `motion.slow`, `Metrics.regionFadeDuration` → `motion.fast` (`Fade`), `backgroundOpacity` → `frame.opacity`, every size → `frame.<name>`; `barEnabled` and `icon` (unused) dropped. Same values, golden identical. `scrim` is a fixed black at 60 % (the views' `"#99000000"`), not a state layer: it dims the screen in both palettes, which neither the foreground nor the background does. Test: `tests/theme.qml`.

**Done in #146 (S9)** — `services/data/Prefs.qml` on `JsonStore` (same `shell_prefs.json`, same keys; written with 4-space indent) + `PrefSchema.qml` (`{ default, type, options | min/max, strict, label, description }`); validation on read and write (the `barStyle` check left `Metrics`; numbers clamped to the settings' ranges); `Prefs.data.<key>`, `set`, `reset`, `resetAll`, `isDefault`; `PrefsService` deleted. `components/settings/Settings*` are presentational (`value`, `defaultValue`, `edited(v)`, `resetRequested()`); `features/dashboard/config/controls/Pref{Toggle,Slider,Dropdown,TextField}.qml` bind them to a schema key. `ToastCard` and `BrightnessSlider` became presentational too, so layer rule 4 (`component`) passes for all of `components/`. `JsonStore` got a `created()` signal (the legacy `update_prefs.json` carry-over uses it). Test: `tests/prefs.qml` loads an old file.

**Done in #145 (S8)** — registries everywhere (§5.6, §5.7): `actions/Actions.qml` + `actions/IpcBridge.qml` (handlers from the registry; `IpcManager` deleted) fed by `app/ActionManifest.qml` (popup and page toggles generated from the specs: `PopupSpec.action`/`actionGroup`, `PageSpec.action`); `DashboardPages`, `AudioPages`, `NetworkTabs` (`PageSpec`; tab bars, `components/base/PageStack.qml`, popup widths — `Popups`' widths and `Metrics.audioPageWidths` are gone —, Config → General's options), `ConfigTabs` (`TabSpec`), `QuickTiles` (`TileSpec`), `BarWidgets` (`BarWidgetSpec`, laid out by `surface/BarZone.qml`; `LeftContent`/`RightContent` deleted; pref `barLayout`, `{}` = every zone in `defaultOrder`, i.e. today's), `NotchItems` (`NotchItemSpec`; `CenterContent._rebuildItems` reads it). The surface now imports no feature at all (layer rule `host` clean). `AudioControl` was split into `OutputPage`, `InputPage`, `MixerPage`, `ChannelColumn`, `SectionLabel`, `DeviceRow`. Differences from the plan: registries are plain `QtObject`s instantiated by their readers, not singletons (a component declared in a singleton outlives its context at shutdown and its bindings fail); keybind labels and groups still come from `keybind-defaults.json` (the keybinds page is unchanged), the registry's labels are for the CLI (#89); `quickcontrols-show` stays an `IpcBridge` handler, not an action. Tests: scenes and contracts generated from the registries.

**Done in #144 (S7)** — popups are a registry: `core/specs/PopupSpec.qml`, one `<Feature>Popup.qml` per popup, `app/PopupManifest.qml` (which also hands the surface its passive parts, the OSD and the recording options, so `DynamicSurface` imports no feature). `DynamicSurface.contents` and `SurfaceState.regionOf`'s literal map are gone (derived from the manifest); region geometry is `surface/Regions.qml`. `SurfaceState` is the lifecycle state machine (phases per popup and screen, `opening`/`opened`/`closing`/`closed(key, screen)`, `phaseOf`), with `state/PopupLifecycle.qml`; the `afterClose` timer and the `onXxxOpenChanged` watchers are replaced. Differences from §5.7–5.8: the spec's close hook is `afterClose(item)` (QML reserves `on…` names for handlers), its pages are `pageProp` + `defaultPagePref` (the page lists come with #145's `PageSpec`), and `focus(item)` runs on `opening` (after the 50 ms keyboard grant), not `opened`, so typing right after a keybind isn't lost during the animation. `state/Dialogs.qml` is the mediator (`confirm`, `alert`, queued); confirm and battery state left `Popups`. Tests: `tests/lifecycle.qml`; the manifest is checked by `tests/contracts.qml` and loaded by `tests/smoke-imports.qml`.

**Done in #143 (S6)** — no view, dialog or surface file runs a command any more (layer rule `io` passes outside `core/`, `services/` and the two files left for #146/#147: `PrefsService`, `ColorLoader`). New services: `system/PowerService` (lock, suspend, log out, reboot, shut down), `system/GpuModeService` (was `EnvyControlService`; also runs the pkexec switch and its reboot, `switching` drives the "Applying changes" card), `system/SystemInfoService` (fastfetch rows, leased), `desktop/AppsService` (`list_apps.py` and launching), `desktop/KeyboardLayoutService` (tiling layout of the focused workspace, `cycle()` through `Hypr`), `desktop/ProfileService` (user, desktop, leased uptime), `media/AudioService` (default sink/source and the device list, nodes tracked while leased), `media/MediaService` (allowlisted MPRIS players, the shared selection, transport intents; `firstPlayer` for the notch). `ClipboardService` decodes the image previews. `ConfirmDialog` only renders and hands the confirmed action to its service (the `Dialogs` mediator is #144). `ShellState` became `state/ShellModes.qml` (the four flags only): the keybind-capture submap is `KeybindService.setCapturing()` through `Hypr`, the provider is `Hypr.provider`. The unused `EnvyControl.qml` view was removed (`PowerPanel` is the GPU switch); `SystemStats.qml` is kept, on `SystemInfoService`. Not done here: the splits of `AudioControl`, `PlayerCard`, `AppLauncher`, `HistoryTab` (#116).

**Done in #115 (S5)** — every service except `PrefsService` (left for #146's schema) runs on `Exec` / `ExecQueue` / `JsonStore` / `Poller` / `Lease` / `Hypr`; the system stats services are leased singletons; no service reads `Popups`, `SurfaceState` or `ShellState` (the mode flags moved into their services: `FocusModeService.active`, `NotificationService.dnd`, `ScreenRecService.setupOpen`, `QuickToggleService.airplaneOn`, mirrored read-only by `ShellState`; the GPU switch prompt moved to its view; the battery dialog is wired in `app/`); `BatteryStatus` became a bar view over a new `BatteryService`; parsers in `sysinfo.js`, `nmcli.js`, `cliphist.js`.

**Done in #113 (S4)** — every move and rename below that needs no code change, with these differences from the target: `features/network/` stays flat (`NetworkContent` loads its tabs by file name; the tab subfolders come with the splits), names that change with a split keep their name until it (`AudioControl`, `HistoryTab`, `BatteryStatus`, `KanbanDeleteDialog` → `components/feedback/ConfirmOverlay`), `IpcManager` stays in `state/` until #145, `BrightnessSlider` sits in `components/inputs/` until #146 makes it presentational, and the system stats services stay per-use until #115. New: `app/App.qml` is the composition root (`shell.qml` only creates it).

### 7.1 Root, theme, utils

| Today | Target | Notes |
|---|---|---|
| `../shell.qml` | `../shell.qml` + `app/App.qml` | eager-boot list moves to `App` |
| `qmldir`, `services/qmldir`, `services/home/qmldir`, `theme/qmldir` | deleted | `qs.*` imports |
| `utils/Paths.qml` | `core/Paths.qml` | `shellQuote()` kept only for the few real scripts |
| `theme/Theme.qml` | `theme/Theme.qml` | facade over token groups |
| `theme/Metrics.qml` | `theme/tokens/FrameTokens.qml` | `barStyle` validation moves to `PrefSchema` |
| `theme/Colors.qml` | `theme/tokens/ColorTokens.qml` | adds role and state-layer tokens |
| `theme/ColorLoader.qml` | `theme/sources/MatugenSource.qml` | `JsonStore` read-only, watch |

### 7.2 State

| Today | Target | Notes |
|---|---|---|
| `state/SurfaceState.qml` | `state/SurfaceState.qml` | phases + signals; `regionOf` built from `PopupManifest`; `scaleFor` → `theme`/`surface` (decision in #79) |
| `state/Popups.qml` | `state/Popups.qml` (facade), `state/Dialogs.qml` | page widths from page registries; confirm/battery state → `Dialogs`; OSD flags stay |
| `state/IpcManager.qml` | `actions/IpcBridge.qml` + `app/ActionManifest.qml` | handlers from the registry; OSD hide timer → `features/osd` |
| `state/ShellState.qml` | `state/ShellModes.qml` | submap → `KeybindService` via `Hypr`; provider file → `Hypr` |
| `state/ToastState.qml` | `state/ToastState.qml` | unchanged |
| `state/ClockState.qml` | `services/time/ClockService.qml` | it is an engine, not UI state |

### 7.3 Services

| Today | Target | Notes |
|---|---|---|
| `services/PrefsService.qml` | `services/data/Prefs.qml` + `PrefSchema.qml` | `JsonStore` + schema (§5.12, D3) |
| `services/KanbanService.qml` | `services/data/TaskService.qml` | `JsonStore`; `clearColumn`, `clear` kept |
| `services/AppPinService.qml` | `services/desktop/AppPins.qml` | `JsonStore` |
| `services/ClipboardService.qml` | `services/data/ClipboardService.qml` | `JsonStore` for pins, `ExecQueue`, lease instead of `Popups.clipboardOpen` |
| `services/WallpaperService.qml` | `services/desktop/WallpaperService.qml` | `JsonStore`, `Exec` |
| `services/HotspotService.qml` | `services/network/HotspotService.qml` | `JsonStore`, `Exec` (fixes F-1) |
| `services/ScreenRecService.qml` | `services/media/ScreenRecService.qml` + `media/recorders/WfRecorder.qml` | split: state machine / backend / config store |
| `services/UpdateService.qml` | `services/system/UpdateService.qml` | `Exec` |
| `services/config_tab/KeybindService.qml` | `services/desktop/KeybindService.qml` + `keybindLua.js` | `JsonStore`; generator as pure JS (unit-tested); capture submap via `Hypr` |
| `services/config_tab/keynames.js` | `services/desktop/keynames.js` | pure JS |
| `services/DataService.qml` | `services/data/DataActions.qml` | `ExecQueue`; uses stores' `clear()`/`flush()` |
| `services/FocusModeService.qml` | `services/desktop/FocusModeService.qml` | `Hypr` |
| `services/AppearanceService.qml` | `services/desktop/AppearanceService.qml` | `Hypr` |
| `services/BrightnessService.qml` | `services/system/BrightnessService.qml` | `Exec` |
| `services/QuickToggleService.qml` | `services/desktop/QuickToggleService.qml` | `Exec`; airplane mirror → `ShellModes` binding |
| `services/ScreenFilterService.qml` | `services/media/ScreenFilterService.qml` | `Exec` |
| `services/CavaService.qml` | `services/media/CavaService.qml` | lease (visualiser shown) |
| `services/ActiveWindowService.qml` | `services/desktop/ActiveWindowService.qml` | |
| `services/BatteryWarningService.qml` | `services/system/BatteryWarningService.qml` | raises `Dialogs.alert` through a signal handled in `app/` |
| `services/BatteryStatus.qml` (view-ish `Item`) | `services/system/BatteryService.qml` (singleton) | one instance for all screens |
| `services/network/WifiService.qml` | `services/network/WifiService.qml` + `nmcli.js` | `Exec` argv (F-1), parsers to JS |
| `services/network/BluetoothService.qml` | `services/network/BluetoothService.qml` + `bluetoothctl.js` | |
| `services/network/VpnService.qml` | `services/network/VpnService.qml` | lease instead of `Popups.networkOpen` (F-1) |
| `services/notifications/NotificationService.qml` | `services/notifications/NotificationService.qml` | |
| `services/system/CpuService.qml` … `ThermalService.qml`, `FanControl.qml`, `EnvyControlService.qml`, `CpuFreqService.qml`, `GpuService.qml`, `MemService.qml`, `NetService.qml`, `DiskService.qml` | `services/system/{Cpu,CpuFreq,Memory,Gpu,GpuMode,Fan,NetStats,Disk,Thermal}Service.qml` | singletons + leases; `EnvyControlService` → `GpuModeService` (stops reading `Popups`) |
| `services/system/SystemStats.qml` (`Item` with a process) | `features/dashboard/system/` view + `services/system/SystemInfoService.qml` | |
| `services/system/EnvyControl.qml` (`Column` with a process) | `features/dashboard/system/GpuModeSwitch.qml` | process → `GpuModeService` |

### 7.4 Views that live under `services/` today

| Today | Target |
|---|---|
| `services/AudioControl.qml` (393) | split → `features/audio/{AudioContent,OutputPage,InputPage,MixerPage}.qml`; Pipewire access → `services/media/AudioService.qml` |
| `services/AppLauncher.qml` (465) | split → `features/dashboard/apps/{AppLauncher,AppGrid,AppTile,LauncherSearch}.qml`; `list_apps.py` process → `services/desktop/AppsService.qml` |
| `services/PowerMenu.qml` | `features/power/PowerMenu.qml`; process → `services/system/PowerService.qml` |
| `services/KanbanBoard.qml` | `features/dashboard/tasks/TaskBoard.qml` |
| `services/kanban/KanbanColumn.qml`, `KanbanTaskCard.qml`, `KanbanDatePicker.qml` (394) | `features/dashboard/tasks/TaskColumn.qml`, `TaskCard.qml`, `TaskDatePicker.qml` (split: calendar grid, time row) |
| `services/kanban/KanbanDeleteDialog.qml` | `components/feedback/ConfirmOverlay.qml` |
| `services/notifications/NotificationList.qml` | `features/notifications/NotificationList.qml` + `NotificationCard.qml` |
| `services/config_tab/ShellConfig.qml` | `features/dashboard/config/ShellConfig.qml` + `ConfigTabs.qml` |
| `services/config_tab/{General,Appearance,Data,Keybinds,Misc}Page.qml` | `features/dashboard/config/pages/` |
| `services/config_tab/KeybindRow.qml` (352) | `features/dashboard/config/pages/keybinds/KeybindRow.qml` (split: capture field, conflict badge) |
| `services/home/DashHome.qml` | `features/dashboard/home/HomePage.qml` |
| `services/home/{ProfileCard,CalendarCard,ClockCard,QuickSettings,QuickFilterPicker}.qml` | `features/dashboard/home/`; `ProfileCard` processes → `ProfileService` |
| `services/home/PlayerCard.qml` (500) | split → `features/dashboard/home/player/{PlayerCard,PlayerArt,PlayerControls,PlayerProgress}.qml`; MPRIS selection → `MediaService` |
| `services/home/clock/*` | `features/dashboard/home/clock/` |

### 7.5 `popups/`, `modules/`, `windows/`, `shapes/`, `components/`

| Today | Target |
|---|---|
| `popups/DashboardContent.qml` | `features/dashboard/DashboardContent.qml` (tabs and pages from `DashboardPages`) + `DashboardPopup.qml` (spec) |
| `popups/NetworkContent.qml`, `WifiTab`, `BluetoothTab`, `VPNTab`, `HotspotTab` | `features/network/` with `wifi/`, `bluetooth/`, `vpn/`, `hotspot/` + `NetworkPopup.qml`, `NetworkTabs.qml` |
| `popups/HistoryTab.qml` (442) | split → `features/clipboard/{ClipboardView,ClipboardRow,ClipboardPreview}.qml`; process → `ClipboardService` |
| `popups/WallpaperContent.qml`, `popups/wallpaper/*` | `features/wallpaper/` + `WallpaperPopup.qml` |
| `modules/Left/*` | `features/bar/left/` (`ControlPanel` → `PowerButton`, `LayoutDisplayer` → `LayoutIndicator` with `KeyboardLayoutService`) |
| `modules/Right/*` | `features/bar/right/` (`Network` → `NetworkIndicator`, `Audio` → `AudioIndicator`, `Battery` → `BatteryIndicator`, `Notifications` → `NotificationsButton`) |
| `modules/Center/CenterContent.qml`, `Notch*Item.qml`, `NotchGlyphButton`, `NotchStripButton`, `CavaBars` | `features/bar/center/` (+ `NotchItems.qml`) |
| `modules/Center/DashStats.qml`, `*Panel.qml` | `features/dashboard/system/SystemPage.qml`, `panels/` |
| `windows/ShellHost.qml`, `DynamicSurface.qml`, `StrutWindow.qml`, `windows/surface/*` | `surface/` (`DynamicSurface` loses the `contents` table and region geometry → `PopupManifest`, `Regions.qml`) |
| `windows/ConfirmDialog.qml` (383), `BatteryCriticalDialog.qml`, `UpdatePopup.qml` (458) | `dialogs/` (split: `UpdatePopup` → header, changelog, actions; `ConfirmDialog` render-only) |
| `shapes/SurfaceShape.qml`, `surfacePath.js` | `surface/shape/` |
| `components/network/*` | `features/network/<tab>/` (they read services) |
| `components/sliders/BrightnessSlider.qml` | `components/inputs/IconSlider.qml` + container in `features/osd/` and `home/` |
| `components/QuickControlContent.qml` | `features/osd/QuickControls.qml` |
| `components/ScreenRecOptions.qml` | `features/screenrec/ScreenRecOptions.qml` |
| `components/ToastCard.qml` | `components/feedback/Toast.qml` (presentational) + container in `surface/` |
| `components/PopupFocusGrab.qml` | `dialogs/PopupFocusGrab.qml` (takes `active` only) |
| `components/QuickToggleTile.qml` | `components/base/ToggleTile.qml` |
| `components/Settings*.qml` | `components/settings/` presentational + `features/dashboard/config/controls/Pref*.qml` |
| `components/{ActionBtn,IconBtn,StatCard,StatRow,TabSwitcher,TimeInput,Speedometer,DiskBar,PopupPage,ProfileButton}.qml` | `components/base/` and `components/inputs/` (`ProfileButton` → `features/dashboard/home/` if it reads a service) |

---

## 8. Contracts of the core types

These are the APIs v0.7.0 implements. Property types are QML types; "→" is a signal.

### 8.1 `Exec` (component, `core/`)

| Member | Type | Meaning |
|---|---|---|
| `command` | `list<string>` | argv; never a shell string built from data |
| `environment` | `var` | extra env vars |
| `stdin` | `string` | written once on start (e.g. a password), never on the command line |
| `parse` | `function(stdout): var` | optional pure parser; result passed to `succeeded` |
| `timeout` | `int` ms | 0 = none; kills and fails with code 124 |
| `busy` | `bool` (ro) | running |
| `lastError` | `string` (ro) | last stderr on failure |
| `run(args?)` | function | starts (restarting if running); `args` overrides `command` once |
| `cancel()` | function | |
| → `succeeded(var result)` | | exit 0 |
| → `failed(int code, string stderr)` | | non-zero exit, timeout (124), parse error (-1), command that can't start (-2) |
| → `finished(bool ok)` | | after either, for "whatever happened" handlers |
| → `line(string text)` | | streaming mode (`stream: true`), for `cava`, `wf-recorder` |

`ExecQueue { function enqueue(argv, onDone) }` runs one at a time.

### 8.2 `JsonStore` (component, `core/`)

| Member | Type | Meaning |
|---|---|---|
| `path` | `string` | file |
| `defaults` | `var` | used when missing or unparsable; shallow-merged into loaded data so new keys appear |
| `version`, `migrate(doc, from)` | `int`, function | format changes |
| `watch` | `bool` | reload on external change |
| `readOnly` | `bool` | never writes (colors, config provider) |
| `saveDelay` | `int` ms | debounce, default 300 |
| `data` | `var` (ro) | current document; reassigned on every change |
| `ready` | `bool` (ro) | first load finished |
| `error` | `string` (ro) | parse/read error, "" = none |
| `update(fn)` | function | `fn(copy)` mutates a deep copy; then reassign + save |
| `set(doc)`, `clear()`, `flush()` | functions | |
| → `loaded()`, `saved()`, `failed(string)` | | |

### 8.3 `Poller`, `Lease`

`Poller { interval; running; immediate: true; → tick() }` (a `Timer` that also fires on start).
`Lease { service; active }` calls `service.acquire()` / `release()`; the service exposes `watched` from an embedded `LeaseCount` (_implemented in #142_).

### 8.4 `Hypr` (singleton, `core/`)

`provider` (`"lua"` / `"conf"`, from `config_Provider.json`), `dispatch(name, args)`, `eval(lua)`, `setOption(name, value)`, `getOption(name): Promise-like callback`, `submap(name)`, `reload()`, `refreshWorkspaces()`, `refreshToplevels()`. Each picks the right syntax for the provider (§5.11).

### 8.5 Spec types (`core/specs/`)

```qml
// PopupSpec.qml
QtObject {
    required property string key            // "dashboard"
    required property string region         // top | right | leftCenter | rightCenter | bottomCenter | bottomRight
    required property Component component
    property var size:  (s) => [0, 0]       // s = the DynamicSurface: px(), borderWidth, notchBottom…
    property var place: (s, w, h) => Qt.rect(0, 0, w, h)
    property var focus: (item) => item.forceActiveFocus()
    property var onClosed: (item) => {}     // after the close animation
    property var pages: null                // a page registry (dashboard, audio, network)
    property string defaultPagePref: ""     // "defaultDashboardPage"
}

// PageSpec.qml
QtObject {
    required property string key            // "kanban"
    required property string label          // "Tasks"
    property string icon: ""
    property int width: 0                   // popup width for this page, 0 = the popup's default
    required property Component component
    property string action: ""              // IPC/keybind key, "" = none
    property string actionLabel: ""
}

// TabSpec: key, label, icon, component
// BarWidgetSpec: key, label, zone ("left" | "center" | "right"), component, defaultOrder
// TileSpec: key, label, icon, on, sublabel, busy, enabled, toggle(), secondary(), indicator (icon for #24)
// NotchItemSpec: key, active (bool binding), priority, autoScroll ("never" | "fromTitle" | "always"), component
// Action: key, label, group, run(), enabled
```

### 8.6 `SurfaceState` (singleton)

Unchanged: `activeScreen`, `activeContent`, `activeRegion`, `anyOpen`, `open`, `close`, `toggle`, `isOpen`.
New: `phase` (`"closed" | "opening" | "open" | "closing"`), `phaseOf(key)`, `regionOf` (computed from the registry), signals `opening`, `opened`, `closing`, `closed` (each `(string key, string screen)`). The surface reports `animationDone(key)`; `SurfaceState` moves the phase.

### 8.7 `Dialogs` (singleton)

`confirm({ title, message, label, destructive, onAccept, onCancel })`, `alert({ title, message, label, level })`, `current`, `busy`, `accept()`, `cancel()`. Requests queue; the dialog closes the dashboard when shown (as `showConfirm` does today).

### 8.8 `Theme` (singleton facade)

`Theme.color.*`, `Theme.font.*`, `Theme.space.*`, `Theme.radius.*`, `Theme.motion.*`, `Theme.frame.*` (§5.12). The old flat names (`Theme.active`, `Theme.cornerRadius`, …) are renamed in S10; no compatibility aliases are kept after v0.7.0.

---

## 9. Conventions

**Names**

| Kind | Pattern | Example |
|---|---|---|
| Service (singleton) | `<Domain>Service` | `WifiService`, `TaskService` |
| Store-only singleton | noun | `Prefs`, `AppPins` |
| Popup spec | `<Feature>Popup` | `DashboardPopup` |
| Popup content | `<Feature>Content` | `NetworkContent` |
| Page / tab view | `<Name>Page` | `HomePage`, `GeneralPage` |
| Registry manifest | plural noun | `DashboardPages`, `QuickTiles`, `BarWidgets` |
| Presentational component | what it is | `IconSlider`, `ConfirmOverlay` |
| Container wrapping a component | `<Thing><Role>` | `BrightnessControl`, `PrefToggle` |
| Pure JS module | camelCase, `.js` | `nmcli.js`, `keybindLua.js` |
| Spec keys, action keys | kebab or the existing key | `dashboard-kanban`, `powerMenu` |

**File layout** (in this order): imports (`QtQuick`, `Quickshell…`, then `qs.src.*` from lowest layer up) → header comment (what, who uses it, key behaviour) → `id` → public `required property` → public properties → `readonly` derived state → signals → public functions → private `_` properties and functions → child objects. Sections separated with the existing `// ── Name ──` rule.

**Code**
- Typed function signatures (`function connect(ssid: string): void`) and typed properties; `var` only for JS objects/arrays.
- Private members start with `_` and are never read from another file.
- No `id` reaching into another file's internals; use properties and signals.
- Arrow functions for small callbacks; `function` declarations for public API.
- One responsibility per file; **budgets** (CI warning): views ≤ 300 lines, services and pure `.js` modules ≤ 350, any file ≤ 500 (error).
- Comments say *why*; the header says *what*. Issue numbers in comments only where they explain a decision.
- No literal colours, sizes, durations or font families in views once their area has moved to tokens (enforced per area, D1).

**Imports**: only `import qs.src.<path>`; relative imports allowed only for a `.js` file in the same folder (`import "nmcli.js" as Nmcli`).

---

## 10. Recipes: adding a feature

### 10.1 A dashboard page

1. `features/dashboard/<name>/<Name>Page.qml`: the view (binds to services, holds `Lease`s and a `PopupLifecycle` if it resets on close).
2. One entry in `features/dashboard/DashboardPages.qml`:
   ```qml
   PageSpec { key: "calendar"; label: "Calendar"; icon: "󰃭"; component: Component { CalendarPage {} }
              action: "dashboard-calendar"; actionLabel: "Dashboard: Calendar" }
   ```
3. One line in `config/keybind-defaults.json` for its action (empty `mods`/`key` for no default bind; the contract test reminds you).

Tab bar, page width, IPC handler, keybinds page and Config → General's default-page options pick it up.

### 10.2 A popup

1. `features/<name>/<Name>Content.qml` and `<Name>Popup.qml` (a `PopupSpec`: region, size, place, focus).
2. One line in `app/PopupManifest.qml`.
3. Sizes as tokens in `theme/tokens/FrameTokens.qml`.

The region, click-outside, Escape, keyboard focus, lifecycle signals and toggle action come from the framework.

### 10.3 A bar widget

`features/bar/<zone>/<Name>.qml` + one `BarWidgetSpec` in `features/bar/BarWidgets.qml`. It appears in the default layout at `defaultOrder`, and in the layout picker (#23).

### 10.4 A Quick Settings tile

One `TileSpec` in `features/dashboard/home/QuickTiles.qml` bound to a service's state and intents (`toggle: host => MyService.toggle()`). Setting `indicator` makes it show in the bar indicators (#24).

### 10.5 A preference and its control

1. One entry in `services/data/PrefSchema.qml`: `{ default, type, options | min/max, label }`.
2. In a config page: `PrefToggle { key: "myPref" }` (or `PrefSlider`, `PrefDropdown`, …). Label, range, options and the reset button come from the schema.
3. Read it anywhere as `Prefs.data.myPref`; write with `Prefs.set("myPref", v)`.

### 10.6 A service around a CLI tool

1. `services/<domain>/<Name>Service.qml` with `Exec`s (argv), state as `readonly` properties, intents as functions, a `Poller` gated by `watched` if it polls.
2. Parsers in `services/<domain>/<tool>.js` + `tests/unit/<tool>.test.mjs` with real sample output.
3. If it must start at boot: add it to `app/App.qml`'s eager list.

### 10.7 An action and its keybind

One `Action` in `app/ActionManifest.qml` (or generated by a registry) + one line in `config/keybind-defaults.json`. IPC handler, keybinds page and generated Hyprland binds follow.

### 10.8 A persisted data file

`JsonStore { path: Paths.userData("x.json"); defaults: … }` inside the owning service; add the file to Config → Data & Storage if the user should be able to reset it, and to `DEPLOY-MAP.md`'s runtime tree.

---

## 11. Tests and CI

| Check | What it proves | When it lands |
|---|---|---|
| `tests/unit/*.test.mjs` (node) | pure JS: `surfacePath`, `nmcli`, `bluetoothctl`, `keybindLua`, `keynames`, formatters, store migrations | S1 (runner), S3+ (each parser) |
| `tests/smoke.sh` + `smoke.qml` | every singleton loads, no QML errors | today |
| `tests/smoke-registries.qml` | instantiates **every** registry entry: each popup content, page, tab, tile, bar widget, notch item, dialog | S1 (hand list), S8 (from registries) |
| `tests/contracts.qml` | `keybind-defaults.json` keys = `Actions` keys = IPC targets; every `PopupSpec.region` exists; every `PageSpec.action` unique; every pref used by a control exists in the schema | S1 (keybinds ↔ IPC), S8 (all) |
| `tests/golden.sh` | offscreen screenshots (`grabToImage`) of every scene of `tests/lib/SceneList.qml` (popup contents, pages, tabs, bar parts, the frame shape in the three styles), captured for the **base commit and the PR** on the same machine and compared pixel by pixel (1 % fuzz). No reference images are committed, so fonts and renderer never drift. Deterministic: only `bash`/`sh` on `PATH`, no D-Bus/Pipewire/Hyprland, empty user data, fixed temp path and locale, and libfaketime (2026-01-01 12:00) for the scenes showing the time | S1 (CI job `golden`; a `visual-change` label makes it advisory) |
| `tests/layers.py` | the dependency rules below and the size budgets; `--self-test` proves each rule catches a planted violation | S1 warn-only, S12 enforced (CI fails) |

**Layer rules** (`layers.py`, grep-based; any violation fails CI, there is no allowlist):

1. No `Process`, `FileView`, `Socket`, `SplitParser`, `StdioCollector` outside `core/` (services use `Exec`/`JsonStore`).
2. No visual item (`Item`, `Rectangle`, `Text`, …) as the root of a file in `services/`, `state/`, `actions/`, `core/` (except `core/specs`).
3. `services/` never imports `qs.src.state`, `qs.src.actions`, `qs.src.features`, `qs.src.surface`, `qs.src.dialogs`, and never names `Popups` or `SurfaceState`.
4. `components/` imports only `qs.src.theme` and `qs.src.core`.
5. `surface/` and `dialogs/` never import `qs.src.features`.
6. No `import "../` anywhere.
7. No `"-c"` command element followed by string concatenation in the same array (best-effort check for F-1 class bugs).
8. File size budgets (§9): warn above the view/service budget, fail above 500.

Golden images use Qt's software renderer offscreen, which differs from the live `Shape.CurveRenderer`; they compare **before vs after on the same renderer**, which is exactly what "no visible change" needs. Shape changes still get a live look. Layer-shell windows (`ConfirmDialog`, `BatteryCriticalDialog`, `UpdatePopup`) can't be created offscreen; their parts join the scenes as plain components (`update-header`), and the rest is a live check.

---

## 12. Migration record (v0.7.0)

**Workflow:** a native GitHub stack (`gh stack`, see `CLAUDE.md` "Project workflow") on `dev`: one branch and PR per step, each based on the step below, #141 at the bottom. Layers merge bottom-first with `gh stack merge`, whole or in part, only when asked. Every file moves, so no other stack is open meanwhile; `gh stack sync` after each release. Each PR: smoke + contracts + golden images green, live check on the install (§`CLAUDE.md` live testing), `CLAUDE.md` paths updated in the same PR.

The sub-issues of #111 were rewritten on 2026-11-13 to match these steps: #112, #113, #115, #116 and #117 were rewritten, #114 was folded into #113 and closed, and #141–#147 were created. Each step is blocked by the previous one.

| Step | Title | Scope | Done when | Issue | Size |
|---|---|---|---|---|---|
| **S1** | Safety net | Unit test runner for all `*.mjs`; `smoke-registries.qml` + `lib/SceneList.qml` listing every content/page/tab/bar part by hand; `contracts.qml` (keybinds ↔ IPC targets); `golden.sh` (base vs head capture and compare) + CI job; `layers.py` in warn mode with today's violations allowlisted; **spike**: `IpcHandler` inside an `Instantiator` (works). | CI runs all of it; a 1 px change fails the golden check; spike result written in this file. | #141 | M |
| **S2** | `qs.*` imports, one registry | Replace all 237 relative imports with `qs.src.*`; delete the 4 qmldirs; every singleton uses `pragma Singleton` + `Singleton {}`. No file moves. | No `import "../`; no qmldir; smoke + golden green. | #112 | M |
| **S3** | Core toolkit | `core/Exec`, `ExecQueue`, `JsonStore`, `Poller`, `Lease`/`LeaseCount`, `Hypr`, `Log`, with unit tests where pure and behaviour tests (`tests/core.qml`); the spec types land with S7, their first user. Pilots: `TaskService` on `JsonStore`, `WifiService` + `VpnService` + `HotspotService` on `Exec` argv (this fixes F-1 if it wasn't fixed before the stack). | Pilots behave identically; F-1 closed. | #142 | M |
| **S4** | Move the tree | Pure moves and renames to §6 / §7 (`features/`, `surface/`, `dialogs/`, `services/<domain>/`, `components/<group>/`, `app/`). Splits not included. | `popups/`, `windows/`, `modules/`, `shapes/`, `utils/`, `services/{config_tab,home,kanban,notifications}` gone; golden green. | #113 | L (mechanical) |
| **S5** | Services on the toolkit | Every `Process` → `Exec`/`ExecQueue` (argv), every store → `JsonStore` (atomic), every poll → `Poller` + `Lease`; system services become singletons; services stop reading `Popups`; parsers → pure JS with tests. | Rules 1 and 3 pass for `services/`. | #115 | L |
| **S6** | Processes out of the views, `ShellState` split | `PowerService`, `GpuModeService`, `AppsService`, `KeyboardLayoutService`, `ProfileService`, `SystemInfoService`, `AudioService`, `MediaService` (MPRIS selection only); views keep only bindings; `ShellState` → `ShellModes` + `Hypr` + `KeybindService`. | Rule 1 passes everywhere. | #143 | M |
| **S7** | Popup registry and lifecycle, `Dialogs` | `core/specs/*`; `PopupSpec` per popup, `app/PopupManifest`, `SurfaceState` phases + signals, `PopupLifecycle`; delete `contents`, `regionOf`, the `afterClose` timer and the `xxxOpenChanged` `Connections`; `Dialogs` mediator, render-only `ConfirmDialog`. | Adding a popup = spec + manifest line (checked by a throwaway test popup in the PR). | #144 | M |
| **S8** | Extension registries | `Actions` + `IpcBridge` (or fallback), dashboard pages, audio pages, network tabs, config tabs, Quick Settings tiles, bar widgets (layout pref with today's order as default), notch items; registries feed smoke and contracts. | §2.3 is one entry; contracts cover every registry. | #145 | L |
| **S9** | Prefs schema and settings controls | `Prefs` on `JsonStore` + `PrefSchema` (same file, same keys); presentational `Settings*`; `Pref*` containers; validation (bar style, ranges) in the schema. | Adding a pref = one schema line + one control line. | #146 | M |
| **S10** | Theme tokens | Token groups with today's values, `ColorSource` interface (matugen only), `Theme` facade; rename every existing `Theme.*` read; `Anim`/`Fade` motion components. | `Metrics`/`Colors` names gone from views; golden green. | #147 | M |
| **S11** | Split the last large files | `PlayerCard`, `AppLauncher`, `UpdatePopup`, `ScreenRecService` (+ recorder strategy), `HistoryTab`, `UpdateService`, `KeybindService` (+ `keybindLua.js`), `TaskDatePicker`, `AudioControl` pages, `ConfirmDialog`, `KeybindRow`, `DynamicSurface` (→ `Regions`). | No file > 400 lines; budgets pass. | #116 | M |
| **S12** | Lock it in | `layers.py` enforced (allowlist empty), size budgets in CI, `CLAUDE.md` architecture section rewritten around §4–§10, this document updated from "plan" to "reference". | All rules fail CI on violation. | #117 | S |

**Order rationale**
- S1 first: nothing else is safe to merge without it.
- S2 before S4: with `qs.*` imports a move changes one import name, not `../` depths.
- S3 before S5: the toolkit lands with small pilots, so its API is proven before 40 files adopt it.
- S4 early: every later PR edits files in their final place (the same reason v0.7.0 comes before v0.8.0).
- S7 before S8: page registries hang off popup specs.
- S10 late: renaming `Theme.*` after the moves avoids touching each file twice; it must land before v0.8.0 starts.

**Estimated effort:** about 3–4 weeks of focused work; S4, S5 and S8 are the large ones.

**Outcome:** all twelve steps were built as one native stack (#148 → #171), each with smoke, contracts and golden images green and a live check on the install; the "Done in" notes of §7 record each step.

---

## 13. How the roadmap plugs in

| Item | Extension point | What it adds | Refactor needed |
|---|---|---|---|
| #78/#79–#84 content scaling (v0.8.0) | `Theme.space/font/radius/frame` × scale | per-area literal → token passes | none |
| #102/#103/#104 font set (v0.8.0) | `Theme.font` families | three family tokens, installer packages | none |
| #23 layout picker (v0.9.0) | `BarWidgets` + `Prefs.barLayout` + `ConfigTabs` | the Layout & Behavior page | none |
| #24 bar indicators | `TileSpec.indicator` | an indicator strip widget | none |
| #25 workspace app icons | `BarWidgets` | a widget | none |
| #22 per-app mixer | `AudioPages` + `AudioService` streams | a page | none |
| F3a theme presets / F27 community themes | `ColorSource` strategy + `JsonStore` for `themes/` | `PresetSource` | none |
| F3b colour studio | `ColorSource` override layer | a config page | none |
| F3d animation engine | `Theme.motion` + `Anim` | style/speed prefs | none |
| F17 light mode + picker tiles | colour roles + state layers; `QuickTiles` | tiles, light templates | none |
| F6 MediaService / F13 MiniPlayer | `MediaService` (S6), `PopupSpec` (region `top`, notch dropdown) | a popup | none |
| F12 hover-to-open | `PopupSpec` (`hover`, delays) + `SurfaceTriggers` | prefs + trigger zones | none |
| F14 recorder backends | `RecorderBackend` strategy | two backends | none |
| F15 Hyprland binds list | `Hypr` + `ConfigTabs` | a page | none |
| F16 systray | `BarWidgets` | widget rewrite | none |
| #85 clipboard keys | `features/clipboard` | key handling | none |
| #86 notification expiry | `NotificationService` | timeout logic | none |
| #87 wallpaper thumbnails | `WallpaperService` + `Exec` | cache | none |
| #88 launcher frecency | `AppsService` + `JsonStore` | a store, a Data & Storage action | none |
| #89 `synapse` CLI | `Actions` (`synapse <action>` = `qs ipc call <action> toggle`, `synapse list`) | a script | none |
| #109 Notion sync | `TaskService` + `TaskSync` strategy | a sync adapter | none |
| #16 wallpaper library | `WallpaperService` | sources | none |

---

## 14. Decisions (taken 2026-11-13, as recommended)

| # | Question | Recommendation |
|---|---|---|
| **D1** | Where do the ~1 400 literal colours, sizes, fonts and durations become tokens? | **In v0.8.0's per-area passes (#80–#84)**, which already touch every size literal of each area: one touch per file for sizes, fonts, colours and motion. v0.7.0 only creates the token API and renames existing `Theme.*` reads. Alternative: a dedicated S13 in v0.7.0 (+1–2 weeks, files touched twice). |
| **D2** | Rename `Kanban*` → `Task*`, `ClockState` → `ClockService`, `Battery`/`Audio` widgets → `*Indicator`? | Yes, during S4: they move anyway, and the names then match the UI ("Tasks") and the layer. IPC keys (`dashboard-kanban`) and file names on disk (`tasks.json`) don't change. |
| **D3** | `Prefs` API: keep typed aliases (`PrefsService.borderWidth`) or `Prefs.data.borderWidth` + `Prefs.set()` with a schema? | Schema + `data`: adding a pref becomes one line instead of three, and controls get labels/ranges from it. The whole object is reassigned on change; with ~20 prefs that costs nothing. |
| **D4** | Golden-image tests in CI? | Yes, offscreen, before/after on the same renderer (§11). If they turn flaky on the CI runner, keep them as a local `tests/golden.sh` that each S-PR runs. |
| **D5** | Keep `Popups` as the facade name? | Yes; it is used in ~50 places and reads well. `SurfaceState` stays the engine. |
| **D6** | Bar layout pref in v0.7.0 (no UI yet)? | Yes, with today's order as the default: it makes the bar a registry consumer now, so #23 is UI only. |
| **D7** | Scale mechanism for v0.8.0 (tokens × `localScale` vs a `scale` transform per content host) | Stays #79's spike, but v0.7.0 keeps `localScale` in one place (`surface/`) and contents receive it through one property, so either answer needs no refactor. |

---

## 15. Findings to fix outside v0.7.0

| # | Finding | Where | Recommendation |
|---|---|---|---|
| **F-1** | **Shell injection.** Wi-Fi SSIDs (from the scan list, i.e. chosen by whoever runs a nearby access point), VPN connection names and the hotspot SSID/password are pasted into `bash -c` strings inside double quotes. An SSID such as `$(…)` runs a command when the user clicks it; a password containing `"` breaks the command. | `services/network/WifiService.qml:90-101`, `VpnService.qml:61,75`, `HotspotService.qml:73-74`, `BluetoothService.qml:79-88` (MAC from bluetoothctl, lower risk) | **Fixed in v0.6.2** (#133, #134), together with the same bug in `WallpaperService`. Originally recommended: argument lists, or `"$1"` positional arguments; the password through stdin or `nmcli … password` as its own argv element. S3/S5 then generalise it. |
| **F-2** | Keybind labels swapped: `dashboard-home` (Super+D, opens Home) is labelled "Dashboard: System", `dashboard-stats` (Ctrl+Shift+Esc, opens System) "Dashboard: Home". | `config/keybind-defaults.json:2-3` | Quick win: swap the two labels (visible in Config → Keybinds). |
| **F-3** | System services are instantiated per `DashStats`, i.e. per screen; `FanControl`, `EnvyControlService` and `CpuFreqService` are not gated by visibility. | `modules/Center/DashStats.qml:9-21` | Covered by S5 (singletons + leases). |
| **F-4** | `Theme.iconFont` is a colour but is used as a font family. | `services/notifications/NotificationList.qml:120` | Already in #104. |
