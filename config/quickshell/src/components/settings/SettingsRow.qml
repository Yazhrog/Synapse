import QtQuick
import qs.src.components.base
import qs.src.theme
// SettingsRow — base of the settings widgets: label and optional description
// on the left, a control on the right (the row's children), and a reset button
// while `modified` (it emits resetRequested()).
//
// Used on its own for read-only rows, or through SettingsToggle,
// SettingsSlider, SettingsDropdown and SettingsButton. Place rows in a
// SettingsGroup, separated by SettingsDivider. Presentational: the controls
// show `value` and report edits with edited(v); a container
// (features/dashboard/config/controls/Pref*.qml) binds them to a pref.
Item {
    id: row

    property string label:           ""
    property string description:     ""
    property bool   monoDescription: false
    // The control's value and the value the reset button restores; the
    // button shows while they differ (no defaultValue: never).
    property var value:        undefined
    property var defaultValue: undefined
    readonly property bool modified:
        defaultValue !== undefined && JSON.stringify(value) !== JSON.stringify(defaultValue)

    // The user changed the value (the container writes it).
    signal edited(var value)

    // The control on the right side of the row.
    default property alias control: slot.data
    // Optional content under the row's line (e.g. a dropdown's options).
    property alias below: belowSlot.data

    signal resetRequested()

    width:          parent ? parent.width : 0
    implicitHeight: line.height + (belowSlot.childrenRect.height > 0
                                   ? belowSlot.childrenRect.height + Theme.frame.settingsRowPadding
                                   : 0)
    height:         implicitHeight

    Item {
        id: line
        width:  parent.width
        height: Math.max(Theme.frame.settingsRowMinHeight,
                         texts.implicitHeight + 2 * Theme.frame.settingsRowPadding)

        Column {
            id: texts
            anchors {
                left:           parent.left
                leftMargin:     Theme.frame.settingsRowPadding
                right:          controls.left
                rightMargin:    12
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                width:          parent.width
                text:           row.label
                font.pixelSize: 12
                color:          row.activeFocus ? Theme.color.accent : Theme.color.text
                elide:          Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Text {
                width:          parent.width
                visible:        row.description !== ""
                text:           row.description
                font.pixelSize: row.monoDescription ? 11 : 10
                font.family:    row.monoDescription ? "monospace" : Qt.application.font.family
                color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b,
                                        row.monoDescription ? 0.70 : 0.45)
                elide:          row.monoDescription ? Text.ElideMiddle : Text.ElideRight
            }
        }

        Row {
            id: controls
            anchors {
                right:          parent.right
                rightMargin:    Theme.frame.settingsRowPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            ActionBtn {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modified
                icon:    "󰑓"
                onClicked: row.resetRequested()
            }

            Item {
                id: slot
                anchors.verticalCenter: parent.verticalCenter
                width:  childrenRect.width
                height: childrenRect.height
            }
        }
    }

    Item {
        id: belowSlot
        anchors {
            top:         line.bottom
            left:        parent.left
            right:       parent.right
            leftMargin:  Theme.frame.settingsRowPadding
            rightMargin: Theme.frame.settingsRowPadding
        }
        height: childrenRect.height
    }
}
