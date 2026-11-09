import QtQuick
import "../../"

// EthernetRow — the wired connection at the top of the Wi-Fi tab, shown
// whenever a cable is connected (also while Wi-Fi is off).

Rectangle {
    id: root
    height: 48; radius: Theme.cornerRadius
    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18); border.width: 1

    Text {
        id: icon
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: WifiService.limited ? "󰅢" : ""; font.pixelSize: 16
        color: WifiService.connectivity === "none" ? "#f87171" : WifiService.limited ? "#f5c47a" : Theme.active
    }
    Column {
        anchors { left: icon.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text {
            width: parent.width; elide: Text.ElideRight
            text: WifiService.ethernetName !== "" ? WifiService.ethernetName : "Ethernet"
            font.pixelSize: 13; font.weight: Font.Medium; color: Theme.text
        }
        Text {
            text: WifiService.connectivity === "none" ? "Connected, no internet"
                : WifiService.limited ? "Connected, limited" : "Connected"
            font.pixelSize: 10
            color: WifiService.limited ? "#f5c47a" : Theme.active
        }
    }
}
