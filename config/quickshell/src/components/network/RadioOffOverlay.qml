import QtQuick
import "../../"

// RadioOffOverlay — covers a tab's list while its radio is off, with a
// "Turn On" button (the Wi-Fi and Bluetooth tabs).

Item {
    id: root

    property string glyph:   ""      // radio-off glyph
    property string buttonGlyph: ""  // glyph on the Turn On button
    property string title:   ""      // e.g. "Wi-Fi is off"

    signal turnOn()

    Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95) }

    // Swallow clicks so they don't reach the list below
    MouseArea { anchors.fill: parent }

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
