pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../"

// ============================================================
// SurfaceState — what interactive popup is open, and on which screen.
//
// One popup at a time, globally. Each popup belongs to a region of the
// Dynamic Surface (#37); `regionOf` is the single mapping. Code that opens
// or closes popups goes through Popups.open/close/toggle, which call here;
// Popups.xxxOpen are read-only views of this state.
//
// Passive content (the volume/brightness OSD, notification toasts) is not
// tracked here: it must never close an open popup or take the keyboard.
// ============================================================

Singleton {
    id: root

    property string activeScreen:  ""       // screen name owning the open popup, "" = none
    property string activeRegion:  "none"
    property string activeContent: "none"

    readonly property bool anyOpen: activeContent !== "none"

    readonly property var regionOf: ({
        dashboard:     "top",
        network:       "right",
        notifications: "right",
        audio:         "rightCenter",
        powerMenu:     "leftCenter",
        wallpaper:     "bottomCenter",
        clipboard:     "bottomRight"
    })

    function _focusedScreen(): string {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    // The screen-recording setup owns the screen: nothing opens over it.
    readonly property bool _blocked: ShellState.screenRecord && !ScreenRecService.recording

    // ── Resolution scaling ──────────────────────────────────────────────────
    // Surface sizes are designed for a 1080 px tall screen. The factor comes
    // from PrefsService.surfaceScale: "off" → 1, "auto" → screen height / 1080
    // clamped to [0.75, 1.5] (on top of Hyprland's own monitor scale), or a
    // fixed number. SYNAPSE_SURFACE_SCALE overrides it for testing.
    readonly property real _forcedScale: Number(Quickshell.env("SYNAPSE_SURFACE_SCALE") ?? 0) || 0

    function scaleFor(screen): real {
        if (root._forcedScale > 0) return root._forcedScale
        const mode = PrefsService.surfaceScale
        if (mode === "auto") {
            if (!screen || !screen.height) return 1.0
            return Math.max(0.75, Math.min(1.5, screen.height / 1080))
        }
        const fixed = Number(mode)
        return fixed > 0 ? Math.max(0.5, Math.min(2.0, fixed)) : 1.0
    }

    function isOpen(content: string): bool {
        return root.activeContent === content
    }

    function open(content, screenName) {
        if (!(content in root.regionOf)) {
            console.warn("SurfaceState: unknown content", content)
            return false
        }
        if (root._blocked) return false
        root.activeScreen  = screenName || root._focusedScreen()
        root.activeRegion  = root.regionOf[content]
        root.activeContent = content
        return true
    }

    // Closes the open popup. With `content`, only if that popup is the open one,
    // so a late close from a popup that was already replaced is harmless.
    function close(content) {
        if (!root.anyOpen) return
        if (content && content !== root.activeContent) return
        root.activeScreen  = ""
        root.activeRegion  = "none"
        root.activeContent = "none"
    }

    // Closes `content` if it's open on that screen, otherwise opens it there.
    function toggle(content, screenName) {
        const screen = screenName || root._focusedScreen()
        if (root.activeContent === content && root.activeScreen === screen) {
            root.close()
            return false
        }
        return root.open(content, screen)
    }
}
