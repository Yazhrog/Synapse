// Unit tests for src/core/hypr.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const H = require("../../src/core/hypr.js")

const gaps = { top: 5, right: 10, bottom: 5, left: 10 }

test("lua values", () => {
    assert.equal(H.luaValue("a\"b\\c"), '"a\\"b\\\\c"')
    assert.equal(H.luaValue(gaps), "{ top = 5, right = 10, bottom = 5, left = 10 }")
    assert.equal(H.luaValue({ "col.active_border": { colors: ["rgb(ff0000)"] } }),
                 '{ ["col.active_border"] = { colors = { "rgb(ff0000)" } } }')
    assert.equal(H.luaValue(true), "true")
    assert.throws(() => H.luaValue(NaN))
})

test("setOptions on lua: one hl.config eval", () => {
    assert.deepEqual(H.setOptions("lua", "general", { gaps_in: gaps, layout: "dwindle" }),
        [["hyprctl", "eval", 'hl.config({ general = { gaps_in = { top = 5, right = 10, bottom = 5, left = 10 }, layout = "dwindle" } })']])
})

test("setOptions on conf: one keyword per key", () => {
    assert.deepEqual(H.setOptions("conf", "general", { gaps_in: gaps, layout: "dwindle" }), [
        ["hyprctl", "keyword", "general:gaps_in", "5 10 5 10"],
        ["hyprctl", "keyword", "general:layout", "dwindle"],
    ])
})

test("a section name can't inject Lua", () => {
    assert.throws(() => H.setOptions("lua", "general }) os.execute('x') --", {}))
})

test("data in Lua strings stays a string", () => {
    const [argv] = H.setOptions("lua", "decoration", { screen_shader: '") os.execute("x") --' })
    assert.equal(argv[2], 'hl.config({ decoration = { screen_shader = "\\") os.execute(\\"x\\") --" } })')
})

test("submap per provider", () => {
    assert.deepEqual(H.submap("lua", "Synapse_clean"), ["hyprctl", "dispatch", 'hl.dsp.submap("Synapse_clean")'])
    assert.deepEqual(H.submap("conf", "reset"), ["hyprctl", "dispatch", "submap", "reset"])
})

test("evalLua only on lua", () => {
    assert.deepEqual(H.evalLua("lua", "x()"), ["hyprctl", "eval", "x()"])
    assert.equal(H.evalLua("conf", "x()"), null)
})
