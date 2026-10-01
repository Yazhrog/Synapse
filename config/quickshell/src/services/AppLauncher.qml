import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import "../components"
import "../"

// AppLauncher — scrollable app list + bottom search bar.
// Lives inside Dashboard.qml on the "launcher" page.
// Dashboard gets keyboard focus from PopupFocusGrab, but that doesn't imply
// any particular item has Qt-level active focus — searchInput takes it below,
// and takes it again whenever the window becomes active, so it doesn't matter
// whether the compositor's focus lands before or after the timer.

Item {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────
    property var  apps:     []
    property bool loading:  true
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

    // ── Load apps ─────────────────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["python3", Quickshell.shellDir + "/src/scripts/list_apps.py"]
        running: false
        stdout: StdioCollector {
            id: listBuf
            onStreamFinished: {
                try   { root.apps = JSON.parse(listBuf.text) }
                catch (e) { root.apps = [] }
                root.loading  = false
                root.selIndex = root.apps.length > 0 ? 0 : -1
            }
        }
    }

    onVisibleChanged: {
        if (!visible) return
        root.loading   = true
        root.apps      = []
        root.query     = ""
        root.selIndex  = -1
        searchInput.text = ""
        listProc.running = false
        listProc.running = true
        focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: searchInput.forceActiveFocus()
    }

    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.visible && root.Window.window && root.Window.window.active)
                searchInput.forceActiveFocus()
        }
    }

    // ── Launch ────────────────────────────────────────────────────────────────
    Process {
        id: launcher
        command: []
        running: false
    }

    function launch(exec) {
        launcher.command = ["bash", "-c", "setsid " + exec + " &>/dev/null &"]
        launcher.running = false
        launcher.running = true
        Popups.dashboardOpen = false
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
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.3)
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

                    Rectangle {
                        id: card
                        anchors.bottom: parent.bottom
                        width:  parent.width
                        height: 46
                        radius: 9

                        color: isSel
                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                               : modelData.pinned
                                 ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, rowH.hovered ? 0.10 : 0.055)
                                 : rowH.hovered ? Qt.rgba(1,1,1,0.06) : "transparent"
                        border.color: isSel
                                      ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                                      : modelData.pinned
                                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, rowH.hovered ? 0.30 : 0.18)
                                        : rowH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                        border.width: 1

                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }

                        // Declared before the Row so the pin button stacks above it
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: {
                                if (Date.now() - root._reorderedAt > 250)
                                    root.selIndex = index
                            }
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) root.togglePin(modelData.id)
                                else                                 root.launch(modelData.exec)
                            }
                        }

                        Row {
                            anchors {
                                left:   parent.left;  leftMargin:  12
                                right:  parent.right; rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 12

                            // App icon
                            Item {
                                width: 28; height: 28
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: ico
                                    anchors.fill: parent
                                    source: {
                                        var s = modelData.icon
                                        if (!s || s === "")    return ""
                                        if (s.startsWith("/")) return "file://" + s
                                        return "image://icon/" + s
                                    }
                                    fillMode:          Image.PreserveAspectFit
                                    smooth:            true
                                    sourceSize.width:  28
                                    sourceSize.height: 28
                                }

                                // Letter fallback
                                Rectangle {
                                    anchors.fill: parent
                                    radius:       7
                                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                    visible: ico.status !== Image.Ready || modelData.icon === ""
                                    Text {
                                        anchors.centerIn: parent
                                        text:           modelData.name.charAt(0).toUpperCase()
                                        font.pixelSize: 13; font.bold: true
                                        color:          Theme.active
                                    }
                                }
                            }

                            // App name
                            Text {
                                width: parent.width - 28 - pinBtn.width - parent.spacing * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text:           modelData.name
                                font.pixelSize: 13
                                color:          isSel ? Theme.active : Theme.text
                                elide:          Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            // Pin toggle — always shown on pinned rows (doubles as
                            // the pinned indicator), on hover/selection otherwise
                            ActionBtn {
                                id: pinBtn
                                anchors.verticalCenter: parent.verticalCenter
                                icon:    modelData.pinned && rowH.hovered ? "󰐄" : "󰐃"
                                active:  modelData.pinned
                                opacity: modelData.pinned || isSel || rowH.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                                onClicked: root.togglePin(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // Search bar
        Rectangle {
            id: searchBar
            width: parent.width; height: 44; radius: 12
            color: Qt.rgba(1,1,1,0.06)
            border.color: searchInput.activeFocus
                          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50)
                          : Qt.rgba(1,1,1,0.12)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"; font.pixelSize: 16
                    color: searchInput.activeFocus
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
                           : Qt.rgba(1,1,1,0.35)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Item {
                    width: parent.width - 26 - parent.spacing
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:    "Search apps…"
                        color:   Qt.rgba(1,1,1,0.22)
                        font.pixelSize: 13
                        visible: searchInput.text === ""
                    }

                    // Pin shortcut hint, for whichever row is selected
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: root.selApp && root.selApp.pinned
                              ? "Ctrl+P unpin · Ctrl+Shift+↑↓ reorder"
                              : "Ctrl+P pin"
                        color:   Qt.rgba(1,1,1,0.22)
                        font.pixelSize: 11
                        visible: searchInput.text === "" && root.selApp !== null
                    }

                    TextInput {
                        id: searchInput
                        anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
                        verticalAlignment: TextInput.AlignVCenter
                        color:          Theme.text
                        font.pixelSize: 13
                        selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                        clip: true

                        onTextChanged: {
                            root.query    = text
                            root.selIndex = root.filtered.length > 0 ? 0 : -1
                            if (root.filtered.length > 0)
                                appList.positionViewAtIndex(0, ListView.Beginning)
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                                if (root.selApp) root.togglePin(root.selApp.id)
                                event.accepted = true
                            }
                        }

                        Keys.onUpPressed: function(event) {
                            if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                                root.movePin(-1)
                                return
                            }
                            if (root.selIndex > 0) {
                                root.selIndex--
                                appList.positionViewAtIndex(root.selIndex, ListView.Contain)
                            }
                        }

                        Keys.onDownPressed: function(event) {
                            if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                                root.movePin(1)
                                return
                            }
                            if (root.selIndex < root.filtered.length - 1) {
                                root.selIndex++
                                appList.positionViewAtIndex(root.selIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.selIndex >= 0 && root.selIndex < root.filtered.length)
                                root.launch(root.filtered[root.selIndex].exec)
                        }

                        Keys.onEscapePressed: {
                            if (text !== "") {
                                text = ""
                            } else {
                                Popups.dashboardOpen = false
                            }
                        }
                    }
                }
            }
        }
    }
}
