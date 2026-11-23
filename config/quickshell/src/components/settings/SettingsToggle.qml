import QtQuick
import qs.src.theme
// SettingsToggle — a row with a pill switch.
//
// Shows `value` (a bool); a click or Space/Enter emits edited(!value) and
// toggled(!value), and the container writes it.
SettingsRow {
    id: root

    readonly property bool checked: !!value
    signal toggled(bool checked)

    activeFocusOnTab: true

    function toggle() {
        const next = !root.checked
        root.edited(next)
        root.toggled(next)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle()
            event.accepted = true
        }
    }

    Rectangle {
        id: sw
        width:  42
        height: 24
        radius: height / 2
        color: root.checked
            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.35)
            : Qt.rgba(1, 1, 1, 0.07)
        border.color: root.checked
            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.55)
            : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width:  18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x:     root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.color.accent : Qt.rgba(1, 1, 1, 0.35)
            Behavior on x     { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: root.toggle()
        }
    }
}
