// hypr.js — builds hyprctl argument lists for both Hyprland config providers.
//
// Pure JS, no QML: core/Hypr.qml runs the result, and
// tests/unit/hypr.test.mjs runs it under node.
//
// "lua" (Hyprland 0.55+ Lua config) has no `hyprctl keyword` ("unknown
// request"): options are set with `hyprctl eval "hl.config({...})"`.
// "conf" (legacy hyprland.conf) uses `hyprctl keyword section:key value`.

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/

// A JS value as a Lua literal: strings quoted, arrays as sequences,
// objects as tables ({ top = 1 }, or ["col.active_border"] = … for keys that
// aren't identifiers).
function luaValue(v) {
    if (typeof v === "string")
        return '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"'
    if (typeof v === "number") {
        if (!isFinite(v)) throw new Error("hypr: not a finite number: " + v)
        return String(v)
    }
    if (typeof v === "boolean") return v ? "true" : "false"
    if (Array.isArray(v)) return "{ " + v.map(luaValue).join(", ") + " }"
    if (v !== null && typeof v === "object") {
        const parts = Object.keys(v).map(k =>
            (IDENT.test(k) ? k : "[" + luaValue(k) + "]") + " = " + luaValue(v[k]))
        return "{ " + parts.join(", ") + " }"
    }
    throw new Error("hypr: no Lua form for " + v)
}

// A JS value as a `hyprctl keyword` value: arrays and objects become their
// values joined by spaces (gaps { top, right, bottom, left } → "5 5 5 5").
function confValue(v) {
    if (Array.isArray(v)) return v.map(confValue).join(" ")
    if (v !== null && typeof v === "object") return Object.keys(v).map(k => confValue(v[k])).join(" ")
    if (typeof v === "boolean") return v ? "true" : "false"
    return String(v)
}

// Commands setting options of one section, e.g.
// setOptions("lua", "general", { gaps_in: {top: 5, …} }). Returns a list of
// argument lists, run in order (one per key on conf).
function setOptions(provider, section, values) {
    if (!IDENT.test(section)) throw new Error("hypr: bad section " + section)
    if (provider === "conf")
        return Object.keys(values).map(k => ["hyprctl", "keyword", section + ":" + k, confValue(values[k])])
    return [["hyprctl", "eval", "hl.config({ " + section + " = " + luaValue(values) + " })"]]
}

// Enter or leave a submap ("reset" leaves).
function submap(provider, name) {
    if (provider === "conf") return ["hyprctl", "dispatch", "submap", name]
    return ["hyprctl", "dispatch", "hl.dsp.submap(" + luaValue(name) + ")"]
}

// Arbitrary Lua (only on the Lua provider; null on conf).
function evalLua(provider, lua) {
    return provider === "conf" ? null : ["hyprctl", "eval", lua]
}

function reload() { return ["hyprctl", "reload"] }

if (typeof module !== "undefined") module.exports = { luaValue, confValue, setOptions, submap, evalLua, reload }
