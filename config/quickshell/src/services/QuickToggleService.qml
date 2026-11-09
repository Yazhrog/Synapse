pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// QuickToggleService — state and actions of the Quick Settings toggles:
// Wi-Fi radio, Bluetooth power, Night Light (sunsetr), Caffeine
// (wayland-idle-inhibitor) and Airplane Mode (rfkill).
//
// Checked at startup and polled every 5 s, so the state is right before
// the dashboard is ever opened and anything (e.g. the bar) can read it.
// Mirrors wifiOn / btPowered / btConnected / airplane into ShellState.
// The hotspot lives in HotspotService, the screen shader in ScreenFilterService.
// ============================================================

Singleton {
    id: root

    // ── Wi-Fi ───────────────────────────────────────────────────────────────
    property bool   wifiOn:   false
    property string wifiSSID: ""

    function pollWifi() {
        wifiRadioRead.running = false; wifiRadioRead.running = true
        wifiSSIDRead.running  = false; wifiSSIDRead.running  = true
    }

    function toggleWifi() {
        // Do not allow a wifi toggle while the hotspot is using the interface
        if (HotspotService.on || HotspotService.busy) return
        setWifiRadio(!wifiOn)
    }

    // Sets the radio (optimistically) and re-polls once nmcli is done.
    function setWifiRadio(on) {
        wifiOn = on
        ShellState.wifiOn = on && !ShellState.hotspot
        wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off")]
        wifiToggleProc.running = false
        wifiToggleProc.running = true
    }

    Process { id: wifiRadioRead; command: ["bash", "-c", "nmcli radio wifi"]; running: false
        stdout: SplitParser { onRead: function(l) {
            root.wifiOn = l.trim() === "enabled"
            // Suppressed while the hotspot owns the interface
            ShellState.wifiOn = root.wifiOn && !ShellState.hotspot
        } } }
    Process { id: wifiSSIDRead
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.wifiSSID = l.trim() } } }
    Process { id: wifiToggleProc; command: []; running: false
        onRunningChanged: if (!running) root.pollWifi() }

    // ── Bluetooth ───────────────────────────────────────────────────────────
    property bool   btOn:     false
    property string btDevice: ""

    function pollBluetooth() {
        btPowerRead.running  = false; btPowerRead.running  = true
        btDeviceRead.running = false; btDeviceRead.running = true
    }

    function toggleBluetooth() {
        var turningOn = !btOn
        btOn = turningOn                     // optimistic
        // Mirror to ShellState at once so the bar icon reacts
        ShellState.btPowered = turningOn
        if (!turningOn) ShellState.btConnected = false
        btToggleProc.command = ["bash", "-c", "bluetoothctl power " + (turningOn ? "on" : "off")]
        btToggleProc.running = false
        btToggleProc.running = true
    }

    Process { id: btPowerRead
        command: ["bash", "-c",
            "bluetoothctl show 2>/dev/null | grep '^\\s*Powered:' | awk '{print $2}'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btOn = l.trim() === "yes" } } }
    Process { id: btDeviceRead
        command: ["bash", "-c",
            "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btDevice = l.trim() } } }
    Process { id: btToggleProc; command: []; running: false
        onRunningChanged: if (!running) {
            root.pollBluetooth()
            ShellState.btPowered = root.btOn
            if (!root.btOn) ShellState.btConnected = false
        }
    }

    // ── Night Light (sunsetr — schedule-aware colour temperature daemon) ────
    property bool nightLightOn: false

    function toggleNightLight() {
        if (nightLightOn) {
            nlProc.running = false; nlKill.running = false; nlKill.running = true
        } else { nlProc.running = true; nightLightOn = true }
    }

    Process { id: nlCheck
        command: ["bash", "-c", "sunsetr status 2>&1 | grep -q ERROR && echo off || echo on"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.nightLightOn = l.trim() === "on" } } }
    Process { id: nlProc; command: ["sunsetr", "-b"]; running: false }
    Process { id: nlKill; command: ["sunsetr", "stop"]; running: false
        onRunningChanged: if (!running) root.nightLightOn = false }

    // ── Caffeine (inhibits the Wayland idle protocol, so hypridle stops firing)
    property bool caffeineOn: false

    function toggleCaffeine() {
        if (caffeineOn) {
            caffeineProc.running = false
            caffeineKill.running = false; caffeineKill.running = true
        } else {
            caffeineProc.running = false; caffeineProc.running = true
            caffeineVerifyTimer.restart()
        }
    }

    Process { id: caffeineCheck
        command: ["bash", "-c", "pgrep -f wayland-idle-inhibitor.py"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.caffeineOn = true } } }
    Process { id: caffeineProc
        command: ["python3", Paths.shellDir + "/src/scripts/wayland-idle-inhibitor.py"]
        running: false }
    Process { id: caffeineKill
        command: ["bash", "-c", "pkill -f wayland-idle-inhibitor.py"]; running: false
        onRunningChanged: if (!running) root.caffeineOn = false }
    Timer { id: caffeineVerifyTimer; interval: 400; repeat: false
        onTriggered: { root.caffeineOn = false; caffeineCheck.running = false; caffeineCheck.running = true } }

    // ── Airplane Mode (rfkill) ──────────────────────────────────────────────
    property bool airplaneOn: false
    onAirplaneOnChanged: ShellState.airplane = airplaneOn

    function toggleAirplane() {
        if (airplaneOn) {
            airplaneOffProc.running = false; airplaneOffProc.running = true
        } else {
            airplaneOnProc.running = false; airplaneOnProc.running = true
        }
    }

    Process { id: airplaneCheck
        command: ["bash", "-c",
            // Airplane = ALL radios soft-blocked. `nmcli radio wifi off` blocks
            // only wifi, so count devices that are NOT blocked; zero = airplane.
            "notBlocked=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked: no');" +
            " total=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked:');" +
            " [ \"$total\" -gt 0 ] && [ \"$notBlocked\" -eq 0 ] && echo yes || echo no"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.airplaneOn = l.trim() === "yes" } }
    }
    Process { id: airplaneOnProc
        command: ["bash", "-c", "rfkill block all"]; running: false
        onRunningChanged: if (!running) root.airplaneOn = true }
    Process { id: airplaneOffProc
        command: ["bash", "-c", "rfkill unblock all"]; running: false
        onRunningChanged: if (!running) root.airplaneOn = false }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            root.pollWifi(); root.pollBluetooth()
            airplaneCheck.running = false; airplaneCheck.running = true
        }
    }

    Component.onCompleted: {
        pollWifi(); pollBluetooth()
        nlCheck.running       = true
        caffeineCheck.running = true
        airplaneCheck.running = true
    }
}
