pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// ============================================================
// WifiService — Wi-Fi and wired status through nmcli, shared by the bar
// icon, the Quick Settings tile and the network popup's Wi-Fi tab.
//
// Status (radio, active SSID and signal, ethernet, connectivity) is read at
// startup and every 5 s. The network list is only scanned on request (the
// Wi-Fi tab does it when the popup opens). Connecting first tries a saved
// profile / open network; if nmcli asks for a secret, the network is marked
// as needing a password and `promptSsid` asks the tab to show the field.
// ============================================================

Singleton {
    id: root

    // ── Status ──────────────────────────────────────────────────────────────
    property bool   radioOn:      false     // `nmcli radio wifi` enabled
    property string ssid:         ""        // active network, "" = none
    property int    signal:       0         // active network's signal, 0 = none
    property bool   ethernet:     false     // a wired device is connected
    property string ethernetName: ""        // its connection name
    property string connectivity: "unknown" // full | limited | portal | none | unknown

    readonly property bool limited:
        connectivity === "limited" || connectivity === "portal" || connectivity === "none"

    // ── Network list (Wi-Fi tab) ────────────────────────────────────────────
    property var    networks:      []      // [{ ssid, signal, secured, inUse }]
    property bool   scanning:      false
    property string connectingTo:  ""
    property var    needsPassword: ({})    // ssid → true
    property string promptSsid:    ""      // network whose password field is open

    readonly property var current: {
        for (var i = 0; i < networks.length; i++)
            if (networks[i].inUse) return networks[i]
        return null
    }
    readonly property var available: networks.filter(function(n) { return !n.inUse })

    // ── Status actions ──────────────────────────────────────────────────────
    function poll() {
        radioRead.running   = false; radioRead.running   = true
        activeRead.running  = false; activeRead.running  = true
        wiredRead.running   = false; wiredRead.running   = true
        connRead.running    = false; connRead.running    = true
    }

    // Turns the radio on/off (optimistically) and re-polls once nmcli is done.
    function setRadio(on) {
        radioOn = on
        radioProc.command = ["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off")]
        radioProc.running = false; radioProc.running = true
    }

    // Quick Settings tile: not while the hotspot is using the interface.
    function toggleRadio() {
        if (HotspotService.on || HotspotService.busy) return
        setRadio(!radioOn)
    }

    function openSettings() { nmtuiProc.running = false; nmtuiProc.running = true }

    // ── List actions ────────────────────────────────────────────────────────
    // Clears the connect / password state (the tab does it when the popup opens).
    function resetPrompts() {
        connectingTo  = ""
        promptSsid    = ""
        needsPassword = ({})
    }

    function scan(rescan) {
        if (scanning || !radioOn) return
        scanning = true; networks = []
        scanProc.command = ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list " +
            (rescan ? "--rescan yes" : "--rescan no") + " 2>/dev/null"]
        scanProc.running = false; scanProc.running = true
    }

    function connect(ssid) {
        connectingTo = ssid; promptSsid = ""
        connectProc._ssid = ssid
        connectProc.command = ["bash", "-c",
            "nmcli con up id \"" + ssid + "\" 2>&1 ||" +
            " nmcli dev wifi connect \"" + ssid + "\" 2>&1"]
        connectProc.running = false; connectProc.running = true
    }

    function connectWithPassword(ssid, password) {
        connectingTo = ssid; promptSsid = ""
        var np = Object.assign({}, needsPassword)
        delete np[ssid]
        needsPassword = np
        passProc.command = ["bash", "-c",
            "nmcli dev wifi connect \"" + ssid + "\" password \"" + password + "\" 2>/dev/null"]
        passProc.running = false; passProc.running = true
    }

    function disconnect() {
        actionProc.command = ["bash", "-c",
            "nmcli con down \"$(nmcli -t -f NAME,TYPE con show --active" +
            " | grep ':802-11-wireless' | head -1 | cut -d: -f1)\" 2>/dev/null"]
        actionProc.running = false; actionProc.running = true
    }

    // Deletes every saved profile of that SSID.
    function forget(ssid) {
        actionProc.running = false
        actionProc.command = ["bash", "-c",
            "for uuid in $(nmcli -g UUID,TYPE connection show | awk -F: '$2==\"802-11-wireless\"{print $1}'); do " +
            "if [ \"$(nmcli -g 802-11-wireless.ssid connection show \"$uuid\" 2>/dev/null)\" = \"$1\" ]; then " +
            "nmcli connection delete \"$uuid\"; " +
            "fi; done",
            "--", ssid]
        actionProc.running = true
    }

    // ── Status processes ────────────────────────────────────────────────────
    Process {
        id: radioRead
        command: ["bash", "-c", "nmcli radio wifi"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.radioOn = text.trim() === "enabled" }
    }

    // "yes:<signal>:<ssid>" for the active network, nothing when there is none
    Process {
        id: activeRead
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t === "") { root.signal = 0; root.ssid = ""; return }
                var rest = t.substring(4)
                var c = rest.indexOf(":")
                var s = parseInt(rest.substring(0, c))
                root.signal = isNaN(s) ? 0 : s
                root.ssid   = rest.substring(c + 1).replace(/\\:/g, ":")
            }
        }
    }

    // First connected ethernet device: "ethernet:connected:<connection name>"
    Process {
        id: wiredRead
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n"), name = null
                for (var i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("ethernet:connected:") === 0) {
                        name = lines[i].substring(19).replace(/\\:/g, ":")
                        break
                    }
                }
                root.ethernet     = name !== null
                root.ethernetName = name || ""
            }
        }
    }

    Process {
        id: connRead
        command: ["bash", "-c", "nmcli -t -f CONNECTIVITY general 2>/dev/null | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { var v = text.trim().toLowerCase(); if (v !== "") root.connectivity = v }
        }
    }

    Process { id: radioProc; command: []; running: false
        onRunningChanged: if (!running) root.poll() }

    Process { id: nmtuiProc; command: ["kitty", "--title", "nmtui", "nmtui"]; running: false }

    // ── List processes ──────────────────────────────────────────────────────
    Process {
        id: scanProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                // IN-USE:SSID:SIGNAL:SECURITY — the SSID may hold escaped colons
                var t = line.trim()
                if (t === "") return
                var lastC = t.lastIndexOf(":")
                if (lastC < 0) return
                var security  = t.substring(lastC + 1)
                var t2        = t.substring(0, lastC)
                var secC      = t2.lastIndexOf(":")
                if (secC < 0) return
                var signalStr = t2.substring(secC + 1)
                var t3        = t2.substring(0, secC)
                var firstC    = t3.indexOf(":")
                if (firstC < 0) return
                var inUseStr  = t3.substring(0, firstC)
                var ssid      = t3.substring(firstC + 1).replace(/\\:/g, ":")
                if (ssid === "" || ssid === "--") return
                var inUse   = inUseStr.trim() === "*"
                var signal  = parseInt(signalStr.trim()) || 0
                var secured = security.trim() !== "" && security.trim() !== "--"
                var nets = root.networks.slice()
                var found = false
                for (var i = 0; i < nets.length; i++) {
                    if (nets[i].ssid === ssid) {
                        if (inUse || signal > nets[i].signal)
                            nets[i] = { ssid: ssid, signal: signal, secured: secured, inUse: inUse }
                        found = true; break
                    }
                }
                if (!found) nets.push({ ssid: ssid, signal: signal, secured: secured, inUse: inUse })
                root.networks = nets
            }
        }
        onRunningChanged: if (!running) root.scanning = false
    }

    // First attempt — stderr tells whether a secret is needed
    Process {
        id: connectProc
        command: []
        running: false
        property string _ssid: ""
        stderr: StdioCollector { id: connectStderr }
        onExited: function(code, status) {
            var np = Object.assign({}, root.needsPassword)
            if (code === 0) {
                delete np[connectProc._ssid]
                root.promptSsid = ""
            } else {
                var err = connectStderr.text.toLowerCase()
                if (err.indexOf("secret") >= 0 || err.indexOf("password") >= 0
                        || err.indexOf("no network") < 0) {
                    np[connectProc._ssid] = true
                    root.promptSsid = connectProc._ssid
                }
            }
            root.needsPassword = np
            root.connectingTo  = ""
            root.scan(false)
            root.poll()
        }
    }

    Process {
        id: passProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root.connectingTo = ""
            root.promptSsid   = ""
            root.scan(false)
            root.poll()
        }
    }

    // Disconnect / forget
    Process {
        id: actionProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root.resetPrompts()
            root.scan(false)
            root.poll()
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.poll() }

    Component.onCompleted: poll()
}
