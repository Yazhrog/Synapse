import QtQuick
import "../../"

// KanbanDatePicker — the due-date picker: dims the board and shows a month
// calendar with an optional time. open(taskId) loads the task's due date;
// Done saves it (time only → today), Clear removes it, a click outside cancels.
// Fills the board; shown while pickerTaskId >= 0.

Item {
    id: root

    property int    pickerTaskId:  -1
    property int    pickerYear:    0
    property int    pickerMonth:   0
    property int    pickerDay:     0     // 0 = date not selected
    property bool   pickerHasTime: false
    property int    pickerTimeH:   12
    property int    pickerTimeM:   0
    property var    pickerDays:    []

    readonly property var _monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var _dowNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

    function close() { pickerTaskId = -1 }

    function open(taskId) {
        root.pickerTaskId  = taskId
        var now = new Date()
        root.pickerYear    = now.getFullYear()
        root.pickerMonth   = now.getMonth()
        root.pickerDay     = 0
        root.pickerHasTime = false
        root.pickerTimeH   = 12
        root.pickerTimeM   = 0

        var t = KanbanService.task(taskId)
        var s = t ? (t.dueDate || "") : ""
        if (s !== "") {
            var dp2 = s.length >= 10 ? s.substring(0, 10) : ""
            var tp  = s.length >= 16 ? s.substring(11, 16) : ""
            if (dp2 !== "") {
                var p = dp2.split("-")
                root.pickerYear  = parseInt(p[0])
                root.pickerMonth = parseInt(p[1]) - 1
                root.pickerDay   = parseInt(p[2])
            }
            if (tp !== "") {
                var tParts = tp.split(":")
                root.pickerTimeH   = parseInt(tParts[0]) || 0
                root.pickerTimeM   = parseInt(tParts[1]) || 0
                root.pickerHasTime = true
            }
        }
        _rebuildPickerDays()
    }

    function _rebuildPickerDays() {
        var firstDow   = new Date(root.pickerYear, root.pickerMonth, 1).getDay()
        var daysInMon  = new Date(root.pickerYear, root.pickerMonth + 1, 0).getDate()
        var daysInPrev = new Date(root.pickerYear, root.pickerMonth, 0).getDate()
        var days = []
        for (var p = firstDow - 1; p >= 0; p--)
            days.push({ n: daysInPrev - p, cur: false })
        for (var d = 1; d <= daysInMon; d++)
            days.push({ n: d, cur: true })
        var tail = 42 - days.length
        for (var t = 1; t <= tail; t++)
            days.push({ n: t, cur: false })
        root.pickerDays = days
    }

    onPickerYearChanged:  _rebuildPickerDays()
    onPickerMonthChanged: _rebuildPickerDays()

    function commit() {
        if (root.pickerTaskId < 0) return
        var datePart = "", timePart = ""
        if (root.pickerDay > 0) {
            var m = root.pickerMonth + 1
            datePart = root.pickerYear + "-" + KanbanService.zp2(m) + "-" + KanbanService.zp2(root.pickerDay)
        }
        if (root.pickerHasTime)
            timePart = KanbanService.zp2(root.pickerTimeH) + ":" + KanbanService.zp2(root.pickerTimeM)

        var result = ""
        if (datePart !== "" && timePart !== "") result = datePart + " " + timePart
        else if (datePart !== "") result = datePart
        else if (timePart !== "") {
            result = KanbanService.todayString() + " " + timePart
        }
        KanbanService.patchTask(root.pickerTaskId, "dueDate", result)
        root.pickerTaskId = -1
    }

    // ── Picker dim overlay ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; z: 29
        visible: root.pickerTaskId >= 0
        color:   Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: root.pickerTaskId = -1 }
    }

    // ── Date / time picker popup ──────────────────────────────────────────────
    Rectangle {
        id: datePicker
        z:              30
        anchors.centerIn: parent
        visible:        root.pickerTaskId >= 0

        width:  230
        height: pickerCol.implicitHeight + 24
        radius: Theme.cornerRadius
        color: Qt.rgba(
            Math.min(1, Theme.background.r + 0.06),
            Math.min(1, Theme.background.g + 0.06),
            Math.min(1, Theme.background.b + 0.06), 0.98)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1

        // Swallow clicks so they don't reach the dim overlay below
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: pickerCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            // ── Month nav ──────────────────────────────────────────────────────
            Item {
                width: parent.width; height: 22
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "‹"; font.pixelSize: 17
                    color: pmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    HoverHandler { id: pmH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.pickerMonth === 0) { root.pickerMonth = 11; root.pickerYear-- }
                            else root.pickerMonth--
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text:  root._monthNames[root.pickerMonth].substring(0,3) + "  " + root.pickerYear
                    color: Theme.text; font.pixelSize: 11; font.weight: Font.DemiBold
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "›"; font.pixelSize: 17
                    color: nmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    HoverHandler { id: nmH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.pickerMonth === 11) { root.pickerMonth = 0; root.pickerYear++ }
                            else root.pickerMonth++
                        }
                    }
                }
            }

            // ── Day-of-week headers ────────────────────────────────────────────
            Item {
                width: parent.width; height: 14
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: root._dowNames
                        delegate: Text {
                            width: Math.floor(parent.parent.width / 7)
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData; font.pixelSize: 8; font.weight: Font.Bold
                            color: Qt.rgba(1,1,1,0.18)
                        }
                    }
                }
            }

            // ── Day grid ──────────────────────────────────────────────────────
            Grid {
                id: dayGrid
                width: parent.width; columns: 7; rows: 6
                readonly property real cW: width / 7
                readonly property real cH: 24

                Repeater {
                    model: root.pickerDays
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: dayGrid.cW; height: dayGrid.cH

                        readonly property bool isSel: modelData.cur && modelData.n === root.pickerDay
                        readonly property bool isNow: {
                            var n = new Date()
                            return modelData.cur &&
                                   modelData.n   === n.getDate() &&
                                   root.pickerMonth === n.getMonth() &&
                                   root.pickerYear  === n.getFullYear()
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(dayGrid.cW, dayGrid.cH) - 2; height: width; radius: width / 2
                            color: isSel
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.82)
                                : isNow ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                                        : dayH.hovered && modelData.cur ? Qt.rgba(1,1,1,0.08) : "transparent"
                            border.color: isNow && !isSel ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.n
                                font.pixelSize: 9; font.weight: isSel ? Font.Bold : Font.Normal
                                color: isSel ? Theme.background
                                    : modelData.cur ? Qt.rgba(1,1,1,0.78) : Qt.rgba(1,1,1,0.14)
                            }
                        }
                        HoverHandler { id: dayH; enabled: modelData.cur; cursorShape: Qt.PointingHandCursor }
                        TapHandler  { enabled: modelData.cur; onTapped: root.pickerDay = modelData.n }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Time row ──────────────────────────────────────────────────────
            Item {
                width: parent.width; height: timeInner.implicitHeight

                Row {
                    id: timeInner
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⏰"; font.pixelSize: 13
                    }

                    // Controls when time is set
                    Row {
                        spacing: 4; visible: root.pickerHasTime
                        anchors.verticalCenter: parent.verticalCenter

                        // ── Hour col ──────────────────────────────────────────
                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: hUpH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: hUpH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeH = (root.pickerTimeH + 1) % 24 }
                            }
                            Rectangle {
                                width: 26; height: 24; radius: 4
                                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: KanbanService.zp2(root.pickerTimeH)
                                    font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
                                    color: Theme.active
                                }
                            }
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: hDnH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: hDnH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeH = (root.pickerTimeH + 23) % 24 }
                            }
                        }

                        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }

                        // ── Minute col ────────────────────────────────────────
                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: mUpH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: mUpH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeM = (root.pickerTimeM + 5) % 60 }
                            }
                            Rectangle {
                                width: 26; height: 24; radius: 4
                                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: KanbanService.zp2(root.pickerTimeM)
                                    font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
                                    color: Theme.active
                                }
                            }
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: mDnH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: mDnH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeM = (root.pickerTimeM + 55) % 60 }
                            }
                        }

                        // Clear time ✕
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18; radius: 9
                            color: clrTH.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.05)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: Qt.rgba(1,1,1,0.40) }
                            HoverHandler { id: clrTH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root.pickerHasTime = false }
                        }
                    }

                    // "Add time" pill (shown when no time set)
                    Rectangle {
                        visible: !root.pickerHasTime
                        anchors.verticalCenter: parent.verticalCenter
                        width: addTL.implicitWidth + 18; height: 24; radius: 12
                        color: addTH.hovered
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                            : Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            id: addTL; anchors.centerIn: parent
                            text: "Add time"; font.pixelSize: 10
                            color: addTH.hovered ? Theme.active : Qt.rgba(1,1,1,0.45)
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                        HoverHandler { id: addTH; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.pickerHasTime = true; root.pickerTimeH = 12; root.pickerTimeM = 0 }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Clear / Done ───────────────────────────────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10; bottomPadding: 0

                Rectangle {
                    width: 86; height: 28; radius: 8
                    color: clrH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "Clear"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.50) }
                    HoverHandler { id: clrH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { KanbanService.patchTask(root.pickerTaskId, "dueDate", ""); root.pickerTaskId = -1 }
                    }
                }

                Rectangle {
                    width: 86; height: 28; radius: 8
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, doneH.hovered ? 0.28 : 0.16)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent; text: "Done"
                        font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active
                    }
                    HoverHandler { id: doneH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.commit() }
                }
            }
        }
    }
}
