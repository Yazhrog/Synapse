import QtQuick
import qs.src.services.data
import qs.src.theme
// TaskDatePicker — the due-date picker: dims the board and shows a month
// calendar with an optional time. open(taskId) loads the task's due date;
// Done saves it (time only → today), Clear removes it, a click outside cancels.
// Fills the board; shown while pickerTaskId >= 0. The board fades its
// columns behind it (a black dim showed as a box on a translucent frame).

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

        var t = TaskService.task(taskId)
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
            datePart = root.pickerYear + "-" + TaskService.zp2(m) + "-" + TaskService.zp2(root.pickerDay)
        }
        if (root.pickerHasTime)
            timePart = TaskService.zp2(root.pickerTimeH) + ":" + TaskService.zp2(root.pickerTimeM)

        var result = ""
        if (datePart !== "" && timePart !== "") result = datePart + " " + timePart
        else if (datePart !== "") result = datePart
        else if (timePart !== "") {
            result = TaskService.todayString() + " " + timePart
        }
        TaskService.patchTask(root.pickerTaskId, "dueDate", result)
        root.pickerTaskId = -1
    }

    // ── Click catcher: a click outside the picker cancels ─────────────────────
    MouseArea {
        anchors.fill: parent; z: 29
        visible: root.pickerTaskId >= 0
        onClicked: root.pickerTaskId = -1
    }

    // ── Date / time picker popup ──────────────────────────────────────────────
    Rectangle {
        id: datePicker
        z:              30
        anchors.centerIn: parent
        visible:        root.pickerTaskId >= 0

        width:  230
        height: pickerCol.implicitHeight + 24
        radius: Theme.radius.card
        color: Qt.rgba(
            Math.min(1, Theme.color.background.r + 0.06),
            Math.min(1, Theme.color.background.g + 0.06),
            Math.min(1, Theme.color.background.b + 0.06), 0.98)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1

        // Swallow clicks so they don't reach the dim overlay below
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: pickerCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            // ── Month, weekdays and day grid ───────────────────────────────────
            TaskCalendar {
                width: parent.width
                year:  root.pickerYear
                month: root.pickerMonth
                day:   root.pickerDay
                days:  root.pickerDays
                onMonthStepped: delta => {
                    const m = root.pickerMonth + delta
                    if (m < 0)       { root.pickerMonth = 11; root.pickerYear-- }
                    else if (m > 11) { root.pickerMonth = 0;  root.pickerYear++ }
                    else root.pickerMonth = m
                }
                onDayPicked: day => root.pickerDay = day
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

                        TimeSpinner {
                            anchors.verticalCenter: parent.verticalCenter
                            text:   TaskService.zp2(root.pickerTimeH)
                            onUp:   root.pickerTimeH = (root.pickerTimeH + 1) % 24
                            onDown: root.pickerTimeH = (root.pickerTimeH + 23) % 24
                        }

                        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.color.text }

                        TimeSpinner {
                            anchors.verticalCenter: parent.verticalCenter
                            text:   TaskService.zp2(root.pickerTimeM)
                            onUp:   root.pickerTimeM = (root.pickerTimeM + 5) % 60
                            onDown: root.pickerTimeM = (root.pickerTimeM + 55) % 60
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
                            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.15)
                            : Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            id: addTL; anchors.centerIn: parent
                            text: "Add time"; font.pixelSize: 10
                            color: addTH.hovered ? Theme.color.accent : Qt.rgba(1,1,1,0.45)
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
                        onClicked: { TaskService.patchTask(root.pickerTaskId, "dueDate", ""); root.pickerTaskId = -1 }
                    }
                }

                Rectangle {
                    width: 86; height: 28; radius: 8
                    color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, doneH.hovered ? 0.28 : 0.16)
                    border.color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.38); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent; text: "Done"
                        font.pixelSize: 11; font.weight: Font.Medium; color: Theme.color.accent
                    }
                    HoverHandler { id: doneH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.commit() }
                }
            }
        }
    }
}
