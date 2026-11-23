import QtQuick
import Quickshell
import Quickshell.Hyprland
// SurfaceFullscreen — whether a real fullscreen window is on a screen, for
// DynamicSurface (which hides the frame then, unless it shows something).
//
// Only a real fullscreen window counts, not a maximized one: Hyprland's
// hasfullscreen is true for both, so look at the windows' fullscreen mode
// (a bitmask: 1 maximized, 2 fullscreen).
QtObject {
    id: root

    required property var screen

    readonly property var  _monitor: Hyprland.monitorFor(screen)
    readonly property bool active: {
        const ws = _monitor ? _monitor.activeWorkspace : null
        if (!ws || !ws.hasFullscreen) return false
        const wins = ws.toplevels ? ws.toplevels.values : []
        for (let i = 0; i < wins.length; i++) {
            const ipc = wins[i].lastIpcObject
            if (ipc && ((ipc.fullscreen ?? 0) & 2)) return true
        }
        return false
    }

    // hasFullscreen is only refreshed with the workspace list, and each
    // window's fullscreen mode with the toplevel list.
    property Connections _events: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
            }
        }
    }
}
