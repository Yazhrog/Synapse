pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// MemService — memory use from /proc/meminfo (FileView can't read /proc),
// every 2 s while watched (System page).
Singleton {
    id: root

    property real   usagePercent: 0
    property real   usedGb:       0
    property real   totalGb:      0
    property string usedStr:      "—"
    property string totalStr:     "—"

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    Exec {
        id: read
        command: ["cat", "/proc/meminfo"]
        parse: SysInfo.parseMeminfo
        onSucceeded: m => {
            if (!m) return
            root.totalGb      = m.totalGb
            root.usedGb       = m.usedGb
            root.usagePercent = m.percent
            root.usedStr      = m.usedGb + " GB"
            root.totalStr     = m.totalGb + " GB"
        }
    }

    Poller { interval: 2000; running: root.watched; onTick: read.run() }
}
