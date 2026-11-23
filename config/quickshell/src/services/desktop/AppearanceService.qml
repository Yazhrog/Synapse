pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.data
// AppearanceService — applies the Appearance prefs that live outside QML.
//
// Background blur is a Hyprland layer rule on the `synapse-frame` namespace,
// declared in config/hypr/modules/rules.lua as the global SynapseFrameBlur.
// rules.lua reads backgroundBlur from shell_prefs.json, so the rule survives
// `hyprctl reload`; this service toggles it live (Hypr.evalLua) when the
// pref changes. Blur only shows where the frame is translucent (opacity
// below 100 %). Needs the Lua config (Hypr.provider "lua").
Singleton {
    id: root

    readonly property bool blur: Prefs.ready && Prefs.data.backgroundBlur

    function applyBlur() {
        if (!Prefs.ready || Hypr.provider !== "lua") return
        Hypr.evalLua("if SynapseFrameBlur then SynapseFrameBlur:set_enabled(" + (root.blur ? "true" : "false") + ") end")
    }

    onBlurChanged: applyBlur()
}
