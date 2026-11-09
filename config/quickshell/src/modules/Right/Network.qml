import QtQuick
import Quickshell
import "../../components"
import "../../"

// Network — the bar's network icons: Wi-Fi / ethernet (with connectivity),
// VPN, Bluetooth and hotspot, each opening its tab of the network popup.
// State comes from WifiService, VpnService, BluetoothService and HotspotService.
Item {
    id: root

    implicitWidth:  row.implicitWidth + 6
    implicitHeight: row.implicitHeight

    readonly property string _netIcon: {
        if (WifiService.ethernet) return WifiService.limited ? "󰅢" : ""
        if (WifiService.signal <= 0) return "󰤭"
        if (WifiService.limited) return ""

        if (WifiService.signal > 75) return "󰤨"
        if (WifiService.signal > 50) return "󰤥"
        if (WifiService.signal > 25) return "󰤢"
        return "󰤟"
    }

    readonly property color _netColor: {
        if (!WifiService.ethernet && WifiService.signal <= 0) return Qt.rgba(1,1,1,0.28)
        if (WifiService.connectivity === "none")   return "#f87171"
        if (WifiService.limited)                   return "#f5c47a"
        return hov.hovered ? Theme.active : Theme.text
    }

    // VPN blink
    property real _vpnOpacity: 1.0
    SequentialAnimation on _vpnOpacity {
        running: VpnService.connecting; loops: Animation.Infinite
        NumberAnimation { to: 0.20; duration: 500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
    }
    Connections {
        target: VpnService
        function onConnectingChanged() {
            if (!VpnService.connecting) root._vpnOpacity = 1.0
        }
    }

    HoverHandler { id: hov }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        // WiFi/ethernet icon — opens to wifi tab
        Text {
            id: netIcon
            text:           root._netIcon
            color:          root._netColor
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.networkPage = "wifi"
                    Popups.open("network", QsWindow.window?.screen?.name ?? "")
                }
            }
        }

        // VPN shield — opens to vpn tab
        Text {
            visible:        VpnService.active || VpnService.connecting
            text:           VpnService.connecting ? "󱦚" : "󰦝"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            opacity:        root._vpnOpacity
            color: VpnService.active ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.70)
            Behavior on color   { ColorAnimation  { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 80  } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.networkPage = "vpn"
                    Popups.open("network", QsWindow.window?.screen?.name ?? "")
                }
            }
        }

        // Bluetooth — opens to bluetooth tab
        Text {
            visible:        BluetoothService.powered
            text:           BluetoothService.connected ? "󰂱" : "󰂯"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            color: BluetoothService.connected ? (hov.hovered ? Theme.active : Theme.text) : Qt.rgba(1,1,1,0.32)
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.networkPage = "bluetooth"
                    Popups.open("network", QsWindow.window?.screen?.name ?? "")
                }
            }
        }

        // Hotspot — opens to hotspot tab
        Text {
            visible:        HotspotService.on
            text:           "󰀂"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            color:          Theme.active
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.networkPage = "hotspot"
                    Popups.open("network", QsWindow.window?.screen?.name ?? "")
                }
            }
        }
    }
}
