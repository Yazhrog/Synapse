// Contract test: facts that live in two places and must agree.
//
//   1. Every action in src/config/keybind-defaults.json has an IpcHandler with
//      that target (the generated Hyprland binds call `qs ipc call <key>`).
//   2. Every IpcHandler target is a keybind action, or listed in
//      `ipcOnly` below (targets called by other means, e.g. media keys).
//   3. IPC targets are unique.
//   4. The popup manifest (app/PopupManifest.qml): unique keys, a known
//      region, a component, size() and place() that return a size and a
//      rect, a pageProp that is a Popups property, a defaultPagePref that
//      is a pref.
//
// Run by tests/smoke.sh; prints CONTRACTS OK, or one FAIL line per problem.
// #145 extends it to every registry (actions, pages, tiles, bar widgets).
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.app
import qs.src.services.data
import qs.src.state
ShellRoot {
    id: root

    // IPC targets that are not keybind actions on purpose.
    readonly property var ipcOnly: ["quickcontrols-show"]

    PopupManifest { id: manifest }

    readonly property var regions: ["top", "right", "leftCenter", "rightCenter", "bottomCenter", "bottomRight"]

    // What a spec's functions read from the DynamicSurface, at scale 1.
    readonly property var fakeSurface: ({
        px: v => Math.round(v), borderWidth: 2, notchRadius: 16, notchHeight: 34,
        notchBottom: 34, cornerRadius: 12, framed: true, width: 1920, height: 1080
    })

    function popupFails(): var {
        const out = [], keys = {}
        const list = manifest.popups
        if (list.length === 0) out.push("app/PopupManifest.qml lists no popup")
        for (let i = 0; i < list.length; i++) {
            const p = list[i], k = p.key
            if (keys[k]) out.push("popup '" + k + "' is listed twice")
            keys[k] = true
            if (regions.indexOf(p.region) < 0) out.push("popup '" + k + "' has unknown region '" + p.region + "'")
            if (!p.component) out.push("popup '" + k + "' has no component")
            const sz = p.size(fakeSurface, null)
            if (!sz || sz.length !== 2 || !(sz[0] > 0) || !(sz[1] > 0)) out.push("popup '" + k + "' size() is not [w, h] > 0")
            const r = p.place(fakeSurface, 900, 500)
            if (!r || !(r.width > 0) || !(r.height > 0)) out.push("popup '" + k + "' place() is not a rect")
            if (p.pageProp !== "" && typeof Popups[p.pageProp] !== "string")
                out.push("popup '" + k + "' pageProp '" + p.pageProp + "' is not a Popups property")
            if (p.defaultPagePref !== "" && !(p.defaultPagePref in PrefsService.defaults))
                out.push("popup '" + k + "' defaultPagePref '" + p.defaultPagePref + "' is not a pref")
        }
        return out
    }

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
        for (const f of popupFails()) fails.push(f)

        for (const f of fails) console.log("FAIL " + f)
        if (fails.length === 0)
            console.log("CONTRACTS OK (" + actions.length + " actions, " + targets.length + " IPC targets, "
                        + manifest.popups.length + " popups)")
        Qt.quit()
    }
}
