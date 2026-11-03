import QtQuick
import "../"

// SettingsDivider — thin separator between rows of a SettingsGroup.
Item {
    width:  parent ? parent.width : 0
    height: 1

    Rectangle {
        anchors {
            fill:        parent
            leftMargin:  Theme.settingsRowPadding
            rightMargin: Theme.settingsRowPadding
        }
        color: Qt.rgba(1, 1, 1, 0.07)
    }
}
