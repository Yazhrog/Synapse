pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ─────────────────────────────────────────────────────────────
// IpcManager — centralized entry point for all external IPC signals.
//
// Handlers live in this singleton so that, with one surface per screen,
// only ONE handler reacts to a signal.
// ─────────────────────────────────────────────────────────────

QtObject {
    id: root

    // ── Dashboard Toggles ────────────────────────────────────
    
    property var dashboardHome: IpcHandler {
        target: "dashboard-home"
        function toggle() {
            Popups.togglePage("dashboard", "home")
        }
    }

    property var dashboardStats: IpcHandler {
        target: "dashboard-stats"
        function toggle() {
            Popups.togglePage("dashboard", "stats")
        }
    }

    property var dashboardKanban: IpcHandler {
        target: "dashboard-kanban"
        function toggle() {
            Popups.togglePage("dashboard", "kanban")
        }
    }

    property var dashboardLauncher: IpcHandler {
        target: "dashboard-launcher"
        function toggle() {
            Popups.togglePage("dashboard", "launcher")
        }
    }

    property var dashboardConfig: IpcHandler {
        target: "dashboard-config"
        function toggle() {
            Popups.togglePage("dashboard", "config")
        }
    }

    // ── Audio Toggles ────────────────────────────────────────

    property var audioOut: IpcHandler {
        target: "audioOut-toggle"
        function toggle() {
            Popups.togglePage("audio", "output")
        }
    }

    property var audioMix: IpcHandler {
        target: "audioMix-toggle"
        function toggle() {
            Popups.togglePage("audio", "mixer")
        }
    }

    property var audioIn: IpcHandler {
        target: "audioIn-toggle"
        function toggle() {
            Popups.togglePage("audio", "input")
        }
    }

    // ── Network Toggles ──────────────────────────────────────

    property var wifiToggle: IpcHandler {
        target: "wifi-toggle"
        function toggle() {
            Popups.togglePage("network", "wifi")
        }
    }

    property var btToggle: IpcHandler {
        target: "bt-toggle"
        function toggle() {
            Popups.togglePage("network", "bluetooth")
        }
    }

    property var vpnToggle: IpcHandler {
        target: "vpn-toggle"
        function toggle() {
            Popups.togglePage("network", "vpn")
        }
    }

    property var hotspotToggle: IpcHandler {
        target: "hotspot-toggle"
        function toggle() {
            Popups.togglePage("network", "hotspot")
        }
    }

    // ── Misc Toggles ─────────────────────────────────────────

    property var notifications: IpcHandler {
        target: "notifications-toggle"
        function toggle() {
            Popups.toggle("notifications")
        }
    }

    property var clipboard: IpcHandler {
        target: "clipboard-toggle"
        function toggle() {
            Popups.toggle("clipboard")
        }
    }

    property var wallpaper: IpcHandler {
        target: "wallpaper-toggle"
        function toggle() {
            Popups.toggle("wallpaper")
        }
    }

    property var archMenu: IpcHandler {
        target: "PowerMenu-toggle"
        function toggle() {
            Popups.toggle("powerMenu")
        }
    }

    property var screenRec: IpcHandler {
        target: "screenrec-on"
        function toggle() {
            if (ScreenRecService.recording) {
                 ScreenRecService.stopRecording()
             } else if (ShellState.screenRecord) {
                 ScreenRecService.cancelSetup()
             } else {
                 Popups.closeAll()
                 ShellState.screenRecord = true
             }
        }
    }

    property var focusMode: IpcHandler {
        target: "focus-toggle"
        function toggle() {
            root.focusToggleRequested()
        }
    }

    signal focusToggleRequested()

    // ── Quick Controls OSD (volume/brightness keys) ──────────
    // Reveals the Quick Controls OSD briefly, then auto-hides — see
    // Popups.anyOpen for why quickOpen stays out of the shared popup set.
    // NOTE: the handler function must not be named "show" — that collides
    // with quickshell's own "qs ipc show" introspection verb and silently
    // no-ops instead of calling into this function.
    property var quickControlsHideTimer: Timer {
        id: quickControlsHideTimer
        interval: 1800
        // Hovering the OSD keeps it open; check again after another interval.
        onTriggered: Popups.quickHeld ? quickControlsHideTimer.restart() : Popups.hideQuick()
    }

    property var quickControls: IpcHandler {
        target: "quickcontrols-show"
        function reveal() {
            Popups.showQuick()
            quickControlsHideTimer.restart()
        }
    }
}
