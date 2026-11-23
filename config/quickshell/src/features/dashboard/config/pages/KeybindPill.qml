import QtQuick
import qs.src.theme
// KeybindPill — a keybind's combo on Config → Keybinds: accent while bound,
// amber while a change is pending, dimmed and italic when unbound.
Rectangle {
    id: pill
    property string text:        ""
    property bool   unbound:     false
    property bool   pending:     false
    property bool   interactive: true
    signal clicked()

    height: 24; radius: 6
    width:  _pillT.implicitWidth + 18

    color: pill.unbound
        ? Qt.rgba(1, 1, 1, 0.04)
        : ((_pillH.hovered && pill.interactive)
            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.16)
            : Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.08))

    border.color: pill.unbound
        ? Qt.rgba(1, 1, 1, 0.1)
        : (pill.pending
            ? Qt.rgba(1.0, 0.74, 0.22, 0.55)
            : Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.24))

    border.width: 1

    opacity: pill.interactive ? (pill.unbound ? 0.7 : 1.0) : 0.4

    Behavior on color        { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on opacity      { NumberAnimation { duration: 120 } }

    Text {
        id: _pillT
        anchors.centerIn: parent
        text:           pill.text
        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
        font.italic:    pill.unbound

        color: pill.unbound
            ? Qt.rgba(1, 1, 1, 0.45)
            : (pill.pending ? Qt.rgba(1.0, 0.74, 0.22, 1.0) : Theme.color.accent)

        Behavior on color { ColorAnimation { duration: 150 } }
    }
    HoverHandler { id: _pillH; cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
    MouseArea {
        anchors.fill: parent
        enabled: pill.interactive
        onClicked: pill.clicked()
    }
}
