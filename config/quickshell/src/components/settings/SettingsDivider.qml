import QtQuick
import qs.src.theme
// SettingsDivider — thin separator between rows of a SettingsGroup.
Item {
    width:  parent ? parent.width : 0
    height: 1

    Rectangle {
        anchors {
            fill:        parent
            leftMargin:  Theme.frame.settingsRowPadding
            rightMargin: Theme.frame.settingsRowPadding
        }
        color: Qt.rgba(1, 1, 1, 0.07)
    }
}
