pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services
import "nmcli.js" as Nmcli
// ============================================================
// WifiService — Wi-Fi and wired status through nmcli, shared by the bar
// icon, the Quick Settings tile and the network popup's Wi-Fi tab.
//
// Status (radio, active SSID and signal, ethernet, connectivity) is read at
// startup and every 5 s. The network list is only scanned on request (the
// Wi-Fi tab does it when the popup opens). Connecting first tries a saved
// profile / open network; if nmcli asks for a secret, the network is marked
// as needing a password and `promptSsid` asks the tab to show the field.
// Commands run through Exec (argument lists); nmcli output is parsed by
// nmcli.js (unit-tested).
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
        radioRead.run()
        activeRead.run()
        wiredRead.run()
        connRead.run()
    }

    // Turns the radio on/off (optimistically) and re-polls once nmcli is done.
    function setRadio(on) {
        radioOn = on
        radioExec.run(["nmcli", "radio", "wifi", on ? "on" : "off"])
    }

    // Quick Settings tile: not while the hotspot is using the interface.
    function toggleRadio() {
        if (HotspotService.on || HotspotService.busy) return
        setRadio(!radioOn)
    }

    function openSettings() { nmtuiExec.run() }

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
        scanExec.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list",
                      "--rescan", rescan ? "yes" : "no"])
    }

    function connect(ssid) {
        connectingTo = ssid; promptSsid = ""
        connectExec._ssid = ssid
        // The SSID comes from the scan (anyone nearby picks it): it is passed
        // as an argument ($1), never pasted into the script.
        connectExec.run(["bash", "-c",
            "nmcli con up id \"$1\" 2>&1 || nmcli dev wifi connect \"$1\" 2>&1",
            "--", ssid])
    }

    function connectWithPassword(ssid, password) {
        connectingTo = ssid; promptSsid = ""
        var np = Object.assign({}, needsPassword)
        delete np[ssid]
        needsPassword = np
        passExec.run(["bash", "-c",
            "nmcli dev wifi connect \"$1\" password \"$2\" 2>/dev/null",
            "--", ssid, password])
    }

    function disconnect() {
        actionExec.run(["bash", "-c",
            "nmcli con down \"$(nmcli -t -f NAME,TYPE con show --active" +
            " | grep ':802-11-wireless' | head -1 | cut -d: -f1)\" 2>/dev/null"])
    }

    // Deletes every saved profile of that SSID.
    function forget(ssid) {
        actionExec.run(["bash", "-c",
            "for uuid in $(nmcli -g UUID,TYPE connection show | awk -F: '$2==\"802-11-wireless\"{print $1}'); do " +
            "if [ \"$(nmcli -g 802-11-wireless.ssid connection show \"$uuid\" 2>/dev/null)\" = \"$1\" ]; then " +
            "nmcli connection delete \"$uuid\"; " +
            "fi; done",
            "--", ssid])
    }

    // ── Status commands ─────────────────────────────────────────────────────
    // A failed read counts as empty output, as the old `… 2>/dev/null` did.
    Exec {
        id: radioRead
        command: ["nmcli", "radio", "wifi"]
        onSucceeded: out => root.radioOn = Nmcli.parseRadio(out)
        onFailed: root.radioOn = false
    }

    Exec {
        id: activeRead
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "dev", "wifi"]
        function _apply(out) { const a = Nmcli.parseActive(out); root.signal = a.signal; root.ssid = a.ssid }
        onSucceeded: out => _apply(out)
        onFailed: _apply("")
    }

    Exec {
        id: wiredRead
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]
        function _apply(out) { const n = Nmcli.parseEthernet(out); root.ethernet = n !== null; root.ethernetName = n ?? "" }
        onSucceeded: out => _apply(out)
        onFailed: _apply("")
    }

    Exec {
        id: connRead
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        onSucceeded: out => { const v = Nmcli.parseConnectivity(out); if (v !== "") root.connectivity = v }
    }

    Exec { id: radioExec; onFinished: root.poll() }

    Exec { id: nmtuiExec; command: ["kitty", "--title", "nmtui", "nmtui"] }

    // ── List commands ───────────────────────────────────────────────────────
    Exec {
        id: scanExec
        parse: Nmcli.parseWifiList
        onSucceeded: nets => root.networks = nets
        onFinished: root.scanning = false
    }

    // First attempt — stderr tells whether a secret is needed
    Exec {
        id: connectExec
        property string _ssid: ""
        onSucceeded: _done(true, "")
        onFailed: (code, err) => _done(false, err)
        function _done(ok, err) {
            var np = Object.assign({}, root.needsPassword)
            if (ok) {
                delete np[_ssid]
                root.promptSsid = ""
            } else {
                err = err.toLowerCase()
                if (err.indexOf("secret") >= 0 || err.indexOf("password") >= 0
                        || err.indexOf("no network") < 0) {
                    np[_ssid] = true
                    root.promptSsid = _ssid
                }
            }
            root.needsPassword = np
            root.connectingTo  = ""
            root.scan(false)
            root.poll()
        }
    }

    Exec {
        id: passExec
        onFinished: {
            root.connectingTo = ""
            root.promptSsid   = ""
            root.scan(false)
            root.poll()
        }
    }

    // Disconnect / forget
    Exec {
        id: actionExec
        onFinished: {
            root.resetPrompts()
            root.scan(false)
            root.poll()
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    Poller { interval: 5000; running: true; onTick: root.poll() }
}
