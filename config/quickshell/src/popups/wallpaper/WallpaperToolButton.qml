import QtQuick
import "../../"

// WallpaperToolButton — a 32 px button of the picker's bottom bar: an icon,
// an optional label and ▾ arrow; accent while hovered or `active`.

Rectangle {
    id: root

    property string icon:      ""
    property string label:     ""     // optional text after the icon
    property bool   active:    false  // its mode / menu is open
    property bool   showArrow: false  // ▾ / ▴ after the label

    signal clicked()

    readonly property bool _lit: active || ma.containsMouse

    width:  label === "" ? 32 : row.implicitWidth + 20
    height: 32
    radius: 8
    color: ma.containsMouse
           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
           : (active ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : Qt.rgba(1,1,1,0.04))
    border.color: _lit ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4) : Qt.rgba(1,1,1,0.09)
    border.width: 1
    Behavior on color        { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Text {
            text: root.icon
            font.pixelSize: root.label === "" ? 15 : 14
            color: root._lit ? Theme.active : Qt.rgba(1,1,1, root.label === "" ? 0.5 : 0.55)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            visible: root.label !== ""
            text: root.label
            font.pixelSize: 12
            color: root._lit ? Theme.active : Qt.rgba(1,1,1,0.7)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            visible: root.showArrow
            text: root.active ? "▴" : "▾"
            font.pixelSize: 8
            color: root._lit ? Theme.active : Qt.rgba(1,1,1,0.35)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}
