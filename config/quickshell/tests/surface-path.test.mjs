// Unit tests for src/shapes/surfacePath.js. Run: node config/quickshell/tests/surface-path.test.mjs
import { createRequire } from "node:module"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const { build } = require("../src/shapes/surfacePath.js")

const base = {
    width: 1920, height: 1080, t: 6, r: 15, R: 17, notchBottom: 40,
    left: { width: 260 }, center: { width: 320 }, right: { width: 300 },
}

// Parse "M x y L x y A rx ry 0 0 s x y ... Z" into loops of points, and compute
// the winding number at a point by sampling arcs into short lines.
function loops(d) {
    const out = []
    const tok = d.trim().split(/\s+/)
    let i = 0, cur = null, px = 0, py = 0
    while (i < tok.length) {
        const c = tok[i++]
        if (c === "M") { px = +tok[i++]; py = +tok[i++]; cur = [[px, py]]; out.push(cur) }
        else if (c === "L") { px = +tok[i++]; py = +tok[i++]; cur.push([px, py]) }
        else if (c === "A") {
            const r = +tok[i++]; i += 3; const sweep = +tok[i++]; const x = +tok[i++], y = +tok[i++]
            // centre of the small arc from (px,py) to (x,y) with radius r
            const mx = (px + x) / 2, my = (py + y) / 2, dx = x - px, dy = y - py
            const q = Math.hypot(dx, dy) || 1e-9, hgt = Math.sqrt(Math.max(0, r * r - (q / 2) ** 2))
            const s = sweep ? 1 : -1
            const cx = mx - s * hgt * dy / q, cy = my + s * hgt * dx / q
            let a0 = Math.atan2(py - cy, px - cx), a1 = Math.atan2(y - cy, x - cx)
            if (sweep && a1 < a0) a1 += 2 * Math.PI
            if (!sweep && a1 > a0) a1 -= 2 * Math.PI
            for (let k = 1; k <= 8; k++) { const a = a0 + (a1 - a0) * k / 8; cur.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]) }
            px = x; py = y
        } else if (c === "Z") { /* closed */ }
        else throw new Error("unexpected token " + c)
    }
    return out
}
function winding(ls, x, y) {
    let w = 0
    for (const l of ls) for (let k = 0; k < l.length; k++) {
        const [x0, y0] = l[k], [x1, y1] = l[(k + 1) % l.length]
        if (y0 <= y && y1 > y && (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0) > 0) w++
        else if (y0 > y && y1 <= y && (x1 - x0) * (y - y0) - (x - x0) * (y1 - y0) < 0) w--
    }
    return w
}
const filled = (d, x, y) => winding(loops(d), x, y) !== 0

let n = 0
function test(name, fn) { fn(); n++; console.log("ok -", name) }

test("no NaN, starts with M, closes every loop", () => {
    const d = build(base)
    assert.ok(d.startsWith("M "))
    assert.ok(!/NaN|Infinity|undefined/.test(d))
    assert.equal((d.match(/M /g) || []).length, (d.match(/Z/g) || []).length)
})

test("frame filled, hole empty, notches filled", () => {
    const d = build(base)
    assert.ok(filled(d, 3, 500), "left border")
    assert.ok(filled(d, 1917, 500), "right border")
    assert.ok(filled(d, 960, 1077), "bottom border")
    assert.ok(filled(d, 960, 3), "top strip")
    assert.ok(!filled(d, 960, 540), "hole")
    assert.ok(filled(d, 100, 30), "left notch")
    assert.ok(filled(d, 960, 30), "center notch")
    assert.ok(filled(d, 1800, 30), "right notch")
    assert.ok(!filled(d, 500, 30), "gap between notches")
})

test("side regions open and close", () => {
    const open = build({ ...base, leftCenter: { depth: 228, height: 270 }, rightCenter: { depth: 180, height: 306 } })
    assert.ok(filled(open, 150, 540), "left-center bump")
    assert.ok(filled(open, 1820, 540), "right-center bump")
    assert.ok(!filled(build(base), 150, 540))
})

test("bottom panels are filled once over the frame (no cancelled winding)", () => {
    const d = build({ ...base, bottomCenter: { width: 980, height: 420 }, bottomRight: { width: 420, height: 560 } })
    assert.ok(filled(d, 960, 900), "bottom-center panel")
    assert.ok(filled(d, 960, 1077), "bottom border under the panel")
    assert.ok(filled(d, 1800, 900), "bottom-right panel")
    assert.ok(filled(d, 1917, 900), "right border under the panel")
    assert.ok(filled(d, 1800, 1077), "bottom border under the panel")
    assert.ok(!filled(d, 300, 900), "hole beside the panels")
})

test("always exactly two loops (no overlapping subpaths)", () => {
    for (const g of [base,
                     { ...base, bottomCenter: { width: 980, height: 420 } },
                     { ...base, bottomRight: { width: 420, height: 560 } },
                     { ...base, bottomRight: { width: 0.5, height: 0.5 } }])
        assert.equal((build(g).match(/M /g) || []).length, 2)
})

