pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// ScreenFilterService — the Hyprland screen shader (Quick Settings → Filter).
//
// `current` is the active shader's name ("" = off), read from Hyprland at
// startup and after each wallpaper change. refreshList() fills `list` from
// the shader directories; apply(name) sets it, and apply("") or applying
// the active one turns it off.
// ============================================================

Singleton {
    id: root

    property string current: ""
    property var    list:    []

    // Shader directories (space-separated). ~/.config/quickshell is a symlink
    // to the repo, so the last entry reaches the shaders Synapse ships;
    // ~/.config/hypr/shaders is for your own.
    property string shaderPaths: "~/.config/hypr/shaders ~/.local/share/hypr/shaders /usr/share/hyprshade/shaders ~/.config/quickshell/src/config/shaders"

    function refresh() { checkProc.running = false; checkProc.running = true }

    function refreshList() {
        list = []
        listProc.running = false
        listProc.running = true
    }

    function apply(name) {
        var turningOff = (name === "" || name === current)
        current = turningOff ? "" : name

        var isLua = ShellState.configProvider === "lua"

        // Force a full redraw so the shader change shows at once
        var damageCmd = isLua
            ? ` && hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' && hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'`
            : ` && hyprctl dispatch dpms off && hyprctl dispatch dpms on`

        if (turningOff) {
            var offCmd = isLua
                ? "hyprctl eval \"hl.config({ decoration = { screen_shader = '' } })\""
                : "hyprctl keyword decoration:screen_shader '[[EMPTY]]'"
            applyProc.command = ["bash", "-c", offCmd + damageCmd]
        } else {
            var resolveCmd =
                "TARGET=$(find " + shaderPaths +
                " -maxdepth 1 -type f \\( -name '" + name + ".glsl' -o -name '" + name + ".frag' \\)" +
                " 2>/dev/null | head -n 1); "
            var onCmd = isLua
                ? "if [ -n \"$TARGET\" ]; then hyprctl eval \"hl.config({ decoration = { screen_shader = '$TARGET' } })\"" + damageCmd + "; fi"
                : "if [ -n \"$TARGET\" ]; then hyprctl keyword decoration:screen_shader \"$TARGET\"" + damageCmd + "; fi"
            applyProc.command = ["bash", "-c", resolveCmd + onCmd]
        }

        applyProc.running = false
        applyProc.running = true
    }

    Process {
        id: checkProc
        command: ["bash", "-c",
            "hyprctl getoption decoration:screen_shader -j 2>/dev/null" +
            " | python3 -c \"" +
            "import sys,json,os;" +
            "d=json.load(sys.stdin);" +
            "s=d.get('str','').strip();" +
            "print('' if s in ('','[[EMPTY]]') else os.path.splitext(os.path.basename(s))[0])\""]
        running: false
        stdout: StdioCollector { onStreamFinished: root.current = text.trim() }
    }

    Process {
        id: applyProc
        command: []
        running: false
        onRunningChanged: if (!running) root.refresh()
    }

    Process {
        id: listProc
        // Every .glsl / .frag in the shader directories, without the extension
        command: ["bash", "-c", "find " + root.shaderPaths + " -maxdepth 1 -type f \\( -name '*.glsl' -o -name '*.frag' \\) 2>/dev/null | rev | cut -d/ -f1 | rev | sed 's/\\.[^.]*$//' | sort -u"]
        running: false
        stdout: SplitParser {
            onRead: function(l) {
                var n = l.trim()
                if (n !== "") root.list = root.list.concat([n])
            }
        }
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) { root.refresh() }
    }

    Component.onCompleted: refresh()
}
