pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// DiskService — real block devices from df, every 15 s while watched
// (System page). disks: [{ source, mount, usedPct, usedStr, totalStr }].
Singleton {
    id: root

    property var disks: []

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    Exec {
        id: read
        command: ["df", "-BM", "--output=source,size,used,pcent,target"]
        parse: SysInfo.parseDf
        onSucceeded: list => root.disks = list
        // df exits 1 when one filesystem can't be read but still prints the rest
        onFailed: code => { if (code === 1) root.disks = SysInfo.parseDf(lastOutput) }
    }

    Poller { interval: 15000; running: root.watched; onTick: read.run() }
}
