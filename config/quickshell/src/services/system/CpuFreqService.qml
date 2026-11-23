pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// CpuFreqService — the auto-cpufreq daemon status, the dominant kernel
// governor across cores and the average current frequency, every 2 s while
// watched (System page); and switching the governor.
//   governor (sysfs value), activeProfile ("performance" | "powersave"),
//   daemonActive, busy, curFreqStr ("2.40 GHz")
Singleton {
    id: root

    property string governor:      "—"
    property string activeProfile: "powersave"
    property bool   daemonActive:  false
    property string curFreqStr:    "— GHz"
    readonly property bool busy:   setGov.busy

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    // Writes the governor to every core.
    function setActiveProfile(profile) {
        if (busy) return
        const gov = profile === "performance" ? "performance" : "powersave"
        setGov.run(["sh", "-c", 'echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor', "--", gov])
    }

    function _poll() { govRead.run(); freqRead.run(); daemonRead.run() }

    Exec {
        id: daemonRead
        command: ["systemctl", "is-active", "auto-cpufreq"]
        // "inactive" exits 3: read the output either way
        onFinished: root.daemonActive = lastOutput.trim() === "active"
    }

    Exec {
        id: govRead
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"]
        parse: SysInfo.dominantGovernor
        onSucceeded: g => {
            if (g === "") return
            root.governor      = g
            root.activeProfile = g === "performance" ? "performance" : "powersave"
        }
    }

    Exec {
        id: freqRead
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"]
        parse: SysInfo.averageFreqGhz
        onSucceeded: f => { if (f !== "") root.curFreqStr = f }
    }

    Exec { id: setGov; onFinished: root._poll() }

    Poller { interval: 2000; running: root.watched; onTick: root._poll() }
}
