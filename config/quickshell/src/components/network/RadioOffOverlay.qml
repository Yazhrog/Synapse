import QtQuick
import "../../"

// RadioOffOverlay — "<radio> is off" and a "Turn On" button, shown in place
// of a tab's list while its radio is off (the Wi-Fi and Bluetooth tabs hide
// the list). No background of its own: the popup's frame shows through.

Item {
    id: root

    property string glyph:   ""      // radio-off glyph
    property string buttonGlyph: ""  // glyph on the Turn On button
    property string title:   ""      // e.g. "Wi-Fi is off"

    signal turnOn()

    Column {
        anchors.centerIn: parent; spacing: 16
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.glyph; font.pixelSize: 42; color: Qt.rgba(1,1,1,0.12) }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.title; font.pixelSize: 14; font.weight: Font.Medium; color: Qt.rgba(1,1,1,0.30) }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: enRow.implicitWidth + 24; height: 34; radius: 17
            color: enH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40); border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Row { id: enRow; anchors.centerIn: parent; spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: root.buttonGlyph; font.pixelSize: 14; color: Theme.active }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Turn On"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.active }
            }
            HoverHandler { id: enH; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: root.turnOn() }
        }
    }
}
