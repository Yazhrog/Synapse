import QtQuick
import "../../../"
import "../../../components"

// TimerView — countdown ring, presets, a custom duration panel and Start/Pause + Reset.

Item {
    id: root

    property bool _addOpen: false

    // "+" / "x" toggle — top-right corner
    ClockAddButton {
        anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
        open: root._addOpen
        closeGlyph: "x"
        onClicked: root._addOpen = !root._addOpen
    }

    Column {
        anchors.centerIn: parent; spacing: 10

        // ── Ring — hidden while the add panel is open ──────────────────────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 100; height: 100
            visible: !root._addOpen

            Canvas {
                id: timerCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width/2, cy = height/2, r = 44
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI*2)
                    ctx.strokeStyle = Qt.rgba(1,1,1,0.08)
                    ctx.lineWidth = 5; ctx.stroke()
                    var p = ClockState.timerProgress
                    if (p > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + Math.PI*2*p)
                        ctx.strokeStyle = Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85)
                        ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                    }
                }
                Connections {
                    target: ClockState
                    function onTimerProgressChanged() { timerCanvas.requestPaint() }
                }
                Connections {
                    target: Theme
                    function onActiveChanged() { timerCanvas.requestPaint() }
                }
            }

            Column {
                anchors.centerIn: parent; spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ClockState.timerDisplay
                    font.pixelSize: ClockState.timerLeft >= 3600 ? 16 : 22
                    font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "remaining"; font.pixelSize: 8
                    color: Qt.rgba(1,1,1,0.25)
                }
            }
        }

        // ── Presets — hidden while the add panel is open or the timer runs ─
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5
            visible: !root._addOpen && !ClockState.timerRunning
            Repeater {
                model: [5, 10, 15, 30]
                delegate: Rectangle {
                    required property int modelData
                    width: 36; height: 22; radius: 6
                    color: _pH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData < 60 ? modelData+"m" : "1h"
                        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
                        color: Qt.rgba(1,1,1,0.45)
                    }
                    HoverHandler { id: _pH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ClockState.setTimer(modelData * 60)
                    }
                }
            }
        }

        // ── Custom duration — visible only while the add panel is open ─────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root._addOpen
            width:  _inputCol.implicitWidth
            height: _inputCol.implicitHeight

            Column {
                id: _inputCol
                anchors.centerIn: parent
                spacing: 10

                TimeInput {
                    id: timeInput
                    anchors.horizontalCenter: parent.horizontalCenter
                    minuteStep: 1
                }

                ClockButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Set Timer"; fontSize: 11
                    restAlpha: 0.1; hoverAlpha: 0.18; borderAlpha: 0.25
                    onClicked: {
                        root._addOpen = false
                        ClockState.setTimer(timeInput.hours * 3600 + timeInput.minutes * 60)
                    }
                }
            }
        }

        // ── Start / Pause + Reset ──────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: !root._addOpen

            ClockButton {
                text: ClockState.timerRunning ? "Pause" : "Start"
                onClicked: ClockState.toggleTimer()
            }
            ClockButton {
                text: "Reset"; accent: false
                onClicked: ClockState.resetTimer()
            }
        }
    }
}
