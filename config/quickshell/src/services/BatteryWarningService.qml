pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

// Single source of truth for low-battery detection — force-instantiated once
// in shell.qml so thresholds fire exactly once, regardless of monitor count.
// 30/20/10% -> a real desktop notification (via notify-send, through the
// shell's own NotificationServer) that auto-dismisses like any other toast.
// <=5% -> a blocking BatteryCriticalDialog the user must acknowledge.

QtObject {
    id: root

    readonly property var  bat:      UPower.displayDevice
    readonly property real pct:      bat.ready ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat.ready
                                     ? (bat.state === UPowerDeviceState.Charging ||
                                        bat.state === UPowerDeviceState.PendingCharge ||
                                        bat.state === UPowerDeviceState.FullyCharged)
                                     : false

    property var  warnedLevels:  []
    property bool criticalWarned: false

    readonly property var notifyLevels: [30, 20, 10]

    function urgencyFor(level) {
        if (level <= 10) return "critical"
        if (level <= 20) return "normal"
        return "low"
    }

    function titleFor(level) {
        return level <= 10 ? "Very Low Battery" : "Low Battery"
    }

    function checkWarning() {
        if (charging) {
            warnedLevels   = []
            criticalWarned = false
            return
        }

        if (pct <= 5 && !criticalWarned) {
            criticalWarned = true
            Popups.showBatteryCritical(pct)
            return
        }

        for (var i = 0; i < notifyLevels.length; i++) {
            var lvl = notifyLevels[i]
            if (pct <= lvl && warnedLevels.indexOf(lvl) < 0) {
                warnedLevels = warnedLevels.concat([lvl])
                notifyProc.command = [
                    "notify-send", "-a", "Synapse Battery",
                    "-u", urgencyFor(lvl),
                    titleFor(lvl),
                    "Battery at " + pct + "% — consider charging."
                ]
                notifyProc.running = true
                break
            }
        }
    }

    onPctChanged:      checkWarning()
    onChargingChanged: checkWarning()

    property Process notifyProc: Process {}
}
