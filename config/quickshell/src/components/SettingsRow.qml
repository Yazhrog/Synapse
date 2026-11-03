import QtQuick
import "../"

// SettingsRow — base of the settings widgets: label and optional description
// on the left, a control on the right (the row's children), and a reset button
// when the PrefsService key in `prefKey` differs from its default.
//
// Used on its own for read-only rows, or through SettingsToggle,
// SettingsSlider, SettingsDropdown and SettingsButton. Place rows in a
// SettingsGroup, separated by SettingsDivider.
Item {
    id: row

    property string label:           ""
    property string description:     ""
    property bool   monoDescription: false
    // PrefsService key this row edits; enables the reset button.
    property string prefKey:         ""

    readonly property bool modified:
        prefKey !== "" && PrefsService[prefKey] !== PrefsService.defaults[prefKey]

    // The control on the right side of the row.
    default property alias control: slot.data
    // Optional content under the row's line (e.g. a dropdown's options).
    property alias below: belowSlot.data

    // Default reset: restore the pref's default. Override by handling
    // resetRequested and setting handleReset to false.
    property bool handleReset: true
    signal resetRequested()

    width:          parent ? parent.width : 0
    implicitHeight: line.height + (belowSlot.childrenRect.height > 0
                                   ? belowSlot.childrenRect.height + Theme.settingsRowPadding
                                   : 0)
    height:         implicitHeight

    Item {
        id: line
        width:  parent.width
        height: Math.max(Theme.settingsRowMinHeight,
                         texts.implicitHeight + 2 * Theme.settingsRowPadding)

        Column {
            id: texts
            anchors {
                left:           parent.left
                leftMargin:     Theme.settingsRowPadding
                right:          controls.left
                rightMargin:    12
                verticalCenter: parent.verticalCenter
            }
            spacing: 3

            Text {
                width:          parent.width
                text:           row.label
                font.pixelSize: 12
                color:          row.activeFocus ? Theme.active : Theme.text
                elide:          Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Text {
                width:          parent.width
                visible:        row.description !== ""
                text:           row.description
                font.pixelSize: row.monoDescription ? 11 : 10
                font.family:    row.monoDescription ? "monospace" : Qt.application.font.family
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b,
                                        row.monoDescription ? 0.70 : 0.45)
                elide:          row.monoDescription ? Text.ElideMiddle : Text.ElideRight
            }
        }

        Row {
            id: controls
            anchors {
                right:          parent.right
                rightMargin:    Theme.settingsRowPadding
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            ActionBtn {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modified
                icon:    "󰑓"
                onClicked: {
                    row.resetRequested()
                    if (row.handleReset) PrefsService.reset(row.prefKey)
                }
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
            leftMargin:  Theme.settingsRowPadding
            rightMargin: Theme.settingsRowPadding
        }
        height: childrenRect.height
    }
}
