pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "keybindLua.js" as KeybindLua

// KeybindService — Synapse's own shell keybinds: the defaults
// (src/config/keybind-defaults.json) merged with the user's overrides
// (user_data/keybinds.json), conflict checks for Config → Keybinds, and the
// generated SynapseKeybinds.lua / .conf that Hyprland loads. The pure parts
// (merge, conflicts, generators) are keybindLua.js.
Singleton {
    id: root

    readonly property string _shellDir: Quickshell.shellDir
    readonly property string _configDir: Paths.configDir
    // Loaded unconditionally by config/hypr/modules/synapse-keybinds.lua on every
    // Hyprland (re)parse — see that file. Not auto-included by this service.
    readonly property string _luaPath:  _configDir + "/SynapseKeybinds.lua"
    // Written for parity but not auto-sourced anywhere: hyprland.conf isn't
    // shipped by this repo, so .conf-provider users must add
    // `source = ~/.config/Synapse/SynapseKeybinds.conf` to their own config.
    readonly property string _confPath: _configDir + "/SynapseKeybinds.conf"
    readonly property string _jsonPath: Paths.userData("keybinds.json")

    readonly property string configProvider: Hypr.provider

    // ── Capture gate ──────────────────────────────────────────────────────────
    // KeybindsPage calls setCapturing(true) while a combo is being recorded:
    // Hyprland goes to the pass-through submap "Synapse_clean" (no binds), so
    // the keys reach the shell, and back to "reset" when capture ends.
    readonly property bool isCapturing: _capturing
    property bool _capturing: false

    function setCapturing(on: bool) {
        if (on === _capturing) return
        _capturing = on
        Hypr.submap(on ? "Synapse_clean" : "reset")
    }

    // ── Defaults ──────────────────────────────────────────────────────────────
    // Single source of truth: config/quickshell/src/config/keybind-defaults.json.
    // install/steps/06-shell-config.sh reads the same file for its live conflict
    // check, so the two never drift out of sync with each other or with the
    // action keys of the Actions registry (tests/contracts.qml checks it).
    readonly property var _defaults: _defaultsStore.data

    property JsonStore _defaultsStore: JsonStore {
        path:     root._shellDir + "/src/config/keybind-defaults.json"
        readOnly: true
        onLoaded: {
            if (error !== "") console.error("Synapse: failed to parse keybind-defaults.json — no shell keybinds will be active")
            root._merge()
        }
    }

    property var keybinds: ({})

    // ── Hyprland binds cache ──────────────────────────────────────────────────
    // Refreshed each time a BindRow enters capture mode.
    property var _hyprBinds: []

    property Exec _hyprBindsProc: Exec {
        command: ["hyprctl", "binds", "-j"]
        parse: out => JSON.parse(out.trim())
        onSucceeded: binds => root._hyprBinds = binds
        onFailed: root._hyprBinds = []
    }

    function loadHyprBinds() { _hyprBindsProc.run() }

    // Returns a short description of the conflicting Hyprland bind, or "".
    // Own shell binds (arg contains "qs ipc") are filtered out.
    function wouldConflictHypr(action, mods, key) {
        return KeybindLua.hyprConflict(root._hyprBinds, mods, key)
    }

    // ── Internal duplicate detection ──────────────────────────────────────────
    readonly property var _comboMap: KeybindLua.comboMap(root.keybinds)

    function isDuplicate(action) {
        var b = root.keybinds[action]
        if (!b || !b.mods || !b.key) return false
        var combo = b.mods + "+" + b.key
        return !!(root._comboMap[combo] && root._comboMap[combo].length > 1)
    }

    function conflictsWith(action) {
        var b = root.keybinds[action]
        if (!b || !b.mods || !b.key) return ""
        var list = root._comboMap[b.mods + "+" + b.key]
        if (!list || list.length < 2) return ""
        for (var i = 0; i < list.length; i++) {
            if (list[i] !== action) {
                var o = root.keybinds[list[i]]
                return o ? o.label : list[i]
            }
        }
        return ""
    }

    function wouldConflict(action, mods, key) {
        return KeybindLua.shellConflict(root.keybinds, action, mods, key)
    }

    // ── Load ──────────────────────────────────────────────────────────────────
    // The user's overrides (only the binds that differ from the defaults).
    property JsonStore _overrides: JsonStore {
        path:            root._jsonPath
        defaults:        ({})
        indent:          2
        createIfMissing: false
        onLoaded: root._merge()
    }

    // Defaults + overrides → keybinds, then the generated files. Runs once
    // both files are read.
    function _merge() {
        if (!_defaultsStore.ready || !_overrides.ready) return
        root.keybinds = KeybindLua.merge(root._defaults, _overrides.data)
        root._writeFiles()
    }

    // ── Save / Reload ─────────────────────────────────────────────────────────
    function save() {
        _overrides.set(KeybindLua.overridesOf(root.keybinds, root._defaults))
        root._writeFiles()
    }

    // Brief delay lets the file writes flush before hyprctl re-reads them
    property var _reloadTimer: Timer {
        interval: 300
        repeat:   false
        onTriggered: Hypr.reload()
    }

    function reload() {
        _reloadTimer.restart()
    }

    // Persist to disk and reload Hyprland in one call
    function saveAndReload() {
        save()
        reload()
    }

    // Updates in-memory only — does NOT persist.
    // Callers responsible for invoking saveAndReload() when ready.
    function updateBinding(action, newMods, newKey) {
        var old = root.keybinds[action]
        if (!old) return
        var m = newMods.toUpperCase().trim()
        var k = newKey.toUpperCase().trim()
        if (m === "" || k === "") return
        if (root.wouldConflict(action, m, k) !== "") return
        var copy     = Object.assign({}, root.keybinds)
        copy[action] = { mods: m, key: k, label: old.label, group: old.group }
        root.keybinds = copy
    }

    // Reset is always immediate — reverts to default and reloads right away
    function resetBinding(action) {
        var def = root._defaults[action]
        if (!def) return
        updateBinding(action, def.mods, def.key)
        saveAndReload()
    }

    // Allows the UI to explicitly unbind an action (or preserve installer unbinds)
    function unbindBinding(action) {
        var old = root.keybinds[action]
        if (!old) return
    
        var copy = Object.assign({}, root.keybinds)
        copy[action] = { mods: "", key: "", label: old.label, group: old.group }
        root.keybinds = copy
    
        saveAndReload()
    }

    // ── File generation ───────────────────────────────────────────────────────
    // Emits CHANGED when the generated Lua differs from what is already on disk.
    // Hyprland parses SynapseKeybinds.lua at startup, before Quickshell has had
    // a chance to regenerate it — so whenever this run produces something
    // different from what Hyprland read, the binds it loaded are stale and it
    // needs a reload. Without this, a change to the generated format leaves
    // every shell keybind dead until the next manual reload.
    property Exec _writeProc: Exec {
        onSucceeded: out => {
            if (out.indexOf("CHANGED") >= 0) {
                console.log("KeybindService: generated binds changed on disk — reloading Hyprland.")
                root.reload()
            }
        }
    }

    // Writes both files so the user has them regardless of which provider they
    // use. Paths and contents go in as arguments ($1 lua, $2 conf, $3 / $4
    // their text), never into the script.
    function _writeFiles() {
        _writeProc.run(["bash", "-c",
            'mkdir -p "$(dirname "$1")" && ' +
            'printf "%s" "$3" > "$1.tmp" && ' +
            'printf "%s" "$4" > "$2" && ' +
            '{ cmp -s "$1.tmp" "$1" || echo CHANGED; } && ' +
            'mv "$1.tmp" "$1"',
            "--", root._luaPath, root._confPath,
            KeybindLua.genLua(root.keybinds), KeybindLua.genConf(root.keybinds)])
    }

    // _merge() runs when the second of the two stores (defaults, overrides)
    // has loaded, so the keybinds are never built from half the data.
}
