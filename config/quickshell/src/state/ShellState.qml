pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import qs.src.core
import qs.src.services.desktop
// Global shell state.
//
// Airplane Mode     — QuickToggleService.airplaneOn (rfkill)
// Focus Mode        — FocusModeService.active; the surface collapses the bar and its strut reserves nothing
// DND               — read by NotificationService to suppress incoming notifications
//
// Wi-Fi, Bluetooth, VPN, the hotspot, Night Light and Caffeine are read
// straight from their services (WifiService, BluetoothService, VpnService,
// HotspotService, QuickToggleService).

Singleton {
    id: root

    
    
    readonly property bool focusMode: FocusModeService.active
    property bool dnd:          false
    property bool screenRecord: false
    readonly property bool airplane: QuickToggleService.airplaneOn

    // ── Keybind Interception / Hyprland Submap Controller ─────────────────────
    
    property Process submapProcess: Process {}

    property Connections keybindListener: Connections {
        target: KeybindService 
        
        function onIsCapturingChanged() {
            if (KeybindService.isCapturing) {
                // Enter passthrough mode (disables Hyprland binds)
                if (configProvider === "lua") {
                    submapProcess.command = ["hyprctl", "dispatch", "hl.dsp.submap('Synapse_clean')"]
                } else {
                    submapProcess.command = ["hyprctl", "dispatch", "submap", "Synapse_clean"]
                }
            } else {
                // Exit passthrough mode (re-enables Hyprland binds)
                if (configProvider === "lua") {
                    submapProcess.command = ["hyprctl", "dispatch", "hl.dsp.submap('reset')"]
                } else {
                    submapProcess.command = ["hyprctl", "dispatch", "submap", "reset"]
                }
            }
            
            submapProcess.running = true
        }
    }
    
    property string configProvider: "lua"
    
    // Watch the JSON file written by the installer
    property var _providerFile: FileView {
        id: providerFile
        path: Paths.userData("config_Provider.json")
        watchChanges: true
        
        onFileChanged: {
            reload()
        }
        
        onLoaded: {
            _parse(providerFile.text())
        }
    }
    
    function _parse(jsonString) {
        if (!jsonString || jsonString === "") return;
        try {
            let data = JSON.parse(jsonString)
            if (data.configProvider) {
                root.configProvider = data.configProvider
            }
        } catch (e) {
            console.error("Synapse: Failed to parse config_Provider.json")
        }
    }
}