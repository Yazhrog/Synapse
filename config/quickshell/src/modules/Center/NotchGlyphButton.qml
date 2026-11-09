import QtQuick
import "../../"

// NotchGlyphButton — a bare 16 px icon button (play / pause, reset) that
// turns accent on hover.

Text {
    id: root
    signal clicked()

    font.pixelSize: 16
    color: _hov.hovered ? Theme.active : Theme.text
    HoverHandler { id: _hov }
    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}
