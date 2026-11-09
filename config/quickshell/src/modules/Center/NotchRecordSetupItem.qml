import QtQuick
import "../../"

// NotchRecordSetupItem — before recording: the capture and audio pills
// (each opens its option strip) and the Record button on the right.

Item {
    Row {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 6

        NotchStripButton {
            id: captureBtn
            strip: "capture"
            icon:  ScreenRecService.captureIcon
            label: ScreenRecService.captureLabel
        }

        NotchStripButton {
            id: audioBtn
            strip: "audio"
            icon:  "🎙"; tintIcon: false
            label: ScreenRecService.audioLabel
        }

        // Flexible spacer
        Item {
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            width:  parent.width - captureBtn.width - audioBtn.width - recBtn.width - parent.spacing * 3
        }

        Rectangle {
            id: recBtn
            anchors.verticalCenter: parent.verticalCenter
            width:  recLabel.implicitWidth + 24
            height: 22
            radius: height / 2
            color:  recH.hovered ? Qt.rgba(0.9, 0.2, 0.2, 0.85) : Qt.rgba(0.8, 0.1, 0.1, 0.7)
            Behavior on color { ColorAnimation { duration: 100 } }
            Row {
                anchors.centerIn: parent
                spacing: 5
                Rectangle {
                    width: 7; height: 7; radius: 4
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: recLabel
                    text: "Record"
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            HoverHandler { id: recH }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ScreenRecService.startRecording() }
        }
    }
}
