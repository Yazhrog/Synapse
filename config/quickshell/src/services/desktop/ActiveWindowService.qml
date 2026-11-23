pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.core
// ============================================================
// ActiveWindowService — the focused window's name for the centre notch:
// its initialTitle (the app), capitalised, or "Desktop" when nothing is
// focused. Re-read on Hyprland focus / workspace events.
// ============================================================

Singleton {
    id: root

    property string title: "Desktop"

    function refresh() { query.run() }

    Exec {
        id: query
        command: ["hyprctl", "activewindow", "-j"]
        onSucceeded: out => {
            const t = out.trim()
            if (t === "" || t === "Invalid" || t === "{}") { root.title = "Desktop"; return }
            try {
                const name = JSON.parse(t).initialTitle || ""
                // e.g. "kitty" -> "Kitty"
                root.title = name !== "" ? name.charAt(0).toUpperCase() + name.slice(1) : "Desktop"
            } catch (e) {
                root.title = "Desktop"
            }
        }
        onFailed: root.title = "Desktop"
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var triggers = ["workspace", "activewindow", "activespecial", "destroyworkspace", "closewindow", "changefloatingmode"]
            if (triggers.includes(event.name)) root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
