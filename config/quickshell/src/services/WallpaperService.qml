pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// WallpaperService — wallpaper list + apply pipeline
//
// Flow:
//   Component.onCompleted → readConfigProc (sets currentWall etc.)
//                         → refresh() (populates wallpapers list)
//   apply(path)           → awww img + ln -sf curr_wall + matugen
//                         → saveConfig() (writes src/user_data/wallpaper.json)
// ============================================================

QtObject {
    id: root

    // ── Paths ─────────────────────────────────────────────────────────────────
    readonly property string configPath:      Paths.userData("wallpaper.json")
    readonly property string _wallDir:        Paths.wallpaperDir
    readonly property string _currWall:       _wallDir + "/curr_wall"
    readonly property string _currWallStatic: _wallDir + "/curr_wall_static.jpg"
    readonly property string defaultWall:     Quickshell.shellDir + "/src/assets/wallpapers/synapse-default-0.png"
    readonly property string defaultWallpaperDir: "~/Pictures/Wallpapers"
    readonly property string defaultScheme:   "content"

    // ── State ─────────────────────────────────────────────────────────────────
    property var    wallpapers:   []
    property var    tempWalls:   []
    property string currentWall:  ""
    property string previewWall:  ""
    property string scheme:       defaultScheme
    property bool   applying:     false
    property string wallpaperDir: defaultWallpaperDir

    readonly property var schemes: [
        "content", "tonal-spot", "fidelity", "fruit-salad", "neutral", "monochrome"
    ]

    // Emitted when the full apply pipeline exits cleanly (exitCode === 0).
    signal wallpaperApplied(string path)
    // Every apply ends with this, successful or not.
    signal applyFinished(bool ok)

    // ── File listing ──────────────────────────────────────────────────────────
    function refresh() {
        if (listProc.running) return
        root.tempWalls = [] // Clear the temp array, not the live one yet
        listProc.running = true
    }

    property var listProc: Process {
        command: [
            "bash", "-c",
            "find " + root.wallpaperDir + " -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.gif' -o -iname '*.webp' \\) | sort"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t !== "") root.tempWalls.push(t)
            }
        }
        onExited: function() {
            // Push everything to the UI at once
            root.wallpapers = root.tempWalls
        }
    }

    // ── Config read — runs on startup, then calls refresh() ──────────────────
    property string _cfgBuf: ""
    property var readConfigProc: Process {
        command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) { root._cfgBuf += line }
        }
        onExited: function() {
            if (root._cfgBuf !== "") {
                try {
                    var obj = JSON.parse(root._cfgBuf)
                    if (obj.currentWall  && obj.currentWall  !== "") root.currentWall  = obj.currentWall
                    if (obj.wallpaperDir && obj.wallpaperDir !== "") root.wallpaperDir = obj.wallpaperDir
                    if (obj.scheme       && obj.scheme       !== "") root.scheme       = obj.scheme
                } catch(e) {}
            }
            if (root.currentWall === "") root.apply(root.defaultWall)
            root.refresh()
        }
    }

    // ── Reset (Config → Data & Storage) ──────────────────────────────────────
    // Default wallpaper, folder and scheme; wallpaper.json is rewritten once
    // the default wallpaper is applied. Returns false (and changes nothing)
    // while another apply is running; applyFinished reports the result.
    function resetToDefaults() {
        if (root.applying) return false
        root.scheme       = root.defaultScheme
        root.wallpaperDir = root.defaultWallpaperDir
        root.apply(root.defaultWall)
        root.refresh()
        return true
    }

    // ── Config write — called after a successful apply ────────────────────────
    function saveConfig() {
        var json = JSON.stringify({
            currentWall:  root.currentWall,
            wallpaperDir: root.wallpaperDir,
            scheme:       root.scheme
        })
        // Use printf so the content is never misinterpreted as shell commands.
        // Single-quote the config path (paths rarely contain single quotes).
        saveConfigProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%s' " + Paths.shellQuote(json) + " > " + Paths.shellQuote(root.configPath)
        ]
        saveConfigProc.running = true
    }

    property var saveConfigProc: Process {}   // silent — no stdout/stderr needed

    // ── Apply pipeline ────────────────────────────────────────────────────────
    function apply(path) {
        if (root.applying || path === "") return
        root.applying    = true
        root.currentWall = path
        applyProc.command = [
            "bash", "-c",
            "mkdir -p '" + root._wallDir + "' " +
            "&& awww img --transition-type grow --transition-step 200 --transition-duration 1.2 --transition-fps 60 --transition-pos bottom \"" + path + "\" " +
            "&& ln -sf \"" + path + "\" '" + root._currWall + "' " +
            "&& (if [[ \"" + path + "\" == *.gif ]]; then " +
            "rm -f '" + root._currWallStatic + "'; magick \"" + path + "[0]\" '" + root._currWallStatic + "' || true; " +
            "else ln -sf \"" + path + "\" '" + root._currWallStatic + "'; fi) " +
            "&& matugen image \"$(readlink -f '" + root._currWallStatic + "')\" -c \"" + Quickshell.shellDir + "/src/config/matugen.toml\" --source-color-index 0 --type scheme-" + root.scheme + " " +
            "&& matugen image \"$(readlink -f '" + root._currWallStatic + "')\" --source-color-index 0 --type scheme-" + root.scheme + " || true"
        ]
        applyProc.running = true
    }
    
    property Process applyProc: Process {
        onExited: function(exitCode, exitStatus) {
            root.applying = false
            root.applyFinished(exitCode === 0)
            if (exitCode === 0) {
                root.wallpaperApplied(root.currentWall)
                root.saveConfig()

                updateBorders()
            }
        }
    }

    // Pushes the new primary color to the Hyprland border after an apply.
    // The color is read from the colors.lua / colors.conf matugen just wrote,
    // not from Theme.active: Theme reloads colors.json asynchronously, so right
    // after an apply (or at startup, before colors.json is read) it still holds
    // the previous or fallback color.
    // Not called at startup: appearance.lua already loads colors.lua.
    function updateBorders() {
        if (ShellState.configProvider === "lua") {
            borderUpdateProc.command = [
                "bash", "-c",
                "p=$(sed -n 's/^M\\.primary *= *\"\\([0-9a-fA-F]\\{6\\}\\)\".*/\\1/p' \"$HOME/.config/hypr/modules/colors.lua\"); " +
                "[ -n \"$p\" ] && hyprctl eval \"hl.config({ general = { [\\\"col.active_border\\\"] = { colors = { \\\"rgb($p)\\\" } } } })\""
            ]
        } else {
            borderUpdateProc.command = [
                "bash", "-c",
                "p=$(sed -n 's/^\\$primary *= *\\([0-9a-fA-F]\\{6\\}\\).*/\\1/p' \"$HOME/.config/hypr/colors.conf\"); " +
                "[ -n \"$p\" ] && hyprctl keyword general:col.active_border \"rgb($p)\""
            ]
        }
        borderUpdateProc.running = true
    }

    property Process borderUpdateProc: Process {
        command: []
    }

    Component.onCompleted: readConfigProc.running = true
}
