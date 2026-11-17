// Contract test: facts that live in two places and must agree.
//
//   1. Every action in src/config/keybind-defaults.json has an IpcHandler with
//      that target (the generated Hyprland binds call `qs ipc call <key>`).
//   2. Every IpcHandler target is a keybind action, or listed in
//      `ipcOnly` below (targets called by other means, e.g. media keys).
//   3. IPC targets are unique.
//
// Run by tests/smoke.sh; prints CONTRACTS OK, or one FAIL line per problem.
// #145 extends it to every registry (actions, pages, tiles, bar widgets).
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.state
ShellRoot {
    id: root

    // IPC targets that are not keybind actions on purpose.
    readonly property var ipcOnly: ["quickcontrols-show"]

    FileView {
        id: defaults
        path: Quickshell.shellDir + "/src/config/keybind-defaults.json"
        blockLoading: true
    }

    function ipcTargets(): var {
        const out = []
        for (const key in IpcManager) {
            const v = IpcManager[key]
            if (v && typeof v === "object" && typeof v.target === "string" && v.target !== "")
                out.push(v.target)
        }
        return out
    }

    Component.onCompleted: {
        const fails = []
        const actions = Object.keys(JSON.parse(defaults.text()))
        const targets = ipcTargets()

        for (const a of actions)
            if (targets.indexOf(a) < 0)
                fails.push("keybind action '" + a + "' has no IpcHandler")
        for (const t of targets)
            if (actions.indexOf(t) < 0 && ipcOnly.indexOf(t) < 0)
                fails.push("IpcHandler '" + t + "' is not in keybind-defaults.json (add it, or to ipcOnly)")
        const seen = {}
        for (const t of targets) {
            if (seen[t]) fails.push("IpcHandler target '" + t + "' is declared twice")
            seen[t] = true
        }
        if (actions.length === 0) fails.push("keybind-defaults.json has no action")
        if (targets.length === 0) fails.push("no IpcHandler found on IpcManager")

        for (const f of fails) console.log("FAIL " + f)
        if (fails.length === 0)
            console.log("CONTRACTS OK (" + actions.length + " actions, " + targets.length + " IPC targets)")
        Qt.quit()
    }
}
