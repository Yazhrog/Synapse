// surfacePath.js — builds the Dynamic Surface frame (#37) as one SVG path.
//
// Pure JS, no QML: SurfaceShape feeds the result to PathSvg, and
// tests/surface-path.test.mjs runs it under node.
//
// The path is filled with the non-zero winding rule and made of:
//   1. the screen rectangle, clockwise (winding +1 → frame);
//   2. the inner edge of the frame, counter-clockwise (winding back to 0 → the
//      transparent hole), with the 3 top notches and the left/right-center
//      bumps on it;
//   3. the bottom panels (bottom-center, bottom-right), clockwise, as separate
//      loops: where they overlap the frame the winding is 2, still filled once,
//      so a translucent fill never shows double alpha.
//
// Closed regions keep a tiny size and every radius is clamped to the room it
// has, so the path never degenerates while a region animates open or closed.
//
// geo = {
//   width, height,
//   t,              border thickness
//   r,              notch corner / flare radius
//   R,              frame inner corner / border flare radius
//   notchBottom,    y of the bar's bottom edge
//   left:   { width, bottom },  center: { width, bottom },  right: { width, bottom },
//   leftCenter:   { depth, height },  rightCenter: { depth, height },
//   bottomCenter: { width, height },  bottomRight: { width, height },
// }

const EPS = 0.001

function _num(v, d) { return (typeof v === "number" && isFinite(v)) ? v : d }

function _fmt(v) { return Math.round(v * 1000) / 1000 }

// A loop: start point + segments. Line: { x, y }. Arc: { x, y, r, cw }, where
// cw is clockwise as seen on screen (y down) = SVG sweep flag 1.
function _loop(x, y) { return { x, y, segs: [] } }
function _line(loop, x, y) { loop.segs.push({ x, y }) }
function _arc(loop, x, y, r, cw) { loop.segs.push({ x, y, r, cw }) }

// Same loop traversed the other way: every segment ends where the previous
// one started, and arcs flip their sweep.
function _reverse(loop) {
    const pts = [{ x: loop.x, y: loop.y }].concat(loop.segs.map(s => ({ x: s.x, y: s.y })))
    const out = _loop(pts[pts.length - 1].x, pts[pts.length - 1].y)
    for (let i = loop.segs.length - 1; i >= 0; i--) {
        const s = loop.segs[i], p = pts[i]
        if (s.r === undefined) _line(out, p.x, p.y)
        else                   _arc(out, p.x, p.y, s.r, !s.cw)
    }
    return out
}

function _svg(loop) {
    let d = "M " + _fmt(loop.x) + " " + _fmt(loop.y)
    for (const s of loop.segs) {
        if (s.r === undefined) d += " L " + _fmt(s.x) + " " + _fmt(s.y)
        else d += " A " + _fmt(s.r) + " " + _fmt(s.r) + " 0 0 " + (s.cw ? 1 : 0) + " " + _fmt(s.x) + " " + _fmt(s.y)
    }
    return d + " Z"
}

