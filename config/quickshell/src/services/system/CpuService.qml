pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// CpuService — CPU usage % from /proc/stat, sampled every second while
// watched (System page). usagePercent: 0–100.
Singleton {
    id: root

    property real usagePercent: 0

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    property var _prev: null

    Exec {
        id: read
        command: ["cat", "/proc/stat"]
        parse: SysInfo.parseCpuStat
        onSucceeded: sample => {
            if (!sample) return
            if (root._prev) {
                const p = SysInfo.cpuPercent(root._prev, sample)
                if (p !== null) root.usagePercent = p
            }
            root._prev = sample
        }
    }

    Poller { interval: 1000; running: root.watched; onTick: read.run() }
}
