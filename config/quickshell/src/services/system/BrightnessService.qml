pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// BrightnessService — screen brightness through brightnessctl.
//
// `value` is 0..1. set(v) moves it at once and writes it (debounced 50 ms);
// a poll keeps it in step with the brightness keys and other tools, once a
// second, or every 100 ms while `fastPoll` is on (the Quick Controls OSD
// turns it on while it's shown).
// ============================================================

Singleton {
    id: root

    property real value:    0.72
    property int  max:      100
    property bool fastPoll: false
    property bool _busy:    false

    function set(v) {
        value = Math.max(0.0, Math.min(1.0, v))
        _debounce.restart()
    }

    Process {
        id: readProc
        command: ["bash", "-c", "brightnessctl -m"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.split(",")
                if (p.length >= 5) {
                    var cur = parseInt(p[2]), max = parseInt(p[4])
                    if (max > 0) { root.max = max; root.value = cur / max }
                }
            }
        }
    }

    Process {
        id: writeProc
        command: ["bash", "-c", "brightnessctl set " +
            (Math.round(root.value * root.max) <= 0 ? 2 : Math.round(root.value * root.max))]
        running: false
        onRunningChanged: if (!running) root._busy = false
    }

    Timer {
        id: _debounce
        interval: 50; repeat: false
        onTriggered: { root._busy = true; writeProc.running = true }
    }

    Timer {
        interval: root.fastPoll ? 100 : 1000
        running: true; repeat: true
        onTriggered: if (!root._busy) readProc.running = true
    }

    Component.onCompleted: readProc.running = true
}
