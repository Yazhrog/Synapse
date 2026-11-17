import Quickshell
import QtQuick
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
// framework lives in this folder (popup and action manifests join in #144 and
// #145).
Scope {
    // Singletons are created on first use: these need to run from startup.
    property var _keybinds:   KeybindService
    property var _updater:    UpdateService
    property var _ipc:        IpcManager
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
        function onCritical(level) { Popups.showBatteryCritical(level) }
    }

    // One Dynamic Surface per screen (#37): frame, bar and every popup.
    ShellHost {}
}
