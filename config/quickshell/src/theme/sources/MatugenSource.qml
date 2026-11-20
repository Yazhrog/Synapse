import QtQuick
import qs.src.core

// MatugenSource — the palette matugen writes to user_data/colors.json on a
// wallpaper change (template `synapse`, src/config/matugen.toml), reloaded
// live. Only the keys present in the file replace the current colour, so a
// missing, empty or half-written file keeps the previous palette (the
// fallback values of ColorSource until a good file has been read).
ColorSource {
    id: root

    property JsonStore _store: JsonStore {
        path:     Paths.userData("colors.json")
        readOnly: true
        watch:    true
        onDataChanged: root._apply(data)
    }

    function _apply(d) {
        if (!d || _store.error !== "") return
        if (d.background) root.background = d.background
        if (d.active)     root.accent     = d.active
        if (d.text)       root.text       = d.text
        if (d.subtext)    root.textMuted  = d.subtext
        if (d.border)     root.border     = d.border
        if (d.iconFont)   root.iconFont   = d.iconFont
    }
}
