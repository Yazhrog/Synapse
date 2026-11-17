pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// BatteryWarningService — low-battery warnings, once per level per discharge
// (one instance, so they fire once whatever the number of monitors).
//   30 / 20 / 10 %  → a desktop notification (notify-send, through the
//                     shell's own NotificationServer, so it shows as a toast)
//   ≤ 5 %           → critical(level): app/App.qml opens the blocking
//                     BatteryCriticalDialog (a service never opens UI itself)
Singleton {
    id: root

    signal critical(int level)

    readonly property real pct:      BatteryService.percent
    readonly property bool charging: BatteryService.charging

    property var  warnedLevels:   []
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
            critical(pct)
            return
        }

        for (var i = 0; i < notifyLevels.length; i++) {
            var lvl = notifyLevels[i]
            if (pct <= lvl && warnedLevels.indexOf(lvl) < 0) {
                warnedLevels = warnedLevels.concat([lvl])
                notify.run(["notify-send", "-a", "Synapse Battery", "-u", urgencyFor(lvl),
                            titleFor(lvl), "Battery at " + pct + "% — consider charging."])
                break
            }
        }
    }

    onPctChanged:      checkWarning()
    onChargingChanged: checkWarning()

    property Exec notify: Exec {}
}
