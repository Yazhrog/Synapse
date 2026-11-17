pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// ============================================================
// QuickToggleService — state and actions of the Quick Settings toggles that
// have no service of their own: Night Light (sunsetr), Caffeine
// (wayland-idle-inhibitor) and Airplane Mode (rfkill).
//
// Checked at startup, airplane polled every 5 s, so the state is right before
// the dashboard is ever opened and anything (e.g. the bar) can read it
// (ShellState.airplane mirrors airplaneOn). Wi-Fi and Bluetooth live in
// WifiService and BluetoothService, the hotspot in HotspotService, the screen
// shader in ScreenFilterService.
// ============================================================

Singleton {
    id: root

    // ── Night Light (sunsetr — schedule-aware colour temperature daemon) ────
    property bool nightLightOn: false

    function toggleNightLight() {
        if (nightLightOn) {
            nlRun.cancel(); nlKill.run()
        } else {
            if (!nlRun.busy) nlRun.run()
            nightLightOn = true
        }
    }

    Exec { id: nlCheck
        command: ["bash", "-c", "sunsetr status 2>&1 | grep -q ERROR && echo off || echo on"]
        onSucceeded: out => root.nightLightOn = out.trim() === "on" }
    Exec { id: nlRun; command: ["sunsetr", "-b"] }
    Exec { id: nlKill; command: ["sunsetr", "stop"]; onFinished: root.nightLightOn = false }

    // ── Caffeine (inhibits the Wayland idle protocol, so hypridle stops firing)
    property bool caffeineOn: false

    function toggleCaffeine() {
        if (caffeineOn) {
            caffeineRun.cancel()
            caffeineKill.run()
        } else {
            caffeineRun.run()
            caffeineVerifyTimer.restart()
        }
    }

    // pgrep exits 1 when nothing matches: "off", not an error
    Exec { id: caffeineCheck
        command: ["pgrep", "-f", "wayland-idle-inhibitor.py"]
        onFinished: root.caffeineOn = lastOutput.trim() !== "" }
    Exec { id: caffeineRun
        command: ["python3", Paths.shellDir + "/src/scripts/wayland-idle-inhibitor.py"] }
    Exec { id: caffeineKill
        command: ["pkill", "-f", "wayland-idle-inhibitor.py"]
        onFinished: root.caffeineOn = false }
    Timer { id: caffeineVerifyTimer; interval: 400; repeat: false
        onTriggered: { root.caffeineOn = false; caffeineCheck.run() } }

    // ── Airplane Mode (rfkill) ──────────────────────────────────────────────
    property bool airplaneOn: false

    function toggleAirplane() {
        if (airplaneOn) airplaneOff.run()
        else            airplaneOnExec.run()
    }

    Exec { id: airplaneCheck
        command: ["bash", "-c",
            // Airplane = ALL radios soft-blocked. `nmcli radio wifi off` blocks
            // only wifi, so count devices that are NOT blocked; zero = airplane.
            "notBlocked=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked: no');" +
            " total=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked:');" +
            " [ \"$total\" -gt 0 ] && [ \"$notBlocked\" -eq 0 ] && echo yes || echo no"]
        onSucceeded: out => root.airplaneOn = out.trim() === "yes" }
    Exec { id: airplaneOnExec; command: ["rfkill", "block", "all"]; onFinished: root.airplaneOn = true }
    Exec { id: airplaneOff; command: ["rfkill", "unblock", "all"]; onFinished: root.airplaneOn = false }

    // ── Polling ─────────────────────────────────────────────────────────────
    Poller { interval: 5000; running: true; onTick: airplaneCheck.run() }

    Component.onCompleted: {
        nlCheck.run()
        caffeineCheck.run()
    }
}
