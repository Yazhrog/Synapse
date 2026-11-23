pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
// ─────────────────────────────────────────────────────────────
// NotificationService — the shell's notification server (global singleton).
// `dnd` (Do Not Disturb) drops incoming notifications, except the battery
// warnings; ShellState.dnd mirrors it.
// ─────────────────────────────────────────────────────────────
NotificationServer {
    id: root

    property bool dnd: false

    bodyMarkupSupported:   true
    bodySupported:         true
    actionsSupported:      true
    keepOnReload:          true
    
    signal notificationAdded(var notification)
    
    property var list: []
    readonly property int count: list.length

    property bool _ready: false
    
    // Assign the Timer to a named property to avoid the default property error
    property Timer _startupTimer: Timer {
        interval: 500 
        running: true
        onTriggered: root._ready = true
    }
    
    onNotification: function(n) {
        n.tracked = true

        if (root.list.includes(n)) return 

        root.list = [n, ...root.list]

        // Connected before the DND check, so a notification closed while DND
        // is on still leaves the list.
        n.onClosed.connect(function() {
            root.list = root.list.filter(function(x) { return x !== n })
        })

        if (root.dnd && n.appName !== "Synapse Battery") return

        if (root._ready) {
            root.notificationAdded(n)
        }
    }

    function dismissAll() {
        if (!root.list) return
        const list = [...root.list]
        for (const n of list) n.dismiss()
    }
}
