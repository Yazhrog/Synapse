pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// PrefsService — central store for shell preferences.
//
// Backed by Paths.userData("shell_prefs.json"). Bind to a pref directly
// (PrefsService.autoUpdate) and assign to change it; the file is saved
// automatically (debounced) and hot-reloaded when edited by hand.
// Missing keys keep their default, so adding a pref never breaks an
// existing file.
//
// Preferences (how the shell behaves) go here. User data (tasks, pins,
// wallpaper, keybinds) stays in its own files.
//
// Adding a pref:
//   1. add its default to `defaults`
//   2. add `property <type> <name>: root.defaults.<name>` to the adapter
//   3. add `property alias <name>: adapter.<name>` below
// ============================================================

Singleton {
    id: root

    readonly property var defaults: ({
        autoUpdate:   true,
        // Dynamic Surface scale: "off" (1.0), "auto" (screen height / 1080)
        // or a fixed factor such as "1.25". Off by default: only the frame and
        // region sizes scale yet, not the popup contents.
        surfaceScale: "off"
    })

    // ── Preferences ────────────────────────────────────────────────────────
    property alias autoUpdate:   adapter.autoUpdate
    property alias surfaceScale: adapter.surfaceScale

    // True once the file has been read (or created). Services that act on a
    // pref at startup should wait for it.
    property bool ready: false
    signal loaded()

    function isDefault(key: string): bool {
        return adapter[key] === root.defaults[key]
    }

    function reset(key: string) {
        if (key in root.defaults)
            adapter[key] = root.defaults[key]
    }

    function resetAll() {
        for (const key in root.defaults)
            adapter[key] = root.defaults[key]
    }

    function _markReady() {
        if (root.ready) return
        root.ready = true
        root.loaded()
    }

    property FileView _file: FileView {
        path: Paths.userData("shell_prefs.json")
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root._markReady()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                root._migrateLegacy()
            else
                console.log("PrefsService: failed to read prefs (" + FileViewError.toString(error) + "), using defaults")
            root._file.writeAdapter()
            root._markReady()
        }
        // Debounced so dragging a slider doesn't write on every tick.
        onAdapterUpdated: root._saveTimer.restart()

        JsonAdapter {
            id: adapter
            property bool   autoUpdate:   root.defaults.autoUpdate
            property string surfaceScale: root.defaults.surfaceScale
        }
    }

    property Timer _saveTimer: Timer {
        interval: 300
        onTriggered: root._file.writeAdapter()
    }

    // First run after the move to shell_prefs.json: carry over the
    // auto-update toggle UpdateService used to keep in update_prefs.json.
    function _migrateLegacy() {
        const raw = root._legacyUpdatePrefs.text()
        if (!raw) return
        try {
            const o = JSON.parse(raw)
            if (typeof o.autoUpdate === "boolean")
                adapter.autoUpdate = o.autoUpdate
        } catch (e) {}
    }

    property FileView _legacyUpdatePrefs: FileView {
        path: Paths.userData("update_prefs.json")
        blockAllReads: true
        printErrors: false
    }
}
