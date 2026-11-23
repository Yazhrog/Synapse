pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// ============================================================
// WallpaperService — wallpaper list + apply pipeline
//
// Flow:
//   wallpaper.json loaded (JsonStore) → currentWall etc.
//                                     → refresh() (populates wallpapers list)
//   apply(path) → awww img + ln -sf curr_wall + matugen
//               → saveConfig() (writes src/user_data/wallpaper.json)
//               → border colour through Hypr
// Every path goes to the commands as an argument, never into a script.
// ============================================================

Singleton {
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
    // Lists the folder again; a listing still running (of another folder,
    // say) is restarted, so the result always matches wallpaperDir.
    function refresh() {
        listProc.run()
    }

    // Switches the wallpaper folder (the panel's folder field): saved right
    // away, not only with the next applied wallpaper.
    function setFolder(path) {
        root.wallpaperDir = path
        if (_cfg.ready) saveConfig()
        refresh()
    }

    property Exec listProc: Exec {
        command: [
            "bash", "-c",
            "find \"$1\" -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.gif' -o -iname '*.webp' \\) | sort",
            // Quoted, so bash no longer expands "~" (the default folder is
            // "~/Pictures/Wallpapers"): expand it here.
            "--", Paths.expand(root.wallpaperDir)
        ]
        // Push everything to the UI at once
        onFinished: root.wallpapers = lastOutput.split("\n").map(l => l.trim()).filter(l => l !== "")
    }

    // ── Config — read at startup, then refresh() ─────────────────────────────
    property JsonStore _cfg: JsonStore {
        path:            root.configPath
        defaults:        ({ currentWall: "", wallpaperDir: "", scheme: "" })
        createIfMissing: false
        onLoaded: {
            const d = data
            if (d.currentWall)  root.currentWall  = d.currentWall
            if (d.wallpaperDir) root.wallpaperDir = d.wallpaperDir
            if (d.scheme)       root.scheme       = d.scheme
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
        _cfg.set({
            currentWall:  root.currentWall,
            wallpaperDir: root.wallpaperDir,
            scheme:       root.scheme
        })
    }

    // ── Apply pipeline ────────────────────────────────────────────────────────
    function apply(path) {
        if (root.applying || path === "") return
        root.applying    = true
        root.currentWall = path
        // Every path (the wallpaper's file name can be anything) and the scheme
        // are passed as arguments, never pasted into the script:
        //   $1 wallpaper  $2 wallpaper state dir  $3 curr_wall link
        //   $4 curr_wall_static  $5 matugen.toml  $6 scheme
        applyProc.run([
            "bash", "-c",
            "mkdir -p \"$2\" " +
            "&& awww img --transition-type grow --transition-step 200 --transition-duration 1.2 --transition-fps 60 --transition-pos bottom \"$1\" " +
            "&& ln -sf \"$1\" \"$3\" " +
            "&& (if [[ \"$1\" == *.gif ]]; then " +
            "rm -f \"$4\"; magick \"${1}[0]\" \"$4\" || true; " +
            "else ln -sf \"$1\" \"$4\"; fi) " +
            "&& matugen image \"$(readlink -f \"$4\")\" -c \"$5\" --source-color-index 0 --type \"scheme-$6\" " +
            "&& matugen image \"$(readlink -f \"$4\")\" --source-color-index 0 --type \"scheme-$6\" || true",
            "--", path, root._wallDir, root._currWall, root._currWallStatic,
            Quickshell.shellDir + "/src/config/matugen.toml", root.scheme
        ])
    }

    property Exec applyProc: Exec {
        onFinished: ok => {
            root.applying = false
            root.applyFinished(ok)
            if (ok) {
                root.wallpaperApplied(root.currentWall)
                root.saveConfig()

                updateBorders()
            }
        }
    }

    // Pushes the new primary color to the Hyprland border after an apply.
    // The color is read from the colors.lua / colors.conf matugen just wrote,
    // not from Theme.color.accent: Theme reloads colors.json asynchronously, so right
    // after an apply (or at startup, before colors.json is read) it still holds
    // the previous or fallback color.
    // Not called at startup: appearance.lua already loads colors.lua.
    function updateBorders() {
        if (Hypr.provider === "lua")
            primaryRead.run(["sed", "-n", 's/^M\\.primary *= *"\\([0-9a-fA-F]\\{6\\}\\)".*/\\1/p',
                             Paths.home + "/.config/hypr/modules/colors.lua"])
        else
            primaryRead.run(["sed", "-n", 's/^\\$primary *= *\\([0-9a-fA-F]\\{6\\}\\).*/\\1/p',
                             Paths.home + "/.config/hypr/colors.conf"])
    }

    property Exec primaryRead: Exec {
        onSucceeded: out => {
            const p = out.trim().split("\n")[0]
            if (/^[0-9a-fA-F]{6}$/.test(p))
                Hypr.setOptions("general", { "col.active_border": { colors: ["rgb(" + p + ")"] } })
        }
    }
}
