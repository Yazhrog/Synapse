pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// EnvyControlService — the GPU mode ("integrated" | "hybrid" | "nvidia")
// from `envycontrol --query`, read at startup and with refresh().
//
// currentMode only ever comes from a query, never set optimistically: the
// switch itself (pkexec, then a reboot) is confirmed and run by
// ConfirmDialog, so a cancelled pkexec leaves the mode unchanged.
Singleton {
    id: root

    property string currentMode: "integrated"
    property bool   busy:        false

    function refresh() { query.run() }

    Exec {
        id: query
        command: ["envycontrol", "--query"]
        onSucceeded: out => {
            const mode = out.trim().toLowerCase()
            if (mode !== "") root.currentMode = mode
        }
    }

    Component.onCompleted: refresh()
}
