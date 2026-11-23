import QtQuick
import QtQuick.Controls
import Quickshell
import qs.src.services.desktop
import qs.src.state
import qs.src.theme
// AppLauncher — scrollable app list + bottom search bar.
// Lives inside DashboardContent on the "launcher" page.
// The surface gets the keyboard while the dashboard is open, but that doesn't
// imply any particular item has Qt-level active focus — the search field takes it below,
// and takes it again whenever the window becomes active, so it doesn't matter
// whether the compositor's focus lands before or after the timer.

Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    readonly property var  apps:    AppsService.apps
    readonly property bool loading: AppsService.loading
    property int  selIndex: -1
    property string query:  ""

    // Pinned apps first (in AppPinService order), then the rest alphabetically.
    // Pins whose .desktop file is gone are skipped, not dropped from the file.
    readonly property var ordered: {
        var byId = {}
        for (var i = 0; i < apps.length; i++) byId[apps[i].id] = apps[i]

        var pins   = AppPinService.pinned
        var pinSet = {}
        var result = []
        for (var p = 0; p < pins.length; p++) {
            var a = byId[pins[p]]
            if (!a || pinSet[a.id]) continue
            pinSet[a.id] = true
            result.push({ id: a.id, name: a.name, exec: a.exec, icon: a.icon, pinned: true })
        }
        for (var j = 0; j < apps.length; j++) {
            var b = apps[j]
            if (pinSet[b.id]) continue
            result.push({ id: b.id, name: b.name, exec: b.exec, icon: b.icon, pinned: false })
        }
        return result
    }

    readonly property var filtered: {
        var q = query.toLowerCase().trim()
        if (q === "") return ordered
        return ordered.filter(function(a) {
            return a.name.toLowerCase().indexOf(q) !== -1
        })
    }

    // Pinned entries are always a prefix of filtered
    readonly property int pinnedCount: {
        var n = 0
        while (n < filtered.length && filtered[n].pinned) n++
        return n
    }

    readonly property var selApp:
        selIndex >= 0 && selIndex < filtered.length ? filtered[selIndex] : null

    // ── Load apps (AppsService, read again each time the launcher is shown) ──
    Connections {
        target: AppsService
        function onListed() { root.selIndex = AppsService.apps.length > 0 ? 0 : -1 }
    }

    onVisibleChanged: {
        if (!visible) return
        root.query     = ""
        root.selIndex  = -1
        searchBar.text = ""
        AppsService.refresh()
        focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: searchBar.focusInput()
    }

    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.visible && root.Window.window && root.Window.window.active)
                searchBar.focusInput()
        }
    }

    // ── Launch ────────────────────────────────────────────────────────────────
    function launch(exec) {
        AppsService.launch(exec)
        Popups.close("dashboard")
    }

    // ── Pin ───────────────────────────────────────────────────────────────────
    // Toggling or moving a pin rebuilds the model, so delegates are recreated
    // under a stationary cursor and fire onEntered — ignore those briefly so the
    // selection stays on the app that was just pinned/moved.
    property double _reorderedAt: 0

    function togglePin(id) {
        AppPinService.toggle(id)
        _reselect(id)
    }

    function movePin(delta) {
        if (!selApp || !selApp.pinned) return
        var id = selApp.id
        AppPinService.move(id, delta)
        _reselect(id)
    }

    function _reselect(id) {
        _reorderedAt = Date.now()
        for (var i = 0; i < filtered.length; i++) {
            if (filtered[i].id !== id) continue
            selIndex = i
            Qt.callLater(function() { appList.positionViewAtIndex(root.selIndex, ListView.Contain) })
            return
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent
        spacing: 8

        // App list
        Item {
            width:  parent.width
            height: parent.height - searchBar.height - parent.spacing

            // Loading state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: root.loading

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰣪"; font.pixelSize: 32
                    color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.3)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "Loading apps…"
                    color:          Qt.rgba(1,1,1,0.25)
                    font.pixelSize: 13
                }
            }

            // Empty / no results state
            Column {
                anchors.centerIn: parent
                spacing: 10
                visible: !root.loading && root.filtered.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.query !== "" ? "󰩄" : "󱗃"
                    font.pixelSize: 28
                    color:          Qt.rgba(1,1,1,0.18)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.query !== "" ? "No results" : "No apps found"
                    color:          Qt.rgba(1,1,1,0.25)
                    font.pixelSize: 13
                }
            }

            // App list
            ListView {
                id: appList
                anchors.fill: parent
                visible: !root.loading && root.filtered.length > 0
                model:   root.filtered
                clip:    true
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth:  3
                        implicitHeight: 40
                        radius:         1.5
                        color:          Qt.rgba(1, 1, 1, 0.22)
                    }
                    background: Item {}
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    readonly property bool isSel: root.selIndex === index

                    // Section header above the first unpinned row ("All apps",
                    // always) and the first pinned row (when something is pinned)
                    readonly property string sectionLabel:
                        index === root.pinnedCount ? "All apps"
                        : index === 0              ? "Pinned"
                        : ""

                    width:  appList.width - 8
                    height: card.height + (sectionLabel !== "" ? 32 : 0)

                    Text {
                        visible: sectionLabel !== ""
                        anchors { left: parent.left; leftMargin: 6; bottom: card.top; bottomMargin: 6 }
                        text:               sectionLabel.toUpperCase()
                        font.pixelSize:     10
                        font.weight:        Font.DemiBold
                        font.letterSpacing: 1
                        color:              Qt.rgba(1,1,1,0.35)
                    }

                    AppTile {
                        id: card
                        anchors.bottom: parent.bottom
                        width:    parent.width
                        app:      modelData
                        selected: isSel
                        onHoverEntered: if (Date.now() - root._reorderedAt > 250) root.selIndex = index
                        onLaunched:     root.launch(modelData.exec)
                        onPinToggled:   root.togglePin(modelData.id)
                    }
                }
            }
        }

        // Search bar
        AppSearchBar {
            id: searchBar
            width: parent.width
            hint: !root.selApp ? ""
                : root.selApp.pinned ? "Ctrl+P unpin · Ctrl+Shift+↑↓ reorder"
                : "Ctrl+P pin"
            onEdited: text => {
                root.query    = text
                root.selIndex = root.filtered.length > 0 ? 0 : -1
                if (root.filtered.length > 0)
                    appList.positionViewAtIndex(0, ListView.Beginning)
            }
            onMoved: delta => {
                const i = root.selIndex + delta
                if (i < 0 || i >= root.filtered.length) return
                root.selIndex = i
                appList.positionViewAtIndex(root.selIndex, ListView.Contain)
            }
            onPinMoved:   delta => root.movePin(delta)
            onPinToggled: if (root.selApp) root.togglePin(root.selApp.id)
            onAccepted: {
                if (root.selIndex >= 0 && root.selIndex < root.filtered.length)
                    root.launch(root.filtered[root.selIndex].exec)
            }
            onCloseRequested: Popups.close("dashboard")
        }
    }
}
