pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"
import "../services/"

// ============================================================
// ToastState — the notification toast queue, shared by every screen.
//
// One toast at a time: new notifications queue up behind the current one.
// Each toast shows for 5s (or until dismissed or closed), on the monitor
// that was focused when it appeared. Both hosts render it from here:
// popups/NotificationToast.qml (legacy) and the right notch of
// DynamicSurface. Drives Popups.notificationToastOpen.
// ============================================================

Singleton {
    id: root

    property var    current: null    // the notification on screen, null = none
    property var    queue:   []
    property bool   showing: false   // true while the toast is fully shown (not sliding)
    property string screen:  ""      // monitor the current toast is shown on

    readonly property int duration: 5000

    function isOn(screenName: string): bool {
        return root.current !== null && (root.screen === "" || root.screen === screenName)
    }

    function dismiss() {
        autoTimer.stop()
        root.showing = false
        Popups.hideToast()
        slideOutTimer.restart()
    }

    function _start(n) {
        root.current = n
        root.screen  = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        root.showing = false
        slideInTimer.restart()
        Popups.hideToast()
    }

    property Connections _service: Connections {
        target: NotificationService
        function onNotificationAdded(n) {
            if (!n || !n.tracked) return
            if (root.current === null) root._start(n)
            else root.queue = [...root.queue, n]
        }
    }

    property Connections _closed: Connections {
        target:               root.current
        ignoreUnknownSignals: true
        function onClosed() { root.dismiss() }
    }

    // Lets the window or notch appear before the slide-in starts.
    property Timer _slideInTimer: Timer {
        id: slideInTimer
        interval: 30
        onTriggered: {
            root.showing = true
            Popups.showToast()
            autoTimer.restart()
        }
    }

    property Timer _autoTimer: Timer {
        id: autoTimer
        interval: root.duration
        onTriggered: root.dismiss()
    }

    property Timer _slideOutTimer: Timer {
        id: slideOutTimer
        interval: Theme.animDuration + 20
        onTriggered: {
            if (root.queue.length > 0) {
                const next = root.queue[0]
                root.queue = root.queue.slice(1)
                root._start(next)
            } else {
                root.current = null
                root.screen  = ""
            }
        }
    }
}
