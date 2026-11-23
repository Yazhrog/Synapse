pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// SystemInfoService — the system summary from `fastfetch -c systemstats`
// as [{ key, value }] rows, read again each time something starts holding a
// Lease on it.
Singleton {
    id: root

    readonly property var  rows:    _rows
    readonly property bool loading: _ff.busy

    function refresh() {
        _rows = []
        _ff.run()
    }

    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }

    // ── Implementation ──────────────────────────────────────────────────────
    property var _rows: []

    property LeaseCount _leases: LeaseCount {
        onWatchedChanged: if (watched) root.refresh()
    }

    property Exec _ff: Exec {
        command: ["fastfetch", "-c", "systemstats"]
        parse: SysInfo.parseFastfetch
        onSucceeded: rows => root._rows = rows
    }
}