test("closed bottom-right panel keeps the round corner", () => {
    const closed = build(base)
    assert.equal(build({ ...base, bottomRight: { width: 10, height: 10 } }), closed)
    assert.ok(filled(closed, 1911, 1071), "the rounded corner is filled")
    assert.ok(!filled(closed, 1890, 1050), "the hole next to it is not")
})

test("grown notches (dashboard, network)", () => {
    const d = build({ ...base, center: { width: 900, bottom: 520 }, right: { width: 495, bottom: 633 } })
    assert.ok(filled(d, 960, 500), "dashboard")
    assert.ok(filled(d, 1700, 600), "network")
    assert.ok(!filled(d, 960, 560), "below dashboard")
})

test("focus mode (notchBottom = t) stays valid", () => {
    const d = build({ ...base, notchBottom: 6 })
    assert.ok(!/NaN/.test(d))
    assert.ok(!filled(d, 960, 30), "notches collapsed")
    assert.ok(filled(d, 960, 3), "top strip")
})

test("border width and corner radius extremes (Config → Appearance)", () => {
    for (const t of [0, 16]) for (const R of [0, 30]) {
        // The notch radius follows the corner radius (Metrics.notchRadius).
        const g = { ...base, t, R, r: Math.round(R * 15 / 17), bottomCenter: { width: 980, height: 420 } }
        const d = build(g)
        assert.ok(!/NaN|Infinity|undefined/.test(d), `t=${t} R=${R}`)
        assert.ok(filled(d, 960, 20), `center notch t=${t} R=${R}`)
        assert.ok(filled(d, 960, 1000), `bottom panel t=${t} R=${R}`)
        assert.ok(!filled(d, 400, 500), `hole t=${t} R=${R}`)
        if (t > 0) assert.ok(filled(d, t / 2, 500), `left border t=${t} R=${R}`)
        const clip = build({ ...g, bottomRight: { width: 420, height: 560 } })
        assert.ok(filled(clip, 1700, 800), `clipboard panel t=${t} R=${R}`)
        assert.equal((clip.match(/M /g) || []).length, 2, `two loops with the clipboard t=${t} R=${R}`)
    }
})

test("bar style: full-width bar, square ends, popups grow from its bottom", () => {
    const bar = { ...base, style: "bar", t: 0 }
    const d = build(bar)
    assert.ok(!/NaN|Infinity|undefined/.test(d))
    assert.equal((d.match(/M /g) || []).length, 2)
    assert.ok(filled(d, 1, 20) && filled(d, 1919, 20), "bar reaches both screen edges")
    assert.ok(filled(d, 600, 38), "bar between the notches")
    assert.ok(filled(d, 0.5, 39.5) && filled(d, 1919.5, 39.5), "square ends")
    assert.ok(!filled(d, 960, 45), "nothing below the closed bar")
    assert.ok(!filled(d, 2, 1078) && !filled(d, 1918, 1078), "no borders, square screen corners")
    const open = build({ ...bar, center: { width: 900, bottom: 520 }, right: { width: 495, bottom: 633 } })
    assert.ok(filled(open, 960, 500), "dashboard below the bar")
    assert.ok(filled(open, 1700, 600) && filled(open, 1919, 600), "network down the right edge")
    assert.ok(!filled(open, 960, 540), "below the dashboard")
    assert.ok(!filled(open, 300, 300), "hole")
})

test("pills style: three floating capsules, cards for the other regions", () => {
    const pills = { ...base, style: "pills", t: 6 }
    const d = build(pills)
    assert.ok(!/NaN|Infinity|undefined/.test(d))
    assert.equal((d.match(/M /g) || []).length, 3)
    assert.ok(filled(d, 130, 23) && filled(d, 960, 23) && filled(d, 1770, 23), "the three pills")
    assert.ok(!filled(d, 130, 3), "gap above the pills")
    assert.ok(!filled(d, 2, 23) && !filled(d, 1918, 23), "gap at the screen edges")
    assert.ok(!filled(d, 600, 23), "gap between the pills")
    assert.ok(!filled(d, 7, 7), "round ends")
    assert.ok(!filled(d, 3, 500) && !filled(d, 960, 1078), "no borders")
    const open = build({ ...pills, center: { width: 900, bottom: 520 },
                         leftCenter: { depth: 228, height: 270 }, bottomCenter: { width: 980, height: 420 } })
    assert.ok(filled(open, 960, 500), "dashboard panel grown from the center pill")
    assert.ok(filled(open, 100, 540) && !filled(open, 2, 540), "power menu card off the edge")
    assert.ok(filled(open, 960, 1000) && !filled(open, 960, 1078), "wallpaper card above the gap")
    assert.equal((open.match(/M /g) || []).length, 5)
    assert.equal(build({ ...pills, notchBottom: 6 }), "", "focus mode: nothing to draw")
})

test("degenerate sizes return empty or valid path", () => {
    assert.equal(build({ ...base, width: 0 }), "")
    assert.ok(!/NaN/.test(build({ width: 800, height: 600 })))
})

console.log(`\n${n} tests passed`)
