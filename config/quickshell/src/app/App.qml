import Quickshell
import QtQuick
import qs.src.actions
import qs.src.features.bar
import qs.src.services.data
import qs.src.services.desktop
import qs.src.services.media
import qs.src.services.network
import qs.src.services.system
import qs.src.services.time
import qs.src.state
import qs.src.surface
// App — the composition root: starts the services that must run from boot
// and creates the per-screen shell. Everything that wires features into the
// framework lives in this folder: the popup, action and bar manifests.
Scope {
    // Singletons are created on first use: these need to run from startup.
    property var _keybinds:   KeybindService
    property var _updater:    UpdateService
    property var _ipc:        IpcBridge
    property var _battery:    BatteryWarningService
    property var _focusMode:  FocusModeService
    property var _appearance: AppearanceService
    property var _clock:      ClockService
    property var _toggles:    QuickToggleService
    property var _hotspot:    HotspotService
    property var _filter:     ScreenFilterService
    property var _tasks:      TaskService
    property var _wifi:       WifiService
    property var _bluetooth:  BluetoothService
    property var _vpn:        VpnService

    // Services raise events; opening UI for them is wired here.
    Connections {
        target: BatteryWarningService
        function onCritical(level) {
            Dialogs.alert({
                title:   "Critical Battery",
                message: "Battery at " + level + "% — plug in now to avoid losing your work.",
                label:   "Acknowledge"
            })
        }
    }

    // Every popup and the surface's passive parts (the surface never imports
    // a feature): SurfaceState takes the keys and regions, the surface the rest.
    PopupManifest { id: manifest }
    Binding { target: SurfaceState; property: "popups"; value: manifest.popups }

    // Every action (the popups' toggles are generated from their specs):
    // IpcBridge creates the IPC handlers from the registry.
    ActionManifest { id: actionManifest; popups: manifest.popups }
    Binding { target: Actions; property: "actions"; value: actionManifest.actions }

    // The bar's widgets, by zone (the surface never imports them either).
    BarWidgets { id: barWidgets }

    // One Dynamic Surface per screen (#37): frame, bar and every popup.
    ShellHost { manifest: manifest; barWidgets: barWidgets.widgets }
}
