import QtQuick
import "../"

// SettingsButton — a row with an action button.
//
// `destructive` buttons are red and need a second click within 3s to fire
// (the first click turns the label into `confirmText`). Space/Enter press
// the button when the row has focus.
SettingsRow {
    id: root

    property string buttonText:  ""
    property string confirmText: "Confirm?"
    property bool   destructive: false
    property bool   busy:        false
    signal activated()

    property bool _confirming: false

    activeFocusOnTab: true
    enabled: !busy

    function press() {
        if (!root.enabled) return
        if (root.destructive && !root._confirming) {
            root._confirming = true
            confirmTimer.restart()
            return
        }
        root._confirming = false
        confirmTimer.stop()
        root.activated()
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root._confirming = false
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.press(); event.accepted = true
        }
    }

    readonly property color _tint: root.destructive ? "#f87171" : Theme.active

    Rectangle {
        width:   Math.max(104, label.implicitWidth + 24)
        height:  30
        radius:  8
        opacity: root.enabled ? 1.0 : 0.5
        color: Qt.rgba(root._tint.r, root._tint.g, root._tint.b,
                       root._confirming ? 0.30 : (btnHover.hovered ? 0.26 : 0.13))
        border.color: Qt.rgba(root._tint.r, root._tint.g, root._tint.b, 0.40)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text:           root._confirming ? root.confirmText : root.buttonText
            font.pixelSize: 11
            font.weight:    Font.Medium
            color:          root._tint
        }

        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: { root.forceActiveFocus(); root.press() }
        }
    }
}
