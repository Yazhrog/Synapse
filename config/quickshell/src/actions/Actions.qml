pragma Singleton
import QtQuick
import Quickshell
// Actions — every user-triggerable command, by key (ARCHITECTURE.md §5.6).
//
//   Actions.run("clipboard-toggle")
//
// `actions` comes from app/ActionManifest.qml (set by App): its own Action
// entries plus one toggle action per popup and per popup page that names an
// `action`. IPC (IpcBridge), keybinds (`qs ipc call <key> toggle`), bar
// buttons and tiles all go through run(). A key is also the
// keybind-defaults.json / keybinds.json key (tests/contracts.qml checks it).
Singleton {
    id: root

    property var actions: []     // [{ key, label, group, run }]

    readonly property var byKey: {
        const m = {}
        for (let i = 0; i < actions.length; i++) m[actions[i].key] = actions[i]
        return m
    }
    readonly property var keys: Array.from(actions, a => a.key)

    function has(key: string): bool { return key in byKey }

    // Runs the action; false (and a warning) for an unknown key.
    function run(key: string): bool {
        const a = byKey[key]
        if (!a) {
            console.warn("Actions: unknown action", key)
            return false
        }
        a.run()
        return true
    }
}
