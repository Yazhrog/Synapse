import QtQuick
import Quickshell.Io

// ============================================================
// ColorsLoader — watches ~/.config/Synapse/src/user_data/colors.json
// and exposes parsed color properties.
//
// Not a singleton. Instantiated as a property inside Theme.qml.
// Theme.qml reads loader.background, loader.active etc.
// ============================================================

QtObject {
    id: root

    // ── Parsed colors ─────────────────────────────────────────────────────────
    // Fallbacks are matugen's scheme-content palette for the default wallpaper
    // (synapse-default-0.png), so a missing colors.json looks like the default theme.
    property color background: "#141311"
    property color active:     "#f0e5bb"
    property color text:       "#e6e2dd"
    property color subtext:    "#ccc6b9"
    property color icon:       "#e6e2dd"
    property color border:     "#4a473c"
    property color iconFont:   "#d3c9a1"

    // ── File watcher ──────────────────────────────────────────────────────────
    property var _file: FileView {
        id: colorsFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(colorsFile.text())
    }

    property var _homeProc: Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h !== "")
                    colorsFile.path = h + "/.config/Synapse/src/user_data/colors.json"
            }
        }
    }

    // ── Parser ────────────────────────────────────────────────────────────────
    function _parse(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            if (obj.background) root.background = obj.background
            if (obj.active)     root.active     = obj.active
            if (obj.text)       { root.text = obj.text; root.icon = obj.text }
            if (obj.subtext)    root.subtext    = obj.subtext
            if (obj.border)     root.border     = obj.border
            if (obj.iconFont)   root.iconFont   = obj.iconFont
        } catch (e) {
            // Malformed JSON — keep fallback values
        }
    }
}
