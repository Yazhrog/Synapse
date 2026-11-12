import QtQuick
import "../../"
import "../../components"
import "clock"

// ClockCard — Clock / Timer / Alarm / Stopwatch.
// The engine lives in ClockState; this card only switches between the views.

StatCard {
    id: root
    padding: 0

    property string _mode: "clock"

    // Back to the clock (the dashboard closed). Running timers, stopwatches
    // and alarms keep going in ClockState.
    function reset() { _mode = "clock" }

    Item {
        anchors.fill: parent

        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }

            ClockView     { anchors.fill: parent; visible: root._mode === "clock" }
            TimerView     { anchors.fill: parent; visible: root._mode === "timer" }
            AlarmView     { anchors.fill: parent; visible: root._mode === "alarm" }
            StopwatchView { anchors.fill: parent; visible: root._mode === "stopwatch" }
        }

        TabSwitcher {
            id: tabs
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            orientation: "horizontal"; divider: false; width: parent.width
            currentPage: root._mode
            model: [
                { key: "clock",     icon: "󰥔", label: "Clock"     },
                { key: "timer",     icon: "󱎫", label: "Timer"     },
                { key: "alarm",     icon: "󰀠", label: "Alarm"     },
                { key: "stopwatch", icon: "󰔚", label: "Stopwatch" }
            ]
            onPageChanged: function(key) { root._mode = key }
        }
    }
}
