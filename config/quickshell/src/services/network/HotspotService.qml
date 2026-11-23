pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// ============================================================
// HotspotService — the Wi-Fi hotspot (nmcli), shared by the Quick Settings
// tile (toggle) and the network popup's Hotspot tab (credentials).
//
// Needs an ethernet connection: toggle() checks it first, and a running
// hotspot is torn down when the cable goes. The Wi-Fi radio is brought up
// for the hotspot and turned back off on stop if it was off before.
// Credentials live in user_data/hotspot.json (a JsonStore, created with the
// defaults when missing and followed when edited by hand).
// ============================================================

Singleton {
    id: root

    property bool   on:       false
    property bool   busy:     false
    property string label:    ""     // tile sublabel: "Active" | "Not on ethernet" | "Failed" | "Ethernet lost" | ""
    readonly property string ssid:     _cfg.data.ssid     || "Synapse"
    readonly property string password: _cfg.data.password || "changeme1"

    property bool   _wifiWasOff: false   // radio was off when the hotspot started; restore on stop
    property string _iface:      "wlan0"

    readonly property string _cfgPath: Paths.userData("hotspot.json")

    // Emitted after the credentials are (re)read from disk, and after a save.
    signal configLoaded()
    signal configSaved()

    // The store follows the file; this tells the tab to take the current values.
    function loadConfig() {
        if (_cfg.ready) Qt.callLater(root.configLoaded)
        else _loadPending = true
    }

    function saveConfig(newSsid, newPassword) {
        _cfg.set({ ssid: newSsid, password: newPassword })
    }

    function toggle() {
        if (busy) return
        busy  = true
        label = ""
        if (on) {
            _stop()
        } else {
            // Check ethernet first, then start
            ethernetCheck.run()
        }
    }

    function _stop() {
        stopExec.run(["bash", "-c",
            "nmcli device disconnect \"$1\" 2>/dev/null; " +
            "nmcli con delete SynapseHotspot 2>/dev/null; true",
            "--", _iface])
    }

    function _start() {
        startExec.run(["bash", "-c",
            // nmcli needs the radio up before it can create an AP connection
            "nmcli radio wifi on 2>/dev/null; " +
            "sleep 1; " +
            "nmcli device disconnect \"$1\" 2>/dev/null; " +
            "nmcli con delete SynapseHotspot 2>/dev/null; " +
            "nmcli device wifi hotspot " +
                "ifname \"$1\" ssid \"$2\" password \"$3\" " +
                "con-name SynapseHotspot 2>&1",
            // Interface, SSID and password as arguments, never pasted into the script
            "--", _iface, ssid, password])
    }

    function _checkActive() { activeCheck.run() }

    // ── Credentials ─────────────────────────────────────────────────────────
    property bool _loadPending: false

    property JsonStore _cfg: JsonStore {
        path:     root._cfgPath
        defaults: ({ ssid: "Synapse", password: "changeme1" })
        watch:    true
        onLoaded: if (root._loadPending) { root._loadPending = false; root.configLoaded() }
        onSaved:  root.configSaved()
        onFailed: root.configSaved()
    }

    // ── Interface and status ────────────────────────────────────────────────
    Exec {
        id: ifaceExec
        command: ["bash", "-c",
            "nmcli -g DEVICE,TYPE dev 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'"]
        onSucceeded: out => { const n = out.trim(); if (n !== "") root._iface = n }
    }

    Exec {
        id: activeCheck
        command: ["bash", "-c",
            "nmcli -t -f NAME,STATE,DEVICE con show --active 2>/dev/null" +
            " | awk -F: '$1~/[Hh]otspot/{found=1} END{print found+0}'"]
        onSucceeded: out => {
            root.on    = parseInt(out.trim()) > 0
            root.label = root.on ? "Active" : ""
        }
    }

    // ── Start / stop ────────────────────────────────────────────────────────
    // grep -c exits 1 when it counts 0: "|| true" keeps that a success.
    Exec {
        id: ethernetCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected' || true"]
        onSucceeded: out => {
            if (!(parseInt(out.trim()) > 0)) {
                root.label = "Not on ethernet"
                root.busy  = false
                return
            }
            root._wifiWasOff = !WifiService.radioOn
            root._start()
        }
        onFailed: root.busy = false
    }

    Exec {
        id: startExec
        onSucceeded: {
            root.on    = true
            root.label = "Active"
        }
        onFailed: {
            root.on    = false
            root.label = "Failed"
            labelResetTimer.restart()
        }
        onFinished: {
            root.busy = false
            // Re-check the actual state after nmcli exits
            root._checkActive()
        }
    }

    Exec {
        id: stopExec
        onFinished: {
            root.busy = false
            root.on   = false
            if (root._wifiWasOff) {
                // The radio was off before the hotspot started: turn it back off
                WifiService.setRadio(false)
                root._wifiWasOff = false
            } else {
                WifiService.poll()
            }
        }
    }

    Timer { id: labelResetTimer; interval: 3000; repeat: false
        onTriggered: if (root.label === "Failed") root.label = "" }

    // Tears the hotspot down when ethernet goes away
    Exec {
        id: ethernetLiveCheck
        command: ethernetCheck.command
        onSucceeded: out => {
            if (!root.on || root.busy) return
            if (!(parseInt(out.trim()) > 0)) {
                root.label = "Ethernet lost"
                root.busy  = true
                root._stop()
                labelResetTimer.restart()
            }
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root._checkActive()
            if (root.on && !root.busy) {
                ethernetLiveCheck.run()
            }
        }
    }

    Component.onCompleted: {
        ifaceExec.run()
        _checkActive()
    }
}
