pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// ============================================================
// BluetoothService — the adapter and devices through bluetoothctl, shared by
// the bar icon, the Quick Settings tile and the network popup's Bluetooth tab.
//
// Power, paired / connected / known devices are read at startup and every
// 5 s. Devices found by a scan (8 s, from the tab) join the list until they
// are paired or the adapter is turned off.
// Device: { mac, name, paired, connected, iconType }.
// ============================================================

Singleton {
    id: root

    property bool   powered:       false
    property var    devices:       []
    property bool   scanning:      false
    property string actionMac:     ""      // device being connected / paired / disconnected
    property string removingMac:   ""      // device being removed

    readonly property var paired:    devices.filter(function(d) { return d.paired })
    readonly property var available: devices.filter(function(d) { return !d.paired })
    readonly property var connectedDevices: devices.filter(function(d) { return d.connected })
    readonly property bool   connected:     connectedDevices.length > 0
    readonly property string connectedName: connected ? connectedDevices[0].name : ""

    // ── Actions ─────────────────────────────────────────────────────────────
    function refresh() {
        if (listProc.running) return
        listProc.running = true
    }

    function setPower(on) {
        powered = on
        if (!on) devices = []
        powerProc.command = ["bluetoothctl", "power", on ? "on" : "off"]
        powerProc.running = false; powerProc.running = true
    }

    function togglePower() { setPower(!powered) }

    // Starts an 8 s scan, or stops the running one.
    function toggleScan() {
        if (!powered) return
        if (scanning) {
            scanning = false
            scanProc.running = false
            scanPollTimer.stop()
            refresh()
            return
        }
        scanning = true
        scanProc.running = false; scanProc.running = true
        scanPollTimer.restart()
    }

    function connect(mac) {
        actionMac = mac
        actionProc.command = ["bluetoothctl", "connect", mac]
        actionProc.running = false; actionProc.running = true
    }

    function disconnect(mac) {
        actionMac = mac
        actionProc.command = ["bluetoothctl", "disconnect", mac]
        actionProc.running = false; actionProc.running = true
    }

    // Trusts and pairs; `pin` answers a legacy PIN prompt ("" = confirm "yes").
    function pair(mac, pin) {
        actionMac = mac
        var answer = pin !== "" ? pin : "yes"
        actionProc.command = ["bash", "-c",
            "(echo 'default-agent'; echo 'trust " + mac + "'; echo 'pair " + mac + "'; sleep 1; echo '" + answer + "'; sleep 4) | timeout 12 bluetoothctl 2>/dev/null"]
        actionProc.running = false; actionProc.running = true
    }

    function remove(mac) {
        removingMac = mac
        removeProc.command = ["bash", "-c",
            "bluetoothctl untrust " + mac + " 2>/dev/null; " +
            "bluetoothctl disconnect " + mac + " 2>/dev/null; " +
            "bluetoothctl remove " + mac + " 2>/dev/null"]
        removeProc.running = false; removeProc.running = true
    }

    function openSettings() { bluemanProc.running = false; bluemanProc.running = true }

    // ── Device icons ────────────────────────────────────────────────────────
    function iconFromName(name) {
        var n = name.toLowerCase()
        if (n.match(/head(phone|set)|earphone|earpad|airpod|buds|wf-|wh-|ep-|tws/)) return "headphone"
        if (n.match(/speaker|soundbar|boom|jbl|bose|harman|charge|flip|pulse/))      return "speaker"
        if (n.match(/keyboard|kbd/))                                                   return "keyboard"
        if (n.match(/mouse|trackpad|trackball|mx master|mx anywhere/))                return "mouse"
        if (n.match(/phone|iphone|android|galaxy|pixel|oneplus|xperia|redmi/))        return "phone"
        if (n.match(/macbook|laptop|thinkpad|xps|zenbook|surface/))                   return "laptop"
        if (n.match(/watch|band|garmin|fitbit|amazfit|mi band|polar/))                return "watch"
        if (n.match(/controller|gamepad|dualshock|dualsense|xbox|joycon|steam/))      return "gamepad"
        if (n.match(/tv |television|bravia|smart-tv/))                                 return "tv"
        return "default"
    }

    function glyph(t) {
        switch (t) {
            case "headphone": return "󰋋"
            case "speaker":   return "󰓃"
            case "keyboard":  return "󰌌"
            case "mouse":     return "󰍽"
            case "phone":     return "󰄜"
            case "laptop":    return "󰌢"
            case "watch":     return "󰢗"
            case "gamepad":   return "󰊖"
            case "tv":        return "󰔮"
            default:          return "󰂯"
        }
    }

    // ── Parsing ─────────────────────────────────────────────────────────────
    function _parse(raw) {
        var lines = raw.split("\n")
        var mode = ""; var paired = {}; var conn = {}; var known = {}

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "POWERED:")   { mode = "powered";   continue }
            if (line === "PAIRED:")    { mode = "paired";    continue }
            if (line === "CONNECTED:") { mode = "connected"; continue }
            if (line === "ALL:")       { mode = "all";       continue }
            if (line === "")           continue

            if (mode === "powered")   { root.powered = line.toLowerCase() === "yes"; continue }
            if (mode === "paired")    { paired[line] = true; continue }
            if (mode === "connected") { conn[line]   = true; continue }
            if (mode === "all") {
                var parts = line.split(" ")
                if (parts.length < 3 || parts[0] !== "Device") continue
                var mac = parts[1]; var name = parts.slice(2).join(" ")
                if (mac && name) known[mac] = name
            }
        }

        var seenMac = {}; var devs = []
        for (var m in known) {
            seenMac[m] = true
            devs.push({ mac: m, name: known[m], paired: !!paired[m], connected: !!conn[m], iconType: iconFromName(known[m]) })
        }
        // Keep devices a scan found that bluetoothctl no longer lists
        var existing = root.devices
        for (var j = 0; j < existing.length; j++) {
            var d = existing[j]
            if (seenMac[d.mac]) continue
            seenMac[d.mac] = true
            devs.push({ mac: d.mac, name: d.name, paired: !!paired[d.mac], connected: !!conn[d.mac], iconType: d.iconType })
        }
        root.devices = root.powered ? devs : []
    }

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["bash", "-c",
            "echo 'POWERED:'; " +
            "bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}'; " +
            "echo 'PAIRED:'; " +
            "bluetoothctl devices Paired    2>/dev/null | awk '{print $2}'; " +
            "echo 'CONNECTED:'; " +
            "bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'; " +
            "echo 'ALL:'; " +
            "bluetoothctl devices           2>/dev/null"]
        running: false
        stdout: StdioCollector { onStreamFinished: root._parse(text) }
    }

    // Scan — commands piped into an interactive bluetoothctl
    Process {
        id: scanProc
        command: ["bash", "-c",
            "trap 'echo scan off | bluetoothctl 2>/dev/null' EXIT; " +
            "(echo 'power on'; echo 'scan on'; sleep 8) | timeout 9 bluetoothctl 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var m = line.match(/\[NEW\]\s+Device\s+([0-9A-Fa-f:]{17})\s+(.+)/)
                if (!m) return
                var mac = m[1]; var name = m[2].trim()
                var devs = root.devices.slice()
                for (var i = 0; i < devs.length; i++) if (devs[i].mac === mac) return
                devs.push({ mac: mac, name: name, paired: false, connected: false, iconType: root.iconFromName(name) })
                root.devices = devs
            }
        }
        onRunningChanged: if (!running) { root.scanning = false; scanPollTimer.stop(); root.refresh() }
    }

    Timer { id: scanPollTimer; interval: 2000; repeat: true; running: false; onTriggered: root.refresh() }

    Process { id: actionProc; command: []; running: false
        onRunningChanged: if (!running) { root.actionMac = ""; root.refresh() } }

    Process { id: removeProc; command: []; running: false
        onRunningChanged: if (!running) { root.removingMac = ""; root.refresh() } }

    Process { id: powerProc; command: []; running: false
        onRunningChanged: if (!running) root.refresh() }

    Process { id: bluemanProc; command: ["blueman-manager"]; running: false }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer { interval: 5000; repeat: true; running: true; onTriggered: if (!root.scanning) root.refresh() }

    Component.onCompleted: refresh()
}
