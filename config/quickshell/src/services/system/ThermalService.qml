pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "sysinfo.js" as SysInfo

// ThermalService — CPU package temperature and fan speeds from `sensors`,
// NVIDIA GPU temperature from nvidia-smi, every 2 s while watched (System
// page). Strings are "—" until read.
Singleton {
    id: root

    property real   cpuTemp:    0
    property real   gpuTemp:    0
    property int    fan1Rpm:    0
    property int    fan2Rpm:    0
    property int    fanCount:   0
    property string cpuTempStr: "—"
    property string gpuTempStr: "—"
    property string fan1Str:    "—"
    property string fan2Str:    "—"

    // ── Lease: polls only while a view shows the data ──────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    Exec {
        id: sensors
        command: ["sensors"]
        // sensors exits 1 when one subfeature can't be read but still prints
        // everything else: use the output whatever the exit code.
        onFinished: {
            if (lastOutput.trim() === "") return
            let s
            try { s = SysInfo.parseSensors(lastOutput) } catch (e) { return }
            if (s.cpuTemp >= 0) {
                root.cpuTemp    = s.cpuTemp
                root.cpuTempStr = s.cpuTemp.toFixed(0) + "°C"
            }
            root.fanCount = s.fans.length
            root.fan1Rpm  = s.fans.length > 0 ? s.fans[0] : 0
            root.fan2Rpm  = s.fans.length > 1 ? s.fans[1] : 0
            root.fan1Str  = s.fans.length > 0 ? s.fans[0] + " RPM" : "—"
            root.fan2Str  = s.fans.length > 1 ? s.fans[1] + " RPM" : "—"
        }
    }

    Exec {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"]
        onSucceeded: out => {
            const t = parseFloat(out.trim())
            if (!isNaN(t)) {
                root.gpuTemp    = t
                root.gpuTempStr = t.toFixed(0) + "°C"
            }
        }
    }

    Poller {
        interval: 2000
        running:  root.watched
        onTick: { sensors.run(); nvidia.run() }
    }
}
