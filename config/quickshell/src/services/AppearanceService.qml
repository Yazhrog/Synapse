pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// AppearanceService — applies the Appearance prefs that live outside QML.
//
// Background blur is a Hyprland layer rule on the `synapse-frame` namespace,
// declared in config/hypr/modules/rules.lua as the global SynapseFrameBlur.
// rules.lua reads backgroundBlur from shell_prefs.json, so the rule survives
// `hyprctl reload`; this service toggles it live with `hyprctl eval` when the
// pref changes. Blur only shows where the frame is translucent (opacity
// below 100 %). Needs the Lua config (ShellState.configProvider "lua").
Singleton {
    id: root

    readonly property bool blur: PrefsService.ready && PrefsService.backgroundBlur

    function applyBlur() {
        if (!PrefsService.ready || ShellState.configProvider !== "lua") return
        _blurProc.command = ["hyprctl", "eval",
            "if SynapseFrameBlur then SynapseFrameBlur:set_enabled(" + (root.blur ? "true" : "false") + ") end"]
        _blurProc.running = false
        _blurProc.running = true
    }

    onBlurChanged: applyBlur()

    property Process _blurProc: Process {}
}
