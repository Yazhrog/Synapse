import QtQuick
import "../../"

// RadioPowerButton — the ⏻ header button of the Wi-Fi and Bluetooth tabs:
// red on hover while on, accent while off.

Rectangle {
    id: root

    property bool on: false
    signal clicked()

    width: 32; height: 32; radius: 8
    color: pwrH.hovered ? (on ? Qt.rgba(248/255,113/255,113/255,0.18) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)) : Qt.rgba(1,1,1,0.04)
    border.color: on ? Qt.rgba(1,1,1,0.10) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
    border.width: 1
    Behavior on color        { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 14; color: root.on ? (pwrH.hovered ? "#f87171" : Qt.rgba(1,1,1,0.32)) : Theme.active; Behavior on color { ColorAnimation { duration: 120 } } }
    HoverHandler { id: pwrH; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
