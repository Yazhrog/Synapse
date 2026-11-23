pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// GpuModeService — the GPU mode ("integrated" | "hybrid" | "nvidia") from
// `envycontrol --query`, read at startup and with refresh(), and the switch
// to another mode.
//
// switchTo(mode) runs scripts/GfxSwitch.sh under pkexec, then reboots
// (PowerService). `switching` turns true once pkexec has authenticated (the
// script prints "authenticated" before envycontrol starts), for the
// "Applying changes" card; a cancelled pkexec or a failed switch only ends
// `busy`. currentMode only ever comes from a query, never set optimistically.
// Asking first is the caller's job (ConfirmDialog).
Singleton {
    id: root

    readonly property string currentMode: _currentMode
    readonly property bool   busy:        _switch.busy
    readonly property bool   switching:   _switching
    readonly property string targetMode:  _targetMode

    // Emitted when a switch could not be done (pkexec cancelled, envycontrol failed).
    signal switchFailed(string mode)

    function refresh() { _query.run() }

    function switchTo(mode: string) {
        if (_switch.busy) return
        _targetMode = mode
        _switching = false
        _switch.run(["pkexec", "bash", Quickshell.shellDir + "/src/scripts/GfxSwitch.sh", mode])
    }

    // ── Implementation ──────────────────────────────────────────────────────
    property string _currentMode: "integrated"
    property bool   _switching:   false
    property string _targetMode:  ""

    property Exec _query: Exec {
        command: ["envycontrol", "--query"]
        onSucceeded: out => {
            const mode = out.trim().toLowerCase()
            if (mode !== "") root._currentMode = mode
        }
    }

    property Exec _switch: Exec {
        stream: true
        onLine: text => { if (text.trim() === "authenticated") root._switching = true }
        onSucceeded: PowerService.reboot()
        onFailed: {
            root._switching = false
            root.switchFailed(root._targetMode)
        }
    }

    Component.onCompleted: refresh()
}
