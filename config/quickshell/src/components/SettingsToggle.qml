import QtQuick
import "../"

// SettingsToggle — a row with a pill switch.
//
// With `prefKey`, the switch reads and writes that PrefsService key. Set
// `autoWrite: false` to only emit toggled() and write the value yourself
// (e.g. through a service that has side effects). Space/Enter toggle it
// when the row has focus.
SettingsRow {
    id: root

    property bool checked:   prefKey !== "" ? !!PrefsService[prefKey] : false
    property bool autoWrite: true
    signal toggled(bool checked)

    activeFocusOnTab: true

    function toggle() {
        const next = !root.checked
        if (root.prefKey !== "" && root.autoWrite)
            PrefsService[root.prefKey] = next
        else if (root.prefKey === "")
            root.checked = next
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
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
            : Qt.rgba(1, 1, 1, 0.07)
        border.color: root.checked
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
            : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            width:  18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x:     root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.active : Qt.rgba(1, 1, 1, 0.35)
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
