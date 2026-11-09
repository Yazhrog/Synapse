import QtQuick
import "../../../"
import "../../../components"

// AlarmView — alarm list with an add panel, per-alarm toggle and delete.

Item {
    id: root
    clip: true

    property bool _addOpen: false

    Item {
        anchors { fill: parent; margins: 10 }

        // ── Header — Item, not Row, so the right-anchored + button works ───
        Item {
            id: alarmHeader
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 28

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "Alarms"; font.pixelSize: 12; font.weight: Font.DemiBold
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
            }

            ClockAddButton {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                open: root._addOpen
                onClicked: {
                    root._addOpen = !root._addOpen
                    if (root._addOpen) {
                        // Snap to the next 5-minute mark from now
                        var d = new Date()
                        var snapped = Math.ceil((d.getHours() * 60 + d.getMinutes() + 1) / 5) * 5
                        alarmTimeInput.initialize(Math.floor(snapped / 60) % 24, snapped % 60)
                    }
                }
            }
        }

        // ── Add alarm panel ────────────────────────────────────────────────
        Rectangle {
            id: addPanel
            anchors { left: parent.left; right: parent.right; top: alarmHeader.bottom; topMargin: 6 }
            height:  root._addOpen ? 140 : 0
            clip:    true
            color:   Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.05)
            radius:  8
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1); border.width: 1
            opacity: root._addOpen ? 1 : 0
            Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 10

                TimeInput {
                    id: alarmTimeInput
                    anchors.horizontalCenter: parent.horizontalCenter
                    minuteStep: 1
                }

                ClockButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Set Alarm"; fontSize: 11
                    restAlpha: 0.1; hoverAlpha: 0.18; borderAlpha: 0.25
                    onClicked: {
                        ClockState.addAlarm(alarmTimeInput.hours, alarmTimeInput.minutes)
                        root._addOpen = false
                    }
                }
            }
        }

        // ── Alarm list ─────────────────────────────────────────────────────
        ListView {
            id: alarmList
            anchors {
                left: parent.left; right: parent.right
                top: addPanel.bottom; topMargin: 6
                bottom: parent.bottom
            }
            model: ClockState.alarms
            clip: true; spacing: 4
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: alarmList.width; height: 36; radius: 8
                color: Qt.rgba(1,1,1,0.04)
                border.color: modelData.enabled
                              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.15)
                              : Qt.rgba(1,1,1,0.07)
                border.width: 1

                // Time label
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: ClockState.zp(modelData.hour) + ":" + ClockState.zp(modelData.minute)
                    font.pixelSize: 15; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"
                    color: modelData.enabled
                           ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                           : Qt.rgba(1,1,1,0.3)
                }

                // Toggle
                Rectangle {
                    anchors { right: deleteBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 28; height: 18; radius: 9
                    color: modelData.enabled
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.25)
                           : Qt.rgba(1,1,1,0.1)
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        x: modelData.enabled ? parent.width - width - 3 : 3
                        color: modelData.enabled ? Theme.active : Qt.rgba(1,1,1,0.3)
                        Behavior on x     { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: 130 } }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: ClockState.toggleAlarm(modelData.id)
                    }
                }

                // Delete
                Rectangle {
                    id: deleteBtn
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 22; height: 22; radius: 6
                    color: _delH.hovered ? Qt.rgba(248/255,113/255,113/255,0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: Qt.rgba(248/255,113/255,113/255,0.6) }
                    HoverHandler { id: _delH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: ClockState.deleteAlarm(modelData.id) }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ClockState.alarms.length === 0 && !root._addOpen
                text: "No alarms set\nTap + to add one"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11; color: Qt.rgba(1,1,1,0.2)
                lineHeight: 1.5
            }
        }
    }
}
