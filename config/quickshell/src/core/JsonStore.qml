import QtQuick
import Quickshell.Io

// JsonStore — one JSON document on disk, owned by one service.
//
//   JsonStore {
//       id: store
//       path:     Paths.userData("tasks.json")
//       defaults: ({ tasks: [], nextId: 0 })
//   }
//   readonly property var tasks: store.data.tasks
//   function add(t) { return store.update(d => { d.tasks.unshift(t); return d.nextId++ }) }
//
// • Writes are atomic (a temp file renamed over the old one), so a crash
//   never leaves half a file.
// • Nothing is written before the first load has finished, so an early
//   change can't overwrite the file with defaults.
// • A missing file gives `defaults` (and is created unless `readOnly` or
//   `createIfMissing: false`). Keys missing from the file are filled from
//   `defaults`; keys the defaults don't know are kept.
// • A file that doesn't parse gives `defaults` and sets `error`. Its content
//   is copied to "<path>.broken" before the first write replaces it.
// • `version` + `migrate(doc, fromVersion)` handle format changes; the
//   document only gets a `_version` key once `version` is above 0, so
//   existing files stay byte-identical until a migration exists.
// • `watch: true` reloads when another program edits the file (our own
//   writes are ignored).
QtObject {
    id: root

    property string path:            ""
    property var    defaults:        ({})
    property int    version:         0
    property var    migrate:         null     // function(doc, fromVersion) → doc
    property bool   watch:           false
    property bool   readOnly:        false
    property bool   createIfMissing: true
    property int    saveDelay:       0        // ms of debounce; 0 = right after the change
    property int    indent:          0        // JSON.stringify indent; 0 = compact

    readonly property var    data:  _data
    readonly property bool   ready: _ready
    readonly property string error: _error

    signal loaded()
    signal saved()
    signal failed(string message)
    signal cleared()
    signal created()       // the file was missing; the defaults were written

    // Applies `fn(doc)` to a copy of the document, keeps the copy and saves
    // it. Returns what `fn` returns. Ignored (returns undefined) before the
    // first load or on a read-only store.
    function update(fn) {
        if (!_ready || readOnly) {
            console.warn("JsonStore: update ignored (" + (readOnly ? "read-only" : "not loaded yet") + "): " + path)
            return undefined
        }
        const copy = _clone(_data)
        const result = fn(copy)
        _data = copy
        _scheduleSave()
        return result
    }

    // Replaces the whole document.
    function set(doc) {
        if (!_ready || readOnly) return
        _data = _withDefaults(_clone(doc))
        _scheduleSave()
    }

    // Writes `defaults` to disk first, and only once that worked resets
    // `data` and emits cleared(); a failed write emits failed() and keeps the
    // data, so a broken disk can't leave an empty list that later saves over
    // the file.
    function clear() {
        if (readOnly) return
        _saveTimer.stop()
        _clearing = true
        _write(_clone(defaults))
    }

    // Saves now (before a restart or a factory reset).
    function flush() {
        if (_dirty) { _saveTimer.stop(); _write(_data) }
    }

    // ── Implementation ──────────────────────────────────────────────────────
    property var    _data:        _clone(defaults)
    property bool   _ready:       false
    property string _error:       ""
    property bool   _dirty:       false
    property bool   _clearing:    false
    property string _lastWritten: ""
    property string _brokenText:  ""      // unparsable content to back up before the first write

    function _clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)) }

    // An array document (defaults: []) is kept as is when the file holds one.
    function _withDefaults(doc) {
        // (cloned first: a QML list property reads back as a list type, not an Array)
        if (Array.isArray(_clone(defaults))) return Array.isArray(doc) ? doc : _clone(defaults)
        if (doc === null || typeof doc !== "object" || Array.isArray(doc)) return _clone(defaults)
        for (const k in defaults)
            if (!(k in doc)) doc[k] = _clone(defaults[k])
        return doc
    }

    function _scheduleSave() {
        _dirty = true
        if (saveDelay > 0) _saveTimer.restart()
        else Qt.callLater(root._saveIfDirty)
    }
    function _saveIfDirty() { if (_dirty && !_clearing) _write(_data) }

    function _write(doc) {
        if (readOnly) return
        if (_brokenText !== "") {
            _backup.setText(_brokenText)
            _brokenText = ""
        }
        const text = indent > 0 ? JSON.stringify(doc, null, indent) : JSON.stringify(doc)
        _dirty = false
        _lastWritten = text
        _file.setText(text)
    }

    function _onLoaded() {
        const raw = _file.text()
        if (_ready && raw === _lastWritten) return     // our own write coming back
        let doc
        try {
            doc = raw.trim() === "" ? _clone(defaults) : JSON.parse(raw)
            _error = ""
        } catch (e) {
            _error = "unreadable JSON (" + (e.message || e) + ")"
            _brokenText = raw
            console.warn("JsonStore: " + path + ": " + _error + " (using the defaults; the file is kept as .broken)")
            doc = _clone(defaults)
        }
        doc = _withDefaults(doc)
        let migrated = false
        if (version > 0) {
            const from = typeof doc._version === "number" ? doc._version : 0
            if (from < version) {
                if (migrate) doc = _withDefaults(migrate(doc, from))
                doc._version = version
                migrated = true
            }
        }
        _data = doc
        const first = !_ready
        _ready = true
        if (migrated) _scheduleSave()
        if (first) loaded()
    }

    property Timer _saveTimer: Timer {
        interval: root.saveDelay
        onTriggered: root._saveIfDirty()
    }

    property FileView _file: FileView {
        path:          root.path
        watchChanges:  root.watch
        atomicWrites:  true
        printErrors:   false

        onLoaded: root._onLoaded()
        onLoadFailed: function(err) {
            if (err === FileViewError.FileNotFound) {
                root._data  = root._clone(root.defaults)
                root._error = ""
                const first = !root._ready
                root._ready = true
                const create = root.createIfMissing && !root.readOnly
                if (create) root._write(root._data)
                if (first) root.loaded()
                if (create) root.created()
            } else {
                root._error = "read failed: " + FileViewError.toString(err)
                console.warn("JsonStore: " + root.path + ": " + root._error)
                root.failed(root._error)
            }
        }
        onFileChanged: reload()
        onSaved: {
            if (root._clearing) {
                root._clearing = false
                root._data = root._clone(root.defaults)
                root.cleared()
            }
            root.saved()
        }
        onSaveFailed: function(err) {
            root._clearing = false
            root._dirty = true
            const msg = "write failed: " + FileViewError.toString(err)
            console.warn("JsonStore: " + root.path + ": " + msg)
            root.failed(msg)
        }
    }

    property FileView _backup: FileView {
        path: root.path !== "" ? root.path + ".broken" : ""
        atomicWrites: true
        printErrors:  false
        preload:      false
    }
}
