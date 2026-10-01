import QtQuick
import "../"

// ActionBtn — small square icon button used for row actions (clipboard rows,
// launcher pin). active = accent-tinted toggle state, danger = red.
Rectangle {
    id: ab
    property string icon:   ""
    property bool   active: false
    property bool   danger: false
    signal clicked()

    width: 26; height: 26; radius: 7

    color: ab.danger
        ? (aH.hovered ? Qt.rgba(248/255, 113/255, 113/255, 0.20) : "transparent")
        : ab.active
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
            : (aH.hovered ? Qt.rgba(1, 1, 1, 0.11) : "transparent")

    Behavior on color { ColorAnimation { duration: 110 } }

    // Subtle scale-up on hover
    transform: Scale {
        origin.x: 13; origin.y: 13
        xScale: aH.hovered ? 1.10 : 1.0
        yScale: aH.hovered ? 1.10 : 1.0
        Behavior on xScale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on yScale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.centerIn: parent
        text:           ab.icon
        font.pixelSize: 13
        color: ab.danger
            ? (aH.hovered ? "#f87171" : Qt.rgba(248/255, 113/255, 113/255, 0.50))
            : ab.active
                ? Theme.active
                : (aH.hovered ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, 0.38))
        Behavior on color { ColorAnimation { duration: 110 } }
    }

    HoverHandler { id: aH; cursorShape: Qt.PointingHandCursor }
    MouseArea    { anchors.fill: parent; onClicked: ab.clicked() }
}
