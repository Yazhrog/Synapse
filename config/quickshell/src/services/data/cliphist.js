// cliphist.js — parser for `cliphist list` output, used by ClipboardService.
//
// Pure JS, no QML: tests/unit/cliphist.test.mjs runs it under node.

// `cliphist list` ("<id>\t<preview>" per line, newest first) →
// [{ id, preview, isImage }], skipping lines without an id or a preview.
function parseList(text) {
    const out = []
    for (const line of String(text).split("\n")) {
        if (line.trim() === "") continue
        const tab = line.indexOf("\t")
        if (tab < 0) continue
        const id = line.substring(0, tab).trim()
        const preview = line.substring(tab + 1).trim()
        if (id === "" || preview === "") continue
        const isImage = preview.indexOf("binary data") >= 0 || preview.startsWith("[[") || preview.indexOf("image/") >= 0
        out.push({ id: id, preview: preview, isImage: isImage })
    }
    return out
}

if (typeof module !== "undefined") module.exports = { parseList }
