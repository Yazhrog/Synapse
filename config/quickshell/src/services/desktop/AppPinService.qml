pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// AppPinService — launcher pins, shared by every per-screen AppLauncher.
// Stored as an ordered array of .desktop ids (list_apps.py's "id" field) in
// Paths.userData("app_pins.json"), a JsonStore. Pins of uninstalled apps
// are kept, just not rendered, so reinstalling an app brings its pin back.

Singleton {
    id: root

    readonly property var pinned: _store.data

    function isPinned(id) {
        return pinned.indexOf(id) !== -1
    }

    // New pins go to the end so they don't displace an order the user set up
    function toggle(id) {
        if (!id || id === "") return
        _store.update(list => {
            const i = list.indexOf(id)
            if (i === -1) list.push(id)
            else          list.splice(i, 1)
        })
    }

    // Swap a pin with its neighbour (delta -1 = up, +1 = down)
    function move(id, delta) {
        const i = pinned.indexOf(id), j = i + delta
        if (i === -1 || j < 0 || j >= pinned.length) return
        _store.update(list => { list[i] = list[j]; list[j] = id })
    }

    property JsonStore _store: JsonStore {
        path:            Paths.userData("app_pins.json")
        defaults:        []
        createIfMissing: false
    }
}
