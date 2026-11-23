import QtQuick
import qs.src.theme
import "player.js" as Player
// PlayerProgress — the track's progress bar (click to seek) and its elapsed
// / total times.
Column {
    id: progress
    property real position: 0     // seconds
    property real length:   0
    property bool canSeek:  false
    signal seekRequested(real seconds)

    spacing: 3
    Item {
        width: parent.width; height: 6
        Rectangle {
            anchors.fill: parent; radius: height / 2
            color: Qt.rgba(1,1,1,0.2)
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                    if (progress.canSeek)
                        progress.seekRequested(mouse.x / width * progress.length)
                }
            }
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width:  Math.max(radius * 2, parent.width * (progress.length > 0 ? progress.position / progress.length : 0))
                radius: parent.radius; color: Theme.color.accent
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
    }
    Item {
        width: parent.width; height: 14

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: Player.formatTime(progress.position)
            font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(1,1,1,0.4)
        }

        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Player.formatTime(progress.length)
            font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(1,1,1,0.4)
        }
    }
}
