pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// ============================================================
// BrightnessService — screen brightness through brightnessctl.
//
// `value` is 0..1. set(v) moves it at once and writes it (debounced 50 ms);
// a poll keeps it in step with the brightness keys and other tools, once a
// second, or every 100 ms while `fastPoll` is on (the Quick Controls OSD
// turns it on while it's shown). Never written below 2 (a black screen).
// ============================================================

Singleton {
    id: root

    property real value:    0.72
    property int  max:      100
    property bool fastPoll: false

    function set(v) {
        value = Math.max(0.0, Math.min(1.0, v))
        _debounce.restart()
    }

    // `brightnessctl -m`: "device,class,current,percent,max"
    Exec {
        id: readExec
        command: ["brightnessctl", "-m"]
        onSucceeded: out => {
            const p = out.split("\n")[0].split(",")
            if (p.length < 5) return
            const cur = parseInt(p[2]), max = parseInt(p[4])
            if (max > 0) { root.max = max; root.value = cur / max }
        }
    }

    Exec { id: writeExec }

    Timer {
        id: _debounce
        interval: 50; repeat: false
        onTriggered: {
            const n = Math.round(root.value * root.max)
            writeExec.run(["brightnessctl", "set", String(n <= 0 ? 2 : n)])
        }
    }

    Poller {
        interval: root.fastPoll ? 100 : 1000
        running:  true
        onTick: if (!writeExec.busy && !readExec.busy) readExec.run()
    }
}