function build(geo) {
    const W = _num(geo.width, 0), H = _num(geo.height, 0)
    if (W <= 0 || H <= 0) return ""
    const t  = _num(geo.t, 0)
    const h  = Math.max(t + EPS, _num(geo.notchBottom, t))
    const r  = Math.max(EPS, Math.min(_num(geo.r, 0), (h - t) / 2))
    const Rm = _num(geo.R, 0)

    const top = name => geo[name] || {}
    const lW = _num(top("left").width, 0),   lh = Math.max(h, _num(top("left").bottom, h))
    const cW = _num(top("center").width, 0), ch = Math.max(h, _num(top("center").bottom, h))
    const rW = _num(top("right").width, 0),  rh = Math.max(h, _num(top("right").bottom, h))

    // Border flares under the left/right notches, and the frame's inner corners.
    const Rl = Math.max(EPS, Math.min(Rm, (H - lh - t) / 2))
    const Rr = Math.max(EPS, Math.min(Rm, (H - rh - t) / 2))
    const Rc = Math.max(EPS, Math.min(Rm, (H - h - t) / 2))

    const side = region => {
        const g = geo[region] || {}
        const D  = Math.max(EPS, _num(g.depth, 0))
        const Hb = Math.max(2 * EPS, _num(g.height, 0))
        return {
            D, Hb,
            F: Math.max(EPS / 2, Math.min(Rm, D / 2)),           // flares into the border
            C: Math.max(EPS / 2, Math.min(Rm, D / 2, Hb / 2)),   // convex corners
            top: H / 2 - Hb / 2,
            bot: H / 2 + Hb / 2,
        }
    }
    const lc = side("leftCenter"), rc = side("rightCenter")

    const cS = W / 2 - cW / 2, cE = W / 2 + cW / 2, rS = W - rW

    // 1. Screen rectangle, clockwise.
    const outer = _loop(0, 0)
    _line(outer, W, 0); _line(outer, W, H); _line(outer, 0, H); _line(outer, 0, 0)

    // 2. Inner edge, built clockwise from the bottom of the left border, then
    //    reversed. Bulges into the hole turn clockwise, into the frame
    //    counter-clockwise.
    const inner = _loop(t, H - t - Rc)

    // Left border with the left-center bump.
    _line(inner, t, lc.bot + lc.F)
    _arc(inner, t + lc.F, lc.bot, lc.F, true)
    _line(inner, t + lc.D - lc.C, lc.bot)
    _arc(inner, t + lc.D, lc.bot - lc.C, lc.C, false)
    _line(inner, t + lc.D, lc.top + lc.C)
    _arc(inner, t + lc.D - lc.C, lc.top, lc.C, false)
    _line(inner, t + lc.F, lc.top)
    _arc(inner, t, lc.top - lc.F, lc.F, true)

    // Up to the flare under the left notch, then the left notch.
    _line(inner, t, lh + Rl)
    _arc(inner, t + Rl, lh, Rl, true)
    _line(inner, lW - r, lh)
    _arc(inner, lW, lh - r, r, false)
    _line(inner, lW, t + r)
    _arc(inner, lW + r, t, r, true)

    // Top strip → center notch.
    _line(inner, cS - r, t)
    _arc(inner, cS, t + r, r, true)
    _line(inner, cS, ch - r)
    _arc(inner, cS + r, ch, r, false)
    _line(inner, cE - r, ch)
    _arc(inner, cE, ch - r, r, false)
    _line(inner, cE, t + r)
    _arc(inner, cE + r, t, r, true)

    // Top strip → right notch → flare into the right border.
    _line(inner, rS - r, t)
    _arc(inner, rS, t + r, r, true)
    _line(inner, rS, rh - r)
    _arc(inner, rS + r, rh, r, false)
    _line(inner, W - t - Rr, rh)
    _arc(inner, W - t, rh + Rr, Rr, true)

    // Right border with the right-center bump.
    const rcX = W - t - rc.D
    _line(inner, W - t, rc.top - rc.F)
    _arc(inner, W - t - rc.F, rc.top, rc.F, true)
    _line(inner, rcX + rc.C, rc.top)
    _arc(inner, rcX, rc.top + rc.C, rc.C, false)
    _line(inner, rcX, rc.bot - rc.C)
    _arc(inner, rcX + rc.C, rc.bot, rc.C, false)
    _line(inner, W - t - rc.F, rc.bot)
    _arc(inner, W - t, rc.bot + rc.F, rc.F, true)

    // Bottom-right corner, bottom border, bottom-left corner.
    _line(inner, W - t, H - t - Rc)
    _arc(inner, W - t - Rc, H - t, Rc, true)
    _line(inner, t + Rc, H - t)
    _arc(inner, t, H - t - Rc, Rc, true)

    const loops = [outer, _reverse(inner)]

    // 3. Bottom panels, clockwise. Skipped while closed.
    const bc = geo.bottomCenter || {}
    const bcW = _num(bc.width, 0), bcH = _num(bc.height, 0)
    if (bcW >= 1 && bcH >= 1) {
        const L = W / 2 - bcW / 2, Rx = W / 2 + bcW / 2, T = H - t - bcH
        const F = Math.max(EPS / 2, Math.min(_num(geo.r, 0), bcH / 2))
        const C = Math.max(EPS / 2, Math.min(Rm, bcW / 2, bcH / 2))
        const p = _loop(L - F, H - t)
        _arc(p, L, H - t - F, F, false)
        _line(p, L, T + C)
        _arc(p, L + C, T, C, true)
        _line(p, Rx - C, T)
        _arc(p, Rx, T + C, C, true)
        _line(p, Rx, H - t - F)
        _arc(p, Rx + F, H - t, F, false)
        _line(p, Rx + F, H)
        _line(p, L - F, H)
        _line(p, L - F, H - t)
        loops.push(p)
    }

    const br = geo.bottomRight || {}
    const brW = _num(br.width, 0), brH = _num(br.height, 0)
    if (brW >= 1 && brH >= 1) {
        const L = W - t - brW, T = H - t - brH
        const F = Math.max(EPS / 2, Math.min(Rm, brW / 2, brH / 2))
        const C = F
        const p = _loop(W - t, T - F)
        _arc(p, W - t - F, T, F, true)
        _line(p, L + C, T)
        _arc(p, L, T + C, C, false)
        _line(p, L, H - t - F)
        _arc(p, L - F, H - t, F, true)
        _line(p, L - F, H)
        _line(p, W, H)
        _line(p, W, T - F)
        _line(p, W - t, T - F)
        loops.push(_reverse(p))   // traced counter-clockwise above; must wind like the frame
    }

    return loops.map(_svg).join(" ")
}

// Exported for node (tests); in QML the file is imported as a JS module.
if (typeof module !== "undefined") module.exports = { build }
