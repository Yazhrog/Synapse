import QtQuick
import "../../"

// SettingsLaunchButton — the 󰒓 header button that opens an external settings
// tool (nmtui, blueman-manager).

Rectangle {
    id: root
    signal clicked()

    width: 32; height: 32; radius: 8
    color: settH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.03)
    border.color: Qt.rgba(1,1,1,0.10); border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }
    Text { anchors.centerIn: parent; text: "󰒓"; font.pixelSize: 14; color: settH.hovered ? Qt.rgba(1,1,1,0.75) : Qt.rgba(1,1,1,0.30); Behavior on color { ColorAnimation { duration: 100 } } }
    HoverHandler { id: settH; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
