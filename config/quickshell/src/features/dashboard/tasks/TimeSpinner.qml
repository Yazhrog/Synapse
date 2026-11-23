import QtQuick
import qs.src.theme
// TimeSpinner — a two-digit value between ▲ and ▼ buttons (TaskDatePicker's
// hour and minute).
Column {
    id: spinner
    property string text: ""
    signal up()
    signal down()

    spacing: 2
    Rectangle {
        width: 26; height: 18; radius: 4
        color: upH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
        Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
        HoverHandler { id: upH; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: spinner.up() }
    }
    Rectangle {
        width: 26; height: 24; radius: 4
        color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
        Text {
            anchors.centerIn: parent
            text: spinner.text
            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
            color: Theme.color.accent
        }
    }
    Rectangle {
        width: 26; height: 18; radius: 4
        color: dnH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
        Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
        HoverHandler { id: dnH; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: spinner.down() }
    }
}
