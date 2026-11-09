import QtQuick
import "../../"

// RefreshButton — the 󰑐 header button; spins while `busy`, dimmed when not
// `available`. Clicks are ignored while busy or unavailable.

Rectangle {
    id: root

    property bool busy:    false
    property bool available: true
    signal clicked()

    width: 32; height: 32; radius: 8
    color: rfH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15) : Qt.rgba(1,1,1,0.05)
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28); border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
        id: rfIcon; anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 15
        color: root.busy ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4) : (root.available ? Theme.active : Qt.rgba(1,1,1,0.18))
        Behavior on color { ColorAnimation { duration: 150 } }
        RotationAnimator { target: rfIcon; from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.busy; easing.type: Easing.Linear }
    }
    HoverHandler { id: rfH; cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor }
    MouseArea { anchors.fill: parent; onClicked: if (!root.busy && root.available) root.clicked() }
}
