pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// FanControl — fan mode through nbfc-linux. The mode is assumed "auto" at
// start (set by Hyprland's exec-once). Each command is wrapped in
// `timeout 5`, as nbfc can hang on unavailable sensors.
//   "quiet" → nbfc set -s 30    "auto" → nbfc set -a    "max" → nbfc set -s 100
Singleton {
    id: root

    property string mode: "auto"
    readonly property bool busy: _set.busy

    function setMode(m) {
        if (busy) return
        mode = m
        _set.run(m === "quiet" ? ["timeout", "5", "nbfc", "set", "-s", "30"]
               : m === "max"   ? ["timeout", "5", "nbfc", "set", "-s", "100"]
               :                 ["timeout", "5", "nbfc", "set", "-a"])
    }

    property Exec _set: Exec {}
}
