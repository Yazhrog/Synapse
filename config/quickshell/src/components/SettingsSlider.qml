import QtQuick
import "../"

// SettingsSlider — a row with a slider and its current value.
//
// With `prefKey`, the slider reads and writes that PrefsService key
// (PrefsService debounces the save). Without it, set `value` and handle
// moved(). Left/Right (or Down/Up) move it by `stepSize` when the row has
// focus.
SettingsRow {
    id: root

    property real   from:     0
    property real   to:       100
    property real   stepSize: 1
    property int    decimals: 0
    property string unit:     ""
    property real   value:    prefKey !== "" ? Number(PrefsService[prefKey]) : from
    signal moved(real value)

    activeFocusOnTab: true

    function setValue(v) {
        let next = Math.max(root.from, Math.min(root.to, v))
        if (root.stepSize > 0)
            next = root.from + Math.round((next - root.from) / root.stepSize) * root.stepSize
        next = Number(next.toFixed(root.decimals))
        if (next === root.value) return
        if (root.prefKey !== "") PrefsService[root.prefKey] = next
        else root.value = next
        root.moved(next)
    }

    readonly property real _ratio: root.to > root.from
        ? (root.value - root.from) / (root.to - root.from) : 0

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) {
            root.setValue(root.value + root.stepSize); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            root.setValue(root.value - root.stepSize); event.accepted = true
        }
    }

    Row {
        spacing: 10

        Item {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width:  140
            height: 18

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  parent.width
                height: 4
                radius: 2
                color:  Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width:  parent.width * root._ratio
                    height: parent.height
                    radius: parent.radius
                    color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.70)
                }
            }

            Rectangle {
                width:  14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x:      (track.width - width) * root._ratio
                color:  Theme.active
                scale:  drag.pressed || drag.containsMouse ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: 110 } }
            }

            MouseArea {
                id: drag
                anchors.fill:  parent
                hoverEnabled:  true
                cursorShape:   Qt.PointingHandCursor
                function _apply(mx) {
                    root.setValue(root.from + Math.max(0, Math.min(1, mx / track.width)) * (root.to - root.from))
                }
                onPressed:         function(mouse) { root.forceActiveFocus(); _apply(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) _apply(mouse.x) }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width:          44
            horizontalAlignment: Text.AlignRight
            text:           root.value.toFixed(root.decimals) + root.unit
            font.pixelSize: 11
            font.family:    "monospace"
            color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.70)
        }
    }
}
