import QtQuick
import "../components"
import "../"

// NetworkContent — the network popup's UI: the Wi-Fi / Bluetooth / VPN /
// Hotspot tab pages and the tab bar. Hosted by NetworkPopup (legacy) and the
// right region of DynamicSurface.
Item {
    id: root

    property string page: "wifi"

    // ── Tab page area ─────────────────────────────────────────────────
    Item {
        id: tabContent
        anchors {
            top:    parent.top
            left:   parent.left
            right:  parent.right
            bottom: tabBar.top
        }

        Loader {
            anchors.fill: parent
            active:       root.page === "wifi"
            source:       "WifiTab.qml"
        }

        Loader {
            anchors.fill: parent
            active:       root.page === "bluetooth"
            source:       "BluetoothTab.qml"
        }

        // VPN — WireGuard connections
        Loader {
            anchors.fill: parent
            active:       root.page === "vpn"
            source:       "VPNTab.qml"
        }

        // Hotspot — virtual AP interface
        Loader {
            anchors.fill: parent
            active:       root.page === "hotspot"
            source:       "HotspotTab.qml"
        }
    }

    // ── Tab bar — lifted by cornerRadius from the popup bottom ────────
    TabSwitcher {
        id: tabBar
        anchors {
            left:         parent.left
            right:        parent.right
            bottom:       parent.bottom
            bottomMargin: -16
        }
        orientation: "horizontal"
        width:        parent.width
        currentPage:  root.page
        model: [
            { key: "wifi",      icon: "󰤨", label: "Wi-Fi"     },
            { key: "bluetooth", icon: "󰂯", label: "Bluetooth" },
            { key: "vpn",       icon: "󰦝", label: "VPN"       },
            { key: "hotspot",   icon: "󰀃", label: "Hotspot"   },
        ]
        onPageChanged: function(key) { Popups.networkPage = key }
    }
}
