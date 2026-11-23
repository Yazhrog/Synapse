pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.desktop
// ============================================================
// ScreenFilterService — the Hyprland screen shader (Quick Settings → Filter).
//
// `current` is the active shader's name ("" = off), read from Hyprland at
// startup and after each wallpaper change. refreshList() fills `list` from
// the shader directories; apply(name) sets it, and apply("") or applying
// the active one turns it off. The shader is set through Hypr with its full
// path (looked up from the listing, never pasted into a shell string), then a
// DPMS off/on forces a full redraw so the change shows at once.
// ============================================================

Singleton {
    id: root

    property string current: ""
    property var    list:    []

    // Shader directories. ~/.config/quickshell is a symlink to the repo, so
    // the last entry reaches the shaders Synapse ships; ~/.config/hypr/shaders
    // is for your own.
    property var shaderDirs: ["~/.config/hypr/shaders", "~/.local/share/hypr/shaders",
                              "/usr/share/hyprshade/shaders", "~/.config/quickshell/src/config/shaders"]

    function refresh() { checkExec.run() }

    function refreshList() { list = []; listExec.run() }

    function apply(name) {
        const turningOff = name === "" || name === current
        current = turningOff ? "" : name
        if (turningOff) {
            Hypr.setOptions("decoration", { screen_shader: Hypr.provider === "conf" ? "[[EMPTY]]" : "" })
            _redraw()
            return
        }
        // Resolve the name to its file: the first .glsl / .frag in the dirs.
        resolveExec.run(_findArgs(name + ".glsl", name + ".frag"))
    }

    function _redraw() {
        Hypr.dispatch('hl.dsp.dpms({ action = "disable" })', ["dpms", "off"])
        Hypr.dispatch('hl.dsp.dpms({ action = "enable" })', ["dpms", "on"], () => root.refresh())
    }

    // find <dirs> -maxdepth 1 -type f ( -name a -o -name b )
    function _findArgs(a, b) {
        return ["find"].concat(shaderDirs.map(d => Paths.expand(d)))
            .concat(["-maxdepth", "1", "-type", "f", "(", "-name", a, "-o", "-name", b, ")"])
    }

    // find exits 1 when a directory is missing but still prints the others
    Exec {
        id: resolveExec
        onFinished: {
            const path = lastOutput.split("\n").map(l => l.trim()).find(l => l !== "") ?? ""
            if (path === "") { root.refresh(); return }
            Hypr.setOptions("decoration", { screen_shader: path })
            root._redraw()
        }
    }

    Exec {
        id: checkExec
        command: ["hyprctl", "getoption", "decoration:screen_shader", "-j"]
        onSucceeded: out => {
            let s = ""
            try { s = String(JSON.parse(out).str ?? "").trim() } catch (e) {}
            root.current = s === "" || s === "[[EMPTY]]" ? "" : s.split("/").pop().replace(/\.[^.]*$/, "")
        }
    }

    // Every .glsl / .frag in the shader directories, without the extension
    Exec {
        id: listExec
        command: root._findArgs("*.glsl", "*.frag")
        onFinished: root.list = Array.from(new Set(
            lastOutput.split("\n").map(l => l.trim()).filter(l => l !== "")
                      .map(p => p.split("/").pop().replace(/\.[^.]*$/, "")))).sort()
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) { root.refresh() }
    }

    Component.onCompleted: refresh()
}
