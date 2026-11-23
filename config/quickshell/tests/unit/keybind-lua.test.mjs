// Unit tests for src/services/desktop/keybindLua.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const K = require("../../src/services/desktop/keybindLua.js")

const defaults = {
    dashboard: { mods: "SUPER", key: "D", label: "Dashboard", group: "Popups" },
    clipboard: { mods: "SUPER", key: "V", label: "Clipboard", group: "Popups" },
    record:    { mods: "", key: "", label: "Record", group: "Tools" },
}

test("merge: overrides change mods/key of known actions only", () => {
    const kb = K.merge(defaults, { dashboard: { mods: "SUPER + SHIFT", key: "X" }, ghost: { mods: "ALT", key: "G" },
                                   clipboard: { key: "B" } })
    assert.deepEqual(kb.dashboard, { mods: "SUPER + SHIFT", key: "X", label: "Dashboard", group: "Popups" })
    assert.deepEqual(kb.clipboard, { mods: "SUPER", key: "B", label: "Clipboard", group: "Popups" })
    assert.equal(kb.ghost, undefined)
    assert.deepEqual(K.merge(defaults, {}), defaults)
})

test("overridesOf keeps only what differs from the defaults", () => {
    const kb = K.merge(defaults, { clipboard: { mods: "", key: "" } })
    assert.deepEqual(K.overridesOf(kb, defaults), { clipboard: { mods: "", key: "" } })
    assert.deepEqual(K.merge(defaults, K.overridesOf(kb, defaults)), kb)
})

test("modsToMask", () => {
    assert.equal(K.modsToMask("SUPER + SHIFT"), 65)
    assert.equal(K.modsToMask("ctrl+alt"), 12)
    assert.equal(K.modsToMask(""), 0)
})

test("hyprConflict ignores submaps, mouse and our own binds", () => {
    const binds = [
        { submap: "", mouse: false, modmask: 64, key: "q", dispatcher: "killactive", arg: "" },
        { submap: "resize", mouse: false, modmask: 64, key: "r", dispatcher: "x", arg: "" },
        { submap: "", mouse: true, modmask: 64, key: "mouse:272", dispatcher: "movewindow", arg: "" },
        { submap: "", mouse: false, modmask: 64, key: "D", dispatcher: "exec", arg: "qs ipc call dashboard toggle" },
        { submap: "", mouse: false, modmask: 65, key: "E", dispatcher: "exec", arg: "x".repeat(50) },
    ]
    assert.equal(K.hyprConflict(binds, "SUPER", "Q"), "killactive")
    assert.equal(K.hyprConflict(binds, "SUPER", "R"), "")
    assert.equal(K.hyprConflict(binds, "SUPER", "D"), "")
    assert.equal(K.hyprConflict(binds, "SUPER + SHIFT", "e"), "exec: " + "x".repeat(36))
})

test("duplicates and shell conflicts", () => {
    const kb = K.merge(defaults, { clipboard: { key: "D" } })
    assert.deepEqual(K.comboMap(kb), { "SUPER+D": ["dashboard", "clipboard"] })
    assert.equal(K.shellConflict(kb, "record", "SUPER", "D"), "Dashboard")
    assert.equal(K.shellConflict(kb, "dashboard", "SUPER", "V"), "")
})

test("genLua: capture submap, then one bind per bound action by group", () => {
    const lua = K.genLua(defaults)
    assert.match(lua, /^-- =+\n-- Synapse Keybinds\n/)
    assert.ok(lua.includes('hl.define_submap("Synapse_clean", function()'))
    assert.ok(lua.endsWith('-- Popups\nhl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc call dashboard toggle"))\n'
                         + 'hl.bind("SUPER + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))\n'))
    assert.ok(!lua.includes("call record"), "an unbound action gets no bind")
})

test("genConf: modifiers without '+'", () => {
    const conf = K.genConf(K.merge(defaults, { dashboard: { mods: "SUPER + SHIFT" } }))
    assert.ok(conf.includes("submap = Synapse_clean\nbind = CTRL, ESCAPE, exec,"))
    assert.ok(conf.includes("# Popups\nbind = SUPER SHIFT, D, exec, qs ipc call dashboard toggle\n"))
})
