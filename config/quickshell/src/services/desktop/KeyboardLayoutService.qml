pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core
// KeyboardLayoutService — the tiling layout of the focused workspace
// (dwindle, master, monocle, scrolling) and its window count, for the bar's
// layout indicator; cycle() switches the layout through Hypr.
//
// Read with `hyprctl -j activeworkspace` at startup, on every Hyprland event
// and every 4 s (a layout change on an empty workspace sends no event).
Singleton {
    id: root

    readonly property string layout:     _layout       // "" until the first read
    readonly property string numWindows: _numWindows   // "  " when the workspace is empty
    readonly property var    available:  ["dwindle", "master", "monocle", "scrolling"]

    function refresh() { if (!_query.busy) _query.run() }

    // Next (step 1) or previous (step -1) layout; shown at once, before
    // Hyprland confirms it.
    function cycle(step: int) {
        let idx = available.indexOf(_layout)
        if (idx === -1) idx = 0
        idx = (idx + step + available.length) % available.length
        const next = available[idx]
        Hypr.setOptions("general", { layout: next })
        _layout = next
    }

    // ── Implementation ──────────────────────────────────────────────────────
    property string _layout: ""
    property string _numWindows: ""

    property Exec _query: Exec {
        command: ["hyprctl", "-j", "activeworkspace"]
        parse: out => JSON.parse(out)
        onSucceeded: ws => {
            if (ws && ws.tiledLayout) {
                root._layout = ws.tiledLayout.toLowerCase()
                root._numWindows = ws.windows > 0 ? ws.windows.toString() : "  "
            }
        }
    }

    property Connections _events: Connections {
        target: Hyprland
        function onRawEvent(event) { root.refresh() }
    }

    property Poller _safety: Poller { interval: 4000; running: true; onTick: root.refresh() }
}
