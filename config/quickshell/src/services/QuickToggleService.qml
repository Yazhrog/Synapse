pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// QuickToggleService — state and actions of the Quick Settings toggles that
// have no service of their own: Night Light (sunsetr), Caffeine
// (wayland-idle-inhibitor) and Airplane Mode (rfkill).
//
// Checked at startup and polled every 5 s, so the state is right before
// the dashboard is ever opened and anything (e.g. the bar) can read it.
// Mirrors airplane into ShellState. Wi-Fi and Bluetooth live in WifiService
// and BluetoothService, the hotspot in HotspotService, the screen shader in
// ScreenFilterService.
// ============================================================

Singleton {
    id: root

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
        onTriggered: { airplaneCheck.running = false; airplaneCheck.running = true }
    }

    Component.onCompleted: {
        nlCheck.running       = true
        caffeineCheck.running = true
        airplaneCheck.running = true
    }
}
