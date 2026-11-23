import QtQuick
import qs.src.theme
// PillButton — a text button with a tinted fill and outline (the dialogs'
// action rows). `tint` is the colour; the alphas pick the variant:
//   primary  tint accent,  rest 0.13, hover 0.26, border 0.40, medium text
//   neutral  tint white,   rest 0.04, hover 0.08, border 0.09
//   ghost    tint white,   rest 0,    hover 0.06, border 0.07
// A rest alpha of 0 is fully transparent.
Rectangle {
    id: root
    property string label:       ""
    property color  tint:        "#ffffff"
    property real   restAlpha:   0.04
    property real   hoverAlpha:  0.08
    property real   borderAlpha: 0.09
    property color  textColor:   Qt.rgba(1, 1, 1, 0.52)
    property bool   medium:      false
    signal clicked()

    height: 30; radius: Theme.radius.card
    color: hov.hovered ? Theme.color.alpha(tint, hoverAlpha)
         : restAlpha > 0 ? Theme.color.alpha(tint, restAlpha) : "transparent"
    border.color: Theme.color.alpha(tint, borderAlpha)
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.centerIn: parent
        text:           root.label
        font.pixelSize: 11
        font.weight:    root.medium ? Font.Medium : Font.Normal
        color:          root.textColor
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
