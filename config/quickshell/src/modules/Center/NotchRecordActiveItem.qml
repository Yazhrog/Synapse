import QtQuick
import "../../"

// NotchRecordActiveItem — while recording: pulsing dot and elapsed time on
// the left, the audio level in the middle, discard and stop on the right.

Item {
    // Left: dot + timer, anchored left
    Row {
        anchors {
            left:           parent.left
            leftMargin:    10
            verticalCenter: parent.verticalCenter
        }
        spacing: 7

        // Pulsing red dot
        Rectangle {
            width:  8; height: 8; radius: 4
            color:  "#ff4444"
            anchors.verticalCenter: parent.verticalCenter
            SequentialAnimation on opacity {
                running: ScreenRecService.recording
                loops:   Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
            }
        }

        // Elapsed time
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           ScreenRecService.elapsedDisplay
            font.pixelSize: 13; font.weight: Font.Bold
            font.family:    "JetBrainsMono Nerd Font"
            color:          Theme.text
        }
    }

    // Center: the recording's audio level
    CavaBars {
        anchors.centerIn: parent
        width:  44
        height: 20
        bars:       ScreenRecService.audioBars
        barWidth:   4
        barSpacing: Math.max(1, (width - barWidth * 12) / 5)
        tint:       Qt.rgba(0.95, 0.3, 0.3, 1)
        minAlpha:   0.30
        muted:      !(ScreenRecService.audioMic || ScreenRecService.audioSystem)
    }

    // Right: trash + stop, anchored right
    Row {
        anchors {
            right:          parent.right
            rightMargin:    10
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.notchRadius / 2

        // Discard button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 5
            color: recDiscardH.hovered
            ? Qt.rgba(1, 1, 1, 0.12)
            : Qt.rgba(1, 1, 1, 0.05)
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text:           "󰩺"
                font.pixelSize: 11
                color:          recDiscardH.hovered
                ? Qt.rgba(1, 0.4, 0.4, 1.0)
                : Qt.rgba(1, 1, 1, 0.4)
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            HoverHandler { id: recDiscardH }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ScreenRecService.discardRecording() }
        }

        // Stop button
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 5
            color: recStopH.hovered
            ? Qt.rgba(0.9, 0.2, 0.2, 0.55)
            : Qt.rgba(0.8, 0.1, 0.1, 0.32)
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
                anchors.centerIn: parent
                text:           "⏹"
                font.pixelSize: 10
                color:          "#ff9999"
            }
            HoverHandler { id: recStopH }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ScreenRecService.stopRecording() }
        }
    }
}
