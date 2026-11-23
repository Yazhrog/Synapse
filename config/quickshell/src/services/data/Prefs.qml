pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// Prefs — the shell preferences (how the shell behaves), in
// Paths.userData("shell_prefs.json"), with the keys, defaults and allowed
// values of PrefSchema.
//
//   Prefs.data.borderWidth            read (bindable)
//   Prefs.set("borderWidth", 8)       write (validated, saved debounced)
//   Prefs.reset("borderWidth"); Prefs.resetAll(); Prefs.isDefault("borderWidth")
//
// Every value is validated against the schema, on read and on write (wrong
// type → default, numbers clamped, strict options), so a hand-edited file
// can't put the shell in a state the settings can't show. Keys missing from
// the file keep their default and keys the schema doesn't know are kept,
// so an old file loads unchanged. Edits by hand are picked up live. Wait
// for `ready` (or `loaded`) before acting on a pref at startup.
//
// Adding a pref: one entry in PrefSchema.qml (+ a Pref* control in a config
// page). User data (tasks, pins, wallpaper, keybinds) keeps its own files.
//
// `data` is one object with a property per schema key, and only the keys
// whose value changed notify: dragging the border-width slider re-evaluates
// the bindings on borderWidth, not every binding on every pref.
Singleton {
    id: root

    readonly property QtObject data: _data
    readonly property var  defaults: PrefSchema.defaults
    readonly property bool ready:    _store.ready
    signal loaded()

    function set(key: string, value: var) {
        if (!(key in PrefSchema.keys)) {
            console.warn("Prefs: unknown pref", key)
            return
        }
        const v = PrefSchema.validate(key, value)
        if (_same(data[key], v)) return
        _store.update(d => { d[key] = v })
    }

    function reset(key: string) {
        if (key in PrefSchema.keys) set(key, PrefSchema.keys[key].default)
    }

    function resetAll() {
        _store.update(d => {
            for (const k in PrefSchema.keys) d[k] = JSON.parse(JSON.stringify(PrefSchema.keys[k].default))
        })
    }

    function isDefault(key: string): bool {
        return key in PrefSchema.keys && _same(data[key], PrefSchema.keys[key].default)
    }

    // ── Implementation ──────────────────────────────────────────────────────
    function _same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }

    // One `property var` per schema key, filled with the defaults before any
    // binding reads it.
    property QtObject _data: _makeData()
    function _makeData() {
        const o = Qt.createQmlObject("import QtQuick\nQtObject {\n"
            + Object.keys(PrefSchema.keys).map(k => "    property var " + k + "\n").join("")
            + "}\n", root, "PrefsData")
        for (const k in PrefSchema.keys) o[k] = PrefSchema.validate(k, PrefSchema.keys[k].default)
        return o
    }

    // Copies the validated store into _data, key by key, only where it changed.
    function _sync() {
        const doc = _store.data
        for (const k in PrefSchema.keys) {
            const v = PrefSchema.validate(k, doc[k])
            if (!_same(_data[k], v)) _data[k] = v
        }
    }
    Component.onCompleted: _sync()
    property Connections _storeChanges: Connections {
        target: root._store
        function onDataChanged() { root._sync() }
    }

    property JsonStore _store: JsonStore {
        path:      Paths.userData("shell_prefs.json")
        defaults:  PrefSchema.defaults
        watch:     true
        saveDelay: 300          // dragging a slider doesn't write on every tick
        indent:    4
        onLoaded:  root.loaded()
        // First run after the move to shell_prefs.json: carry over the
        // auto-update toggle UpdateService used to keep in update_prefs.json.
        onCreated: { root._created = true; root._carryOver() }
    }

    property bool _created: false
    function _carryOver() {
        if (!_created || !_legacy.ready) return
        _created = false
        if (typeof _legacy.data.autoUpdate === "boolean") set("autoUpdate", _legacy.data.autoUpdate)
    }

    property JsonStore _legacy: JsonStore {
        path:     Paths.userData("update_prefs.json")
        readOnly: true
        onLoaded: root._carryOver()
    }
}
