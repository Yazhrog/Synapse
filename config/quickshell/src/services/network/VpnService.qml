pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

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
// The list is read at startup, then kept fresh while the network popup is
// open (`nmcli monitor`, debounced, plus an 8 s poll).
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

    property var _buf: []

    // ── Actions ─────────────────────────────────────────────────────────────
    function refresh() {
        if (wgProc.running) return
        loading = true
        _buf    = []
        wgProc.running = true
    }

    function connect(name) {
        if (connectProc.running || disconnectProc.running) return

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

        connectProc._name   = name
        connectProc.command = ["bash", "-c", _downAllCmd + "; nmcli con up \"" + name + "\" 2>&1"]
        connectProc.running = false; connectProc.running = true
    }

    function disconnect(name) {
        if (connectProc.running || disconnectProc.running) return

        var cons = connections.slice()
        for (var i = 0; i < cons.length; i++)
            if (cons[i].name === name)
                cons[i] = { name: cons[i].name, active: cons[i].active, busy: true }
        connections = cons

        disconnectProc._name   = name
        disconnectProc.command = ["bash", "-c", "nmcli con down \"" + name + "\" 2>/dev/null"]
        disconnectProc.running = false; disconnectProc.running = true
    }

    function toggleKillSwitch() {
        killSwitch = !killSwitch
        if (killSwitch && (active || connecting)) {
            killSwitchProc.command = ["bash", "-c", _downAllCmd]
            killSwitchProc.running = false; killSwitchProc.running = true
            active = false; connecting = false; activeName = ""
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────
    readonly property string _downAllCmd:
        "nmcli -g NAME,TYPE connection show --active" +
        " | awk -F: '$2==\"wireguard\" {print $1}'" +
        " | xargs -r -I {} nmcli connection down \"{}\""

    function _notify(title, body, urgency) {
        notifyProc.command = ["notify-send", "--app-name=Synapse", "--urgency=" + urgency,
                              "--icon=network-vpn", title, body]
        notifyProc.running = false; notifyProc.running = true
    }

    // ── Processes ───────────────────────────────────────────────────────────
    // Runs once at startup; safe to re-run.
    Process {
        id: disableAutoconnectProc
        command: ["bash", "-c",
            "nmcli -t -f NAME,TYPE con show" +
            " | awk -F: '$2==\"wireguard\"{print $1}'" +
            " | while IFS= read -r name; do" +
            "     nmcli con modify \"$name\" connection.autoconnect no 2>/dev/null;" +
            "   done"]
        running: false
    }

    Process {
        id: wgProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE,ACTIVE con show" +
            " | awk -F: '$2==\"wireguard\"{print $1 \"|\" ($3==\"yes\" ? \"active\" : \"inactive\")}'"]
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (!line) return
                var sep = line.lastIndexOf("|")
                if (sep < 0) return
                root._buf = root._buf.concat([{
                    name:   line.substring(0, sep),
                    active: line.substring(sep + 1) === "active",
                    busy:   false
                }])
            }
        }
        onExited: function(code, status) {
            var buf = root._buf.slice()
            // Busy only while its process still runs
            var connectingName    = connectProc.running    ? connectProc._name    : ""
            var disconnectingName = disconnectProc.running ? disconnectProc._name : ""
            buf.sort(function(a, b) { return a.name.localeCompare(b.name) })
            for (var j = 0; j < buf.length; j++)
                if (buf[j].name === connectingName || buf[j].name === disconnectingName)
                    buf[j].busy = true

            root._buf        = []
            root.connections = buf
            root.loading     = false

            var up = buf.filter(function(c) { return c.active })
            root.active     = up.length > 0
            root.connecting = connectProc.running
            root.activeName = up.length > 0 ? up[0].name : (connectProc.running ? connectProc._name : "")
        }
    }

    Process {
        id: connectProc
        running: false
        command: []
        property string _name: ""
        stderr: StdioCollector { id: connectStderr }
        onExited: function(code, status) {
            var cname = connectProc._name
            var cons = root.connections.slice()
            for (var i = 0; i < cons.length; i++)
                cons[i] = { name: cons[i].name, active: code === 0 ? cons[i].name === cname : cons[i].active, busy: false }
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
                    "Could not connect to " + cname + ".\n" + connectStderr.text.trim(), "critical")
            }
            root.refresh()
        }
    }

    Process {
        id: disconnectProc
        running: false
        command: []
        property string _name: ""
        onExited: function(code, status) {
            var cons = root.connections.slice()
            for (var i = 0; i < cons.length; i++)
                cons[i] = { name: cons[i].name, active: false, busy: false }
            root.connections = cons
            root.active      = false
            root.connecting  = false
            root.activeName  = ""
            root._notify("VPN Disconnected", "󰦝  " + disconnectProc._name + " has been disconnected.", "low")
            root.refresh()
        }
    }

    Process {
        id: killSwitchProc
        running: false
        command: []
        onExited: root.refresh()
    }

    Process { id: notifyProc; running: false; command: [] }

    // While the network popup is open: follow NetworkManager, debounced
    Process {
        id: monitorProc
        running: Popups.networkOpen
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: function(data) { monitorDebounce.restart() } }
    }
    Timer { id: monitorDebounce; interval: 600; repeat: false; onTriggered: root.refresh() }
    Timer { interval: 8000; repeat: true; running: Popups.networkOpen; onTriggered: root.refresh() }

    Component.onCompleted: {
        disableAutoconnectProc.running = true
        refresh()
    }
}
