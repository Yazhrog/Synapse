import QtQuick
import qs.src.core.specs
// NetworkTabs — the network popup's tabs, in order. The tab bar, the page
// area (a tab exists only while shown) and the toggle actions read it.
QtObject {
    readonly property list<PageSpec> pages: [
        PageSpec {
            key: "wifi"; label: "Wi-Fi"; icon: "󰤨"
            action: "wifi-toggle"; actionLabel: "Network: Wi-Fi"
            component: Component { WifiTab {} }
        },
        PageSpec {
            key: "bluetooth"; label: "Bluetooth"; icon: "󰂯"
            action: "bt-toggle"; actionLabel: "Network: Bluetooth"
            component: Component { BluetoothTab {} }
        },
        PageSpec {
            key: "vpn"; label: "VPN"; icon: "󰦝"
            action: "vpn-toggle"; actionLabel: "Network: VPN"
            component: Component { VPNTab {} }
        },
        PageSpec {
            key: "hotspot"; label: "Hotspot"; icon: "󰀃"
            action: "hotspot-toggle"; actionLabel: "Network: Hotspot"
            component: Component { HotspotTab {} }
        }
    ]
}
