import QtQuick
import "../../../"

// ClockAddButton — the 24×24 "+" toggle that opens a view's add panel.
// Shows `closeGlyph` while `open`.

Item {
    id: root

    property bool   open:       false
    property string closeGlyph: "✕"

    signal clicked()

    width: 24; height: 24

    Rectangle {
        anchors.fill: parent; radius: 7
        color: _hov.hovered
               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
               : Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2); border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
            anchors.centerIn: parent
            text: root.open ? root.closeGlyph : "+"
            font.pixelSize: 14; color: Theme.active
        }
    }
    HoverHandler { id: _hov; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
