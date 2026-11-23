import QtQuick
// KeybindIconBtn — the small clear / reset buttons of a KeybindRow.
Rectangle {
    id: btn
    property string icon:       ""
    property color  hoverColor: "#ffffff"
    property bool   interactive: true
    signal clicked()

    width: 22; height: 22; radius: 6
    color: hov.hovered ? Qt.rgba(1,1,1,0.09) : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }
    Text { anchors.centerIn: parent; text: btn.icon; font.pixelSize: 11
        color: hov.hovered ? btn.hoverColor : Qt.rgba(1,1,1,0.28) }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        enabled: btn.interactive
        onClicked: btn.clicked()
    }
}
