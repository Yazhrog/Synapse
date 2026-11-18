pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// NetService — up/down speed of the interface carrying the default route,
// from /proc/net/dev every second while watched (System page). The
// interface is re-detected every tick (VPN, cable, network switch); when it
// changes the counters restart, so the first delta isn't a spike.
Singleton {
    id: root

    property string iface:     "—"
    property string upSpeed:   "0 KB/s"
    property string downSpeed: "0 KB/s"

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    property var _prev: null

    Exec {
        id: route
        command: ["ip", "route", "get", "1.1.1.1"]
        parse: SysInfo.parseRouteIface
        onSucceeded: name => {
            if (name !== "" && name !== root.iface) {
                root.iface = name
                root._prev = null
            }
        }
    }

    Exec {
        id: counters
        command: ["cat", "/proc/net/dev"]
        onSucceeded: out => {
            if (root.iface === "—") return
            const c = SysInfo.parseNetDev(out, root.iface)
            if (!c) return
            if (root._prev) {
                root.downSpeed = SysInfo.formatRate(Math.max(0, c.rx - root._prev.rx))
                root.upSpeed   = SysInfo.formatRate(Math.max(0, c.tx - root._prev.tx))
            }
            root._prev = c
        }
    }

    Poller {
        interval: 1000
        running:  root.watched
        onTick: { route.run(); counters.run() }
    }
}
