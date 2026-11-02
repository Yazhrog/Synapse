pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// AppPinService — launcher pins, shared by every per-screen AppLauncher.
// Stored as an ordered array of .desktop ids (list_apps.py's "id" field) in
// $HOME/.config/Synapse/src/user_data/app_pins.json. Pins of uninstalled apps
// are kept, just not rendered, so reinstalling an app brings its pin back.

QtObject {
    id: root

    property var pinned: []

    readonly property string _pinsPath:
        Quickshell.env("HOME") + "/.config/Synapse/src/user_data/app_pins.json"

    // ── Load ───────────────────────────────────────────────────────────────────
    property var _loadProc: Process {
        command: ["bash", "-c",
            "[ -f '" + root._pinsPath + "' ] && cat '" + root._pinsPath + "' || " +
            "(mkdir -p \"$(dirname '" + root._pinsPath + "')\" && echo '[]')"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text.trim())
                    root.pinned = Array.isArray(list) ? list : []
                } catch (e) { root.pinned = [] }
            }
        }
    }

    // ── Save ───────────────────────────────────────────────────────────────────
    property var _saveProc: Process { command: []; running: false }

    function _save() {
        var json = JSON.stringify(root.pinned)
        _saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._pinsPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root._pinsPath + "'"]
        _saveProc.running = false
        _saveProc.running = true
    }

    // ── API ────────────────────────────────────────────────────────────────────
    function isPinned(id) {
        return root.pinned.indexOf(id) !== -1
    }

    // New pins go to the end so they don't displace an order the user set up
    function toggle(id) {
        if (!id || id === "") return
        var list = root.pinned.slice()
        var i = list.indexOf(id)
        if (i === -1) list.push(id)
        else          list.splice(i, 1)
        root.pinned = list
        root._save()
    }

    // Swap a pin with its neighbour (delta -1 = up, +1 = down)
    function move(id, delta) {
        var list = root.pinned.slice()
        var i = list.indexOf(id)
        var j = i + delta
        if (i === -1 || j < 0 || j >= list.length) return
        list[i] = list[j]
        list[j] = id
        root.pinned = list
        root._save()
    }

    Component.onCompleted: _loadProc.running = true
}
