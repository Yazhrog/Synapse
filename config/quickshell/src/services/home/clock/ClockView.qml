import QtQuick
import "../../../"

// ClockView — the big stacked HH / MM clock with seconds (and AM/PM).

Item {
    id: root

    readonly property bool   _h24: PrefsService.use24HourClock
    readonly property string _hStr: ClockState.zp(_h24 ? ClockState.hours : (ClockState.hours % 12 || 12))
    readonly property string _ampm: _h24 ? "" : (ClockState.hours < 12 ? "AM" : "PM")

    Row {
        anchors.centerIn: parent
        spacing: 10

        // HH stacked above MM with diagonal offset
        Item {
            anchors.verticalCenter: parent.verticalCenter
            // Width fits both texts plus the one-char offset
            readonly property int charOffset: 40
            width:  hhText.implicitWidth + charOffset
            height: hhText.implicitHeight + mmText.implicitHeight - 8

            Text {
                id: hhText
                anchors.left: parent.left
                anchors.top:  parent.top
                text: root._hStr
                font.pixelSize: 72; font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: -4
                color: Theme.text
            }
            Text {
                id: mmText
                anchors.left: parent.left
                anchors.leftMargin: parent.charOffset
                anchors.top:  hhText.bottom
                anchors.topMargin: -8
                text: ClockState.zp(ClockState.minutes)
                font.pixelSize: 72; font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: -4
                color: Theme.active
            }
        }

        // Seconds (and AM/PM in 12-hour mode) — centered beside the stack
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: ClockState.zp(ClockState.seconds)
                font.pixelSize: 22; font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
            }
            Text {
                visible: root._ampm !== ""
                text: root._ampm
                font.pixelSize: 13; font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.70)
            }
        }
    }
}
