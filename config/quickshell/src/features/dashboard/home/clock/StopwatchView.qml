import QtQuick
import qs.src.services.time
import qs.src.theme
// StopwatchView — elapsed time with Start/Stop and Reset.

Item {
    Column {
        anchors.centerIn: parent; spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ClockService.swDisplay
            font.pixelSize: 52; font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: -1
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            ClockButton {
                text: ClockService.swRunning ? "Stop" : "Start"
                onClicked: ClockService.toggleStopwatch()
            }
            ClockButton {
                text: "Reset"; accent: false
                onClicked: ClockService.resetStopwatch()
            }
        }
    }
}
