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
Singleton {
    id: root

    readonly property var  data:     _validated(_store.data)
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

    function _validated(doc) {
        const out = Object.assign({}, doc)
        for (const k in PrefSchema.keys) out[k] = PrefSchema.validate(k, doc[k])
        return out
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
