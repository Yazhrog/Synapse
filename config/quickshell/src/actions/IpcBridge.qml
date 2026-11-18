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
        // The handler is wrapped so it has no `modelData` of its own: every
        // property of an IpcHandler is exposed over IPC, and a var can't be.
        delegate: QtObject {
            id: entry
            required property var modelData
            readonly property string key: modelData.key
            property IpcHandler handler: IpcHandler {
                target: entry.key
                function toggle() { Actions.run(entry.key) }
            }
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
