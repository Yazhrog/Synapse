import QtQuick
import "../../../"

// ClockButton — the 58×26 text button of the clock views (Start, Reset, Set …).
// `accent` tints it with Theme.active; the alphas tune the accent fill.

Rectangle {
    id: root

    property string text:        ""
    property bool   accent:      true
    property int    fontSize:    10
    property real   restAlpha:   0.12
    property real   hoverAlpha:  0.2
    property real   borderAlpha: 0.22

    signal clicked()

    width: 58; height: 26; radius: 8
    color: accent
           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, _hov.hovered ? hoverAlpha : restAlpha)
           : Qt.rgba(1, 1, 1, _hov.hovered ? 0.1 : 0.05)
    border.color: accent
                  ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, borderAlpha)
                  : Qt.rgba(1, 1, 1, 0.1)
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: root.fontSize; font.weight: Font.Medium
        color: root.accent ? Theme.active : Qt.rgba(1, 1, 1, 0.4)
    }
    HoverHandler { id: _hov; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
