import QtQuick
import "../"

// QuickToggleTile — one Quick Settings tile: icon, label, optional sublabel
// and an on/off state (accent fill + dot). Emits toggled() on click.

Rectangle {
    id: btn

    required property bool   on
    required property string icon
    required property string label
    property string sublabel: ""

    signal toggled()

    radius: 10
    color: on
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
        : bH.hovered
            ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
    border.color: on
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
    border.width: 1
    Behavior on color        { ColorAnimation { duration: 130 } }
    Behavior on border.color { ColorAnimation { duration: 130 } }

    Rectangle {
        anchors { top: parent.top; right: parent.right; margins: 8 }
        width: 6; height: 6; radius: 3
        color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.18)
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    Column {
        anchors { left: parent.left; bottom: parent.bottom; margins: 9 }
        spacing: 2
        Text {
            text: btn.icon; font.pixelSize: 17
            color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.40)
            Behavior on color { ColorAnimation { duration: 130 } }
        }
        Text {
            text: btn.label; font.pixelSize: 9; font.weight: Font.Medium
            color: btn.on ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
            Behavior on color { ColorAnimation { duration: 130 } }
        }
        Text {
            visible: btn.sublabel !== ""
            text:    btn.sublabel
            font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font"
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.65)
            width: btn.width - 18; elide: Text.ElideRight
        }
    }
    HoverHandler { id: bH; cursorShape: Qt.PointingHandCursor }
    MouseArea    { anchors.fill: parent; onClicked: btn.toggled() }
}
