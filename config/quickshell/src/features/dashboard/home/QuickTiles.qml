import QtQuick
import qs.src.actions
import qs.src.core.specs
import qs.src.services.desktop
import qs.src.services.media
import qs.src.services.network
import qs.src.services.notifications
import qs.src.state
// QuickTiles — the Quick Settings tiles, in grid order (ARCHITECTURE.md §10.4).
// Each tile binds a service's state and calls its intents; toggle(host) gets
// the Quick Settings card.
QtObject {
    readonly property bool _wifiShown: WifiService.radioOn && !HotspotService.on

    readonly property list<TileSpec> tiles: [
        TileSpec {
            key: "wifi"; label: "Wi-Fi"; indicator: true
            on:       _wifiShown
            icon:     _wifiShown ? "󰤨" : "󰤭"
            sublabel: _wifiShown && WifiService.ssid !== "" ? WifiService.ssid
                                                            : (HotspotService.on ? "Used by Hotspot" : "")
            toggle:   host => WifiService.toggleRadio()
        },
        TileSpec {
            key: "bluetooth"; label: "Bluetooth"; indicator: true
            on:       BluetoothService.powered
            icon:     BluetoothService.powered ? "󰂱" : "󰂲"
            sublabel: BluetoothService.powered ? BluetoothService.connectedName : ""
            toggle:   host => BluetoothService.togglePower()
        },
        TileSpec {
            key: "airplane"; label: "Airplane Mode"; icon: "󰀝"; indicator: true
            on:     QuickToggleService.airplaneOn
            toggle: host => QuickToggleService.toggleAirplane()
        },
        TileSpec {
            key: "hotspot"; label: "Hotspot"; icon: "󰀃"
            on:       HotspotService.on || HotspotService.busy
            sublabel: HotspotService.label
            toggle:   host => HotspotService.toggle()
        },
        TileSpec {
            key: "nightLight"; label: "Night Light"; icon: "󰖐"
            on:     QuickToggleService.nightLightOn
            toggle: host => QuickToggleService.toggleNightLight()
        },
        TileSpec {
            key: "caffeine"; label: "Caffeine"; icon: "󰅶"
            on:     QuickToggleService.caffeineOn
            toggle: host => QuickToggleService.toggleCaffeine()
        },
        TileSpec {
            key: "focus"; label: "Focus Mode"
            on:     ShellModes.focusMode
            icon:   ShellModes.focusMode ? "󱃕" : "󰍻"
            toggle: host => Actions.run("focus-toggle")
        },
        TileSpec {
            key: "dnd"; label: "Do Not Disturb"; indicator: true
            on:     ShellModes.dnd
            icon:   ShellModes.dnd ? "󰂛" : "󰂚"
            toggle: host => NotificationService.dnd = !NotificationService.dnd
        },
        TileSpec {
            key: "screenrec"
            on:     ShellModes.screenRecord || ScreenRecService.recording
            icon:   ScreenRecService.recording ? "⏹" : "󰻂"
            label:  ScreenRecService.recording ? "Recording" : "Screen Capture"
            toggle: host => Actions.run("screenrec-on")
        },
        // Opens the shader picker of the card; does not toggle directly.
        TileSpec {
            key: "filter"; label: "Filter"; icon: "󱡓"
            on:       ScreenFilterService.current !== ""
            sublabel: ScreenFilterService.current
            toggle:   host => host.openFilterPicker()
        }
    ]
}
