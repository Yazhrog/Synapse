pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import "../."

// Global shell state.
//
// WiFi / Bluetooth  — written by QuickToggleService (nmcli / bluetoothctl) and BluetoothTab
// Night Light       — QuickToggleService (sunsetr)
// Caffeine          — QuickToggleService (wayland-idle-inhibitor)
// Hotspot           — written by HotspotService (nmcli hotspot)
// Airplane Mode     — written by QuickToggleService (rfkill)
// Focus Mode        — written by FocusModeService; the surface collapses the bar and its strut reserves nothing
// DND               — read by NotificationService to suppress incoming notifications
// VPN               — written by VPNTab; read by Network.qml for bar icon

QtObject {
    id: root

    
    
    property bool focusMode:    false
    property bool dnd:          false
    property bool screenRecord: false
    property bool hotspot:      false
    property bool airplane:     false

    // WiFi — false when radio is off OR hotspot is using the interface
    property bool wifiOn:       false

    // VPN — set by VPNTab, read by Network.qml bar indicator
    property bool   vpnActive:     false
    property bool   vpnConnecting: false
    property string vpnName:       ""

    // Bluetooth — written by BluetoothTab immediately on action, read by Network.qml
    // This avoids the 5s poll lag when a device disconnects or adapter toggles.
    property bool btPowered:   false   // adapter is on
    property bool btConnected: false   // at least one device connected

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