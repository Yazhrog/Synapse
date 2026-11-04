import QtQuick
import "../"

// SettingsTextField — a row with a one-line text field (paths, names).
//
// The value is committed on Enter or when the field loses focus, not on every
// keystroke; Escape reverts the edit. With `prefKey`, it reads and writes that
// PrefsService key; without it, set `text` and handle committed().
SettingsRow {
    id: root

    property string text:            prefKey !== "" ? String(PrefsService[prefKey] ?? "") : ""
    property string placeholderText: ""
    property int    fieldWidth:      220
    signal committed(string text)

    // Tab focuses the field itself (not the row, which would bounce focus
    // back into it on Shift+Tab).
    activeFocusOnTab: false

    function commit() {
        const next = input.text.trim()
        if (next === root.text) return
        if (root.prefKey !== "") PrefsService[root.prefKey] = next
        else root.text = next
        root.committed(next)
    }

    // Follow outside changes (reset button, hot reload) unless being edited.
    onTextChanged: if (!input.activeFocus) input.text = root.text

    Rectangle {
        width:  root.fieldWidth
        height: 28
        radius: 8
        color:  Qt.rgba(1, 1, 1, input.activeFocus ? 0.08 : 0.05)
        border.color: input.activeFocus
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
            : Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 110 } }

        TextInput {
            id: input
            anchors {
                left:           parent.left
                right:          parent.right
                leftMargin:     10
                rightMargin:    10
                verticalCenter: parent.verticalCenter
            }
            text:              root.text
            activeFocusOnTab:  true
            clip:              true
            selectByMouse:     true
            font.pixelSize:    11
            font.family:       "monospace"
            color:             Theme.text
            selectionColor:    Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40)
            selectedTextColor: Theme.text

            onAccepted:          { root.commit(); focus = false }
            onActiveFocusChanged: if (!activeFocus) root.commit()
            Keys.onEscapePressed: function(event) {
                if (input.text !== root.text) {
                    input.text = root.text
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            Text {
                anchors.fill:   parent
                visible:        input.text === "" && !input.activeFocus
                text:           root.placeholderText
                font:           input.font
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                elide:          Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        HoverHandler { cursorShape: Qt.IBeamCursor }
    }
}
