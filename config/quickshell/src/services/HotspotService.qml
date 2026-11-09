pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// HotspotService — the Wi-Fi hotspot (nmcli), shared by the Quick Settings
// tile (toggle) and the network popup's Hotspot tab (credentials).
//
// Needs an ethernet connection: toggle() checks it first, and a running
// hotspot is torn down when the cable goes. The Wi-Fi radio is brought up
// for the hotspot and turned back off on stop if it was off before.
// Credentials live in user_data/hotspot.json; mirrors `on` into ShellState.hotspot.
// ============================================================

Singleton {
    id: root

    property bool   on:       false
    property bool   busy:     false
    property string label:    ""     // tile sublabel: "Active" | "Not on ethernet" | "Failed" | "Ethernet lost" | ""
    property string ssid:     "Synapse"
    property string password: "changeme1"

    property bool   _wifiWasOff: false   // radio was off when the hotspot started; restore on stop
    property string _iface:      "wlan0"

    readonly property string _cfgPath: Paths.userData("hotspot.json")

    // Emitted after the credentials are (re)read from disk, and after a save.
    signal configLoaded()
    signal configSaved()

    function loadConfig() { cfgLoadProc.running = false; cfgLoadProc.running = true }

    function saveConfig(newSsid, newPassword) {
        ssid = newSsid; password = newPassword
        var j = JSON.stringify({ ssid: newSsid, password: newPassword })
        cfgSaveProc.command = ["bash", "-c",
            "printf '%s' " + Paths.shellQuote(j) + " > " + Paths.shellQuote(_cfgPath)]
        cfgSaveProc.running = false; cfgSaveProc.running = true
    }

    function toggle() {
        if (busy) return
        busy  = true
        label = ""
        if (on) {
            _stop()
        } else {
            // Check ethernet first, then start
            ethernetCheck.running = false; ethernetCheck.running = true
        }
    }

    function _stop() {
        stopProc.command = ["bash", "-c",
            "nmcli device disconnect \"" + _iface + "\" 2>/dev/null; " +
            "nmcli con delete SynapseHotspot 2>/dev/null; true"]
        stopProc.running = false; stopProc.running = true
    }

    function _start() {
        startProc.command = ["bash", "-c",
            // nmcli needs the radio up before it can create an AP connection
            "nmcli radio wifi on 2>/dev/null; " +
            "sleep 1; " +
            "nmcli device disconnect \"" + _iface + "\" 2>/dev/null; " +
            "nmcli con delete SynapseHotspot 2>/dev/null; " +
            "nmcli device wifi hotspot " +
                "ifname \"" + _iface + "\" " +
                "ssid \"" + ssid + "\" " +
                "password \"" + password + "\" " +
                "con-name SynapseHotspot 2>&1"]
        startProc.running = false; startProc.running = true
    }

    function _checkActive() { activeCheck.running = false; activeCheck.running = true }

    // ── Credentials ─────────────────────────────────────────────────────────
    Process {
        id: cfgLoadProc
        command: ["bash", "-c",
            "[ -f '" + root._cfgPath + "' ] || " +
            "(mkdir -p \"$(dirname '" + root._cfgPath + "')\" && " +
            "printf '%s' '{\"ssid\":\"Synapse\",\"password\":\"changeme1\"}' > '" + root._cfgPath + "'); " +
            "cat '" + root._cfgPath + "'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text.trim())
                    if (o.ssid)     root.ssid     = o.ssid
                    if (o.password) root.password = o.password
                } catch(e) {}
                root.configLoaded()
            }
        }
    }

    Process {
        id: cfgSaveProc; command: []; running: false
        onRunningChanged: if (!running) root.configSaved()
    }

    // ── Interface and status ────────────────────────────────────────────────
    Process {
        id: ifaceProc
        command: ["bash", "-c",
            "nmcli -g DEVICE,TYPE dev 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { var n = text.trim(); if (n !== "") root._iface = n }
        }
    }

    Process {
        id: activeCheck
        command: ["bash", "-c",
            "nmcli -t -f NAME,STATE,DEVICE con show --active 2>/dev/null" +
            " | awk -F: '$1~/[Hh]otspot/{found=1} END{print found+0}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.on            = parseInt(text.trim()) > 0
                ShellState.hotspot = root.on
                root.label         = root.on ? "Active" : ""
                // The Wi-Fi interface is owned by the hotspot
                if (root.on) ShellState.wifiOn = false
            }
        }
    }

    // ── Start / stop ────────────────────────────────────────────────────────
    Process {
        id: ethernetCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!(parseInt(text.trim()) > 0)) {
                    root.label = "Not on ethernet"
                    root.busy  = false
                    return
                }
                root._wifiWasOff = !QuickToggleService.wifiOn
                root._start()
            }
        }
    }

    Process {
        id: startProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root.busy = false
            // Re-check the actual state after nmcli exits
            root._checkActive()
        }
        onExited: function(code, status) {
            if (code === 0) {
                root.on            = true
                root.label         = "Active"
                ShellState.hotspot = true
                ShellState.wifiOn  = false
            } else {
                root.on            = false
                root.label         = "Failed"
                ShellState.hotspot = false
                labelResetTimer.restart()
            }
        }
    }

    Process {
        id: stopProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root.busy          = false
            root.on            = false
            ShellState.hotspot = false
            if (root._wifiWasOff) {
                // The radio was off before the hotspot started: turn it back off
                QuickToggleService.setWifiRadio(false)
                root._wifiWasOff = false
            } else {
                ShellState.wifiOn = QuickToggleService.wifiOn
                QuickToggleService.pollWifi()
            }
        }
    }

    Timer { id: labelResetTimer; interval: 3000; repeat: false
        onTriggered: if (root.label === "Failed") root.label = "" }

    // Tears the hotspot down when ethernet goes away
    Process {
        id: ethernetLiveCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.on || root.busy) return
                if (!(parseInt(text.trim()) > 0)) {
                    root.label = "Ethernet lost"
                    root.busy  = true
                    root._stop()
                    labelResetTimer.restart()
                }
            }
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._checkActive()
            if (root.on && !root.busy) {
                ethernetLiveCheck.running = false; ethernetLiveCheck.running = true
            }
        }
    }

    Component.onCompleted: {
        loadConfig()
        ifaceProc.running = true
        _checkActive()
    }
}
