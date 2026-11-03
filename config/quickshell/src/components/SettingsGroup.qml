import QtQuick
import "../"

// SettingsGroup — a titled card stacking settings rows.
//
//   SettingsGroup {
//       title: "Updates"
//       SettingsToggle  { ... }
//       SettingsDivider {}
//       SettingsButton  { ... }
//   }
Column {
    id: group

    property string title: ""
    default property alias rows: body.data

    width:   parent ? parent.width : 0
    spacing: 8

    Text {
        visible:        group.title !== ""
        leftPadding:    4
        text:           group.title.toUpperCase()
        font.pixelSize: 9
        font.weight:    Font.Bold
        color:          Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
    }

    Rectangle {
        width:        parent.width
        height:       body.implicitHeight
        radius:       Theme.cornerRadius
        color:        Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1

        Column {
            id: body
            width: parent.width
        }
    }
}
