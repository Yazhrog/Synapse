pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.src.state
// IpcBridge — the shell's IPC entry points (`qs ipc call <target> …`).
//
// One IpcHandler per action of the Actions registry, created from it:
// `qs ipc call <key> toggle` runs the action. They live in this singleton so
// that, with one surface per screen, only one handler reacts to a call.
//
// Plus `quickcontrols-show reveal` (volume/brightness keys): shows the Quick
// Controls OSD briefly. It is not an action (no keybind, no toggle). The
// function must not be named "show": that is quickshell's own `qs ipc show`.
Singleton {
    id: root

    property Instantiator _handlers: Instantiator {
        model: Actions.actions
        delegate: IpcHandler {
            required property var modelData
            target: modelData.key
            function toggle() { Actions.run(modelData.key) }
        }
    }

    // ── Quick Controls OSD ───────────────────────────────────────────────────
    // Hovering the OSD keeps it open; check again after another interval.
    property Timer _quickHide: Timer {
        interval: 1800
        onTriggered: Popups.quickHeld ? root._quickHide.restart() : Popups.hideQuick()
    }

    property IpcHandler _quickControls: IpcHandler {
        target: "quickcontrols-show"
        function reveal() {
            Popups.showQuick()
            root._quickHide.restart()
        }
    }
}
