pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "nmcli.js" as Nmcli
// ============================================================
// VpnService — WireGuard connections through nmcli, shared by the bar's VPN
// icon and the network popup's VPN tab.
//
//  • One connection at a time: connecting first downs the active one (in the
//    same command, so there is no gap).
//  • No autoconnect: every WireGuard profile gets connection.autoconnect off
//    at startup, so nothing reconnects on boot.
//  • Kill switch (in memory): turning it on downs every active WireGuard
//    connection. nmcli only, no root.
//  • notify-send on connect, disconnect and failure.
// The list is read at startup, then kept fresh while something holds a Lease
// on the service (the network popup, while open): `nmcli monitor`, debounced,
// plus an 8 s poll.
// Connection: { name, active, busy }.
// ============================================================

Singleton {
    id: root

    property var    connections: []
    property bool   loading:     false
    property bool   killSwitch:  false

    // Status for the bar
    property bool   active:      false    // a connection is up
    property bool   connecting:  false
    property string activeName:  ""       // the active (or connecting) connection

    // ── Lease: watch NetworkManager while a view needs fresh data ───────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    // ── Actions ─────────────────────────────────────────────────────────────
    function refresh() {
        if (wgExec.busy) return
        loading = true
        wgExec.run()
    }

    function connect(name) {
        if (connectExec.busy || disconnectExec.busy) return

        // Mark the requested connection and the active one (if any) as busy
        var cons = connections.slice()
        for (var i = 0; i < cons.length; i++) {
            if (cons[i].name === name || cons[i].active)
                cons[i] = { name: cons[i].name, active: cons[i].active, busy: true }
        }
        connections = cons

        connecting = true
        active     = false
        activeName = name

        connectExec._name = name
        // The name is passed as an argument ($1), never pasted into the script.
        connectExec.run(["bash", "-c", _connectCmd, "--", name])
    }

    function disconnect(name) {
        if (connectExec.busy || disconnectExec.busy) return

        var cons = connections.slice()
        for (var i = 0; i < cons.length; i++)
            if (cons[i].name === name)
                cons[i] = { name: cons[i].name, active: cons[i].active, busy: true }
        connections = cons

        disconnectExec._name = name
        disconnectExec.run(["nmcli", "con", "down", name])
    }

    function toggleKillSwitch() {
        killSwitch = !killSwitch
        if (killSwitch && (active || connecting)) {
            killSwitchExec.run(["bash", "-c", _downAllCmd])
            active = false; connecting = false; activeName = ""
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────
    // Downs every active WireGuard connection, then brings up "$1".
    readonly property string _connectCmd: _downAllCmd + "; nmcli con up \"$1\" 2>&1"
    readonly property string _downAllCmd:
        "nmcli -g NAME,TYPE connection show --active" +
        " | awk -F: '$2==\"wireguard\" {print $1}'" +
        " | xargs -r -I {} nmcli connection down \"{}\""

    function _notify(title, body, urgency) {
        notifyExec.run(["notify-send", "--app-name=Synapse", "--urgency=" + urgency,
                        "--icon=network-vpn", title, body])
    }

    // ── Commands ────────────────────────────────────────────────────────────
    // Runs once at startup; safe to re-run.
    Exec {
        id: disableAutoconnectExec
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE con show" +
            " | awk -F: '$2==\"wireguard\"{print $1}'" +
            " | while IFS= read -r name; do" +
            "     nmcli con modify \"$name\" connection.autoconnect no 2>/dev/null;" +
            "   done"]
    }

    Exec {
        id: wgExec
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "con", "show"]
        parse: Nmcli.parseWireguard
        onSucceeded: list => _apply(list)
        onFailed: _apply([])
        function _apply(list) {
            // Busy only while its command still runs
            const connectingName    = connectExec.busy    ? connectExec._name    : ""
            const disconnectingName = disconnectExec.busy ? disconnectExec._name : ""
            const buf = list.map(c => ({ name: c.name, active: c.active,
                                         busy: c.name === connectingName || c.name === disconnectingName }))
            root.connections = buf
            root.loading     = false

            const up = buf.filter(c => c.active)
            root.active     = up.length > 0
            root.connecting = connectExec.busy
            root.activeName = up.length > 0 ? up[0].name : (connectExec.busy ? connectExec._name : "")
        }
    }

    Exec {
        id: connectExec
        property string _name: ""
        onSucceeded: _done(0, "")
        onFailed: (code, err) => _done(code, err)
        function _done(code, err) {
            const cname = _name
            const cons = root.connections.map(c => ({
                name: c.name, active: code === 0 ? c.name === cname : c.active, busy: false }))
            root.connections = cons
            root.connecting  = false

            if (code === 0) {
                root.active     = true
                root.activeName = cname
                root._notify("VPN Connected",
                    "󰦝  " + cname + " is now active.\nYour traffic is encrypted.", "normal")
            } else {
                root.active     = false
                root.activeName = ""
                root._notify("VPN Failed",
                    "Could not connect to " + cname + ".\n" + err.trim(), "critical")
            }
            root.refresh()
        }
    }

    Exec {
        id: disconnectExec
        property string _name: ""
        onFinished: {
            root.connections = root.connections.map(c => ({ name: c.name, active: false, busy: false }))
            root.active      = false
            root.connecting  = false
            root.activeName  = ""
            root._notify("VPN Disconnected", "󰦝  " + _name + " has been disconnected.", "low")
            root.refresh()
        }
    }

    Exec { id: killSwitchExec; onFinished: root.refresh() }

    Exec { id: notifyExec }

    // While watched: follow NetworkManager, debounced
    Exec {
        id: monitorExec
        command: ["nmcli", "monitor"]
        stream:  true
        onLine: monitorDebounce.restart()
    }
    onWatchedChanged: watched ? monitorExec.run() : monitorExec.cancel()
    Timer { id: monitorDebounce; interval: 600; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 8000; repeat: true; running: root.watched; onTriggered: root.refresh() }

    Component.onCompleted: {
        disableAutoconnectExec.run()
        refresh()
    }
}
