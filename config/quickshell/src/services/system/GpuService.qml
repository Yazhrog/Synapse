pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// GpuService — Intel iGPU frequency (sysfs rps files) and NVIDIA dGPU usage
// (nvidia-smi, only when EnvyControl isn't on "integrated"), every second
// while watched (System page).
//   igpu: freqPercent (act / max × 100), curMhz, maxMhz
//   dgpu: active, usagePercent, usedVram, totalVram
Singleton {
    id: root

    readonly property string envyMode: GpuModeService.currentMode

    property QtObject igpu: QtObject {
        property real   freqPercent: 0
        property string curMhz:      "— MHz"
        property string maxMhz:      "— MHz"
    }

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
    }

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    property real _maxMhz: 0

    Exec {
        id: actRead
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_act_freq_mhz"]
        onSucceeded: out => {
            const a = parseFloat(out.trim())
            if (isNaN(a)) return
            root.igpu.curMhz = a + " MHz"
            if (root._maxMhz > 0) root.igpu.freqPercent = Math.round(a / root._maxMhz * 100)
        }
    }

    Exec {
        id: maxRead
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_max_freq_mhz"]
        onSucceeded: out => {
            const m = parseFloat(out.trim())
            if (isNaN(m)) return
            root._maxMhz     = m
            root.igpu.maxMhz = m + " MHz"
        }
    }

    Exec {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total",
                  "--format=csv,noheader,nounits"]
        parse: SysInfo.parseNvidiaUsage
        onSucceeded: u => {
            if (!u) return
            root.dgpu.active       = true
            root.dgpu.usagePercent = u.usage
            root.dgpu.usedVram     = u.usedMb + " MB"
            root.dgpu.totalVram    = u.totalMb + " MB"
        }
    }

    Poller { interval: 1000; running: root.watched; onTick: { actRead.run(); maxRead.run() } }
    Poller { interval: 1000; running: root.watched && root.envyMode !== "integrated"; onTick: nvidia.run() }

    // The dGPU is off in integrated mode
    onEnvyModeChanged: {
        if (envyMode !== "integrated") return
        dgpu.active       = false
        dgpu.usagePercent = 0
        dgpu.usedVram     = "— MB"
        dgpu.totalVram    = "— MB"
    }
}
