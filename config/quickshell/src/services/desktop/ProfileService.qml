pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "profile.js" as Profile
// ProfileService — who is logged in, in which desktop, and for how long,
// for the dashboard's profile card.
//
// `user` and `desktop` come from the environment ($USER,
// $XDG_CURRENT_DESKTOP, "Hyprland" when unset); `uptime` ("1d 2h 5m") from
// `uptime -p`, read while something holds a Lease (at once, then every
// minute).
Singleton {
    id: root

    readonly property string user:    Quickshell.env("USER") ?? ""
    readonly property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"
    readonly property string uptime:  _uptime

    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }

    // ── Implementation ──────────────────────────────────────────────────────
    property string _uptime: ""

    property LeaseCount _leases: LeaseCount {}

    property Poller _poll: Poller { interval: 60000; running: root.watched; onTick: root._uptimeExec.run() }

    property Exec _uptimeExec: Exec {
        command: ["uptime", "-p"]
        parse: Profile.formatUptime
        onSucceeded: text => { if (text !== "") root._uptime = text }
    }
}
