import QtQuick
import "../"

// SettingsDropdown — a row with a choice from a list of options.
//
// `options` is a list of { value, label } (or plain strings). Clicking the
// button opens the list under the row, inline, so it never gets clipped by
// the popup window. With `prefKey`, the choice reads and writes that
// PrefsService key; without it, set `currentValue` and handle selected().
// Up/Down change the choice, Space/Enter open or close the list.
SettingsRow {
    id: root

    property var options:      []
    property var currentValue: prefKey !== "" ? PrefsService[prefKey] : undefined
    property bool open:        false
    signal selected(var value)

    activeFocusOnTab: true
    onActiveFocusChanged: if (!activeFocus) open = false

    function _value(o) { return (typeof o === "object" && o !== null) ? o.value : o }
    function _label(o) { return (typeof o === "object" && o !== null) ? o.label : String(o) }

    readonly property int _index: {
        for (let i = 0; i < root.options.length; i++)
            if (root._value(root.options[i]) === root.currentValue) return i
        return -1
    }

    function select(i) {
        if (i < 0 || i >= root.options.length) return
        const v = root._value(root.options[i])
        if (root.prefKey !== "") PrefsService[root.prefKey] = v
        else root.currentValue = v
        root.selected(v)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down) {
            root.select(Math.min(root.options.length - 1, root._index + 1)); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            root.select(Math.max(0, root._index - 1)); event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.open = !root.open; event.accepted = true
        } else if (event.key === Qt.Key_Escape && root.open) {
            root.open = false; event.accepted = true
        }
    }

    // ── Button showing the current choice ────────────────────────────────────
    Rectangle {
        width:  Math.max(110, btnRow.implicitWidth + 20)
        height: 28
        radius: 8
        color:  btnHover.hovered || root.open
            ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
        border.color: root.open
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
            : Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 110 } }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text:           root._index >= 0 ? root._label(root.options[root._index]) : "—"
                font.pixelSize: 11
                color:          Theme.text
            }
            Text {
                text:           root.open ? "󰅃" : "󰅀"
                font.pixelSize: 11
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.55)
            }
        }

        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            onClicked: { root.forceActiveFocus(); root.open = !root.open }
        }
    }

    // ── Options, shown inline under the row ──────────────────────────────────
    below: Column {
        width:   parent ? parent.width : 0
        visible: root.open
        height:  root.open ? implicitHeight : 0
        spacing: 2

        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool current: index === root._index

                width:  parent.width
                height: 28
                radius: 8
                color: current
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                    : (optHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors {
                        left:           parent.left
                        leftMargin:     10
                        verticalCenter: parent.verticalCenter
                    }
                    text:           root._label(modelData)
                    font.pixelSize: 11
                    color:          current ? Theme.active : Theme.text
                }

                HoverHandler { id: optHover; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.select(index); root.open = false }
                }
            }
        }
    }
}
