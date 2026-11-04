// surfacePath.js — builds the Dynamic Surface frame (#37) as one SVG path.
//
// Pure JS, no QML: SurfaceShape feeds the result to PathSvg, and
// tests/surface-path.test.mjs runs it under node.
//
// The path is exactly two loops, filled with the non-zero winding rule:
//   1. the screen rectangle, clockwise (winding +1 → frame);
//   2. the inner edge of the frame, counter-clockwise (winding back to 0 → the
//      transparent hole), with every region on it: the 3 top notches, the
//      left/right-center bumps, the bottom-center bump and the bottom-right
//      panel. No subpath overlaps another, so every pixel is filled once (no
//      double alpha with a translucent frame) and triangulating renderers
//      (Shape.CurveRenderer) don't have to resolve overlaps.
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
//   style,          "frame" (default), "bar" or "pills" (Config → Appearance)
// }
//
// Styles:
//   frame  the 3 notches hang from a thin top strip, joined to side and
//          bottom borders of thickness t; regions melt into the frame.
//   bar    one full-width bar of height notchBottom along the top edge with
//          square ends; the top regions grow down out of its bottom edge
//          (flares of radius r). Side and bottom regions grow out of the
//          borders as in frame (t is 0 when the shell hides them).
//   pills  every part is its own floating rounded shape, t away from the
//          screen edges: 3 capsules (left, center, right) that grow into
//          rounded panels for the top regions, and rounded cards for the
//          side and bottom regions. No flares, no borders.

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
    if (geo.style === "pills") return _buildPills(geo, W, H)
    const bar = geo.style === "bar"
    const t  = _num(geo.t, 0)
    const h  = Math.max(t + EPS, _num(geo.notchBottom, t))
    const r  = Math.max(EPS, Math.min(_num(geo.r, 0), (h - t) / 2))
    const Rm = _num(geo.R, 0)
    // Bar without borders: square corners where the bar and the bottom meet
    // the screen edges.
    const square = bar && t <= 0

    const top = name => geo[name] || {}
    const lW = _num(top("left").width, 0),   lh = Math.max(h, _num(top("left").bottom, h))
    const cW = _num(top("center").width, 0), ch = Math.max(h, _num(top("center").bottom, h))
    const rW = _num(top("right").width, 0),  rh = Math.max(h, _num(top("right").bottom, h))

    // Border flares under the left/right notches, and the frame's inner corners.
    const Rl = square ? EPS : Math.max(EPS, Math.min(Rm, (H - (bar ? h : lh) - t) / 2))
    const Rr = square ? EPS : Math.max(EPS, Math.min(Rm, (H - rh - t) / 2))
    const Rc = square ? EPS : Math.max(EPS, Math.min(Rm, (H - h - t) / 2))

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

    if (bar) {
        _barTop(inner, { t, h, W, r: _num(geo.r, 0), cS, cE, ch, rS, rh, Rl, Rr })
    } else {
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
    }

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

    // Bottom-right corner, or the bottom-right panel (clipboard) growing out of
    // it. Below 2 corner radii (and 1 px) in either direction the panel isn't
    // drawn and the corner stays round, so its flares and corner never
    // collapse to a sharp point. With R = 0 the panel is a plain rectangle.
    const br = geo.bottomRight || {}
    const brW = _num(br.width, 0), brH = _num(br.height, 0)
    const brMin = Math.max(2 * Rm, 1)
    if (brW >= brMin && brH >= brMin) {
        const L = W - t - brW, T = H - t - brH
        const F = Math.max(EPS / 2, Math.min(Rm, brW / 2, brH / 2))
        const C = F
        _line(inner, W - t, T - F)
        _arc(inner, W - t - F, T, F, true)
        _line(inner, L + C, T)
        _arc(inner, L, T + C, C, false)
        _line(inner, L, H - t - F)
        _arc(inner, L - F, H - t, F, true)
    } else {
        _line(inner, W - t, H - t - Rc)
        _arc(inner, W - t - Rc, H - t, Rc, true)
    }

    // Bottom border with the bottom-center bump (wallpaper), then the
    // bottom-left corner.
    const bc = geo.bottomCenter || {}
    const bcD  = Math.max(EPS, _num(bc.height, 0))
    const bcW  = Math.max(2 * EPS, _num(bc.width, 0))
    const bcF  = Math.max(EPS / 2, Math.min(_num(geo.r, 0), bcD / 2))
    const bcC  = Math.max(EPS / 2, Math.min(Rm, bcD / 2, bcW / 2))
    const bcL  = W / 2 - bcW / 2, bcR = W / 2 + bcW / 2, bcT = H - t - bcD
    _line(inner, bcR + bcF, H - t)
    _arc(inner, bcR, H - t - bcF, bcF, true)
    _line(inner, bcR, bcT + bcC)
    _arc(inner, bcR - bcC, bcT, bcC, false)
    _line(inner, bcL + bcC, bcT)
    _arc(inner, bcL, bcT + bcC, bcC, false)
    _line(inner, bcL, H - t - bcF)
    _arc(inner, bcL - bcF, H - t, bcF, true)

    _line(inner, t + Rc, H - t)
    _arc(inner, t, H - t - Rc, Rc, true)

    // Exactly two loops, neither overlapping the other nor itself: renderers
    // that triangulate (Shape.CurveRenderer) handle that reliably.
    const loops = [outer, _reverse(inner)]

    return loops.map(_svg).join(" ")
}

// Bar style: the inner edge from the left border along the bar's bottom edge
// (y = h), with the top regions as bumps growing down from it, to the right
// border. Bump radii shrink with the bump, so a closed region is flat.
function _barTop(inner, g) {
    const { t, h, W, r, cS, cE, ch, rS, rh, Rl, Rr } = g
    _line(inner, t, h + Rl)
    _arc(inner, t + Rl, h, Rl, true)

    const fc = Math.max(EPS / 2, Math.min(r, (ch - h) / 2, (cE - cS) / 4))
    _line(inner, cS - fc, h)
    _arc(inner, cS, h + fc, fc, true)
    _line(inner, cS, ch - fc)
    _arc(inner, cS + fc, ch, fc, false)
    _line(inner, cE - fc, ch)
    _arc(inner, cE, ch - fc, fc, false)
    _line(inner, cE, h + fc)
    _arc(inner, cE + fc, h, fc, true)

    const fr = Math.max(EPS / 2, Math.min(r, (rh - h) / 2))
    _line(inner, rS - fr, h)
    _arc(inner, rS, h + fr, fr, true)
    _line(inner, rS, rh - fr)
    _arc(inner, rS + fr, rh, fr, false)
    _line(inner, W - t - Rr, rh)
    _arc(inner, W - t, rh + Rr, Rr, true)
}

// A rounded rectangle, clockwise (winding +1), with top corners rt and
// bottom corners rb, each clamped to the room it has.
function _roundRect(x0, y0, x1, y1, rt, rb) {
    const w = x1 - x0, hh = y1 - y0
    rt = Math.max(EPS / 2, Math.min(rt, w / 2, hh / 2))
    rb = Math.max(EPS / 2, Math.min(rb, w / 2, hh / 2))
    const l = _loop(x0 + rt, y0)
    _line(l, x1 - rt, y0)
    _arc(l, x1, y0 + rt, rt, true)
    _line(l, x1, y1 - rb)
    _arc(l, x1 - rb, y1, rb, true)
    _line(l, x0 + rb, y1)
    _arc(l, x0, y1 - rb, rb, true)
    _line(l, x0, y0 + rt)
    _arc(l, x0 + rt, y0, rt, true)
    return l
}

// Pills style: one loop per visible shape, t (the gap) away from the screen
// edges. Top capsules run from y = t to notchBottom with fully round ends;
// growing down (a popup) turns one into a panel whose bottom corners ease
// from round to R. Side and bottom cards appear once they have some size.
function _buildPills(geo, W, H) {
    const g  = Math.max(0, _num(geo.t, 0))
    const h  = _num(geo.notchBottom, g)
    const Rm = Math.max(0, _num(geo.R, 0))
    const r  = Math.max(0, _num(geo.r, 0))
    const ph = h - g                     // capsule height
    const pr = ph / 2
    const loops = []
    const MIN = 1                        // below this a shape isn't drawn

    const top = name => geo[name] || {}
    // In focus mode the capsules are 0 tall (h = g) and only a popup grown
    // out of one is drawn; its top corners then ease in to R as well.
    const pill = (x0, x1, bottom) => {
        const y1 = Math.max(h, _num(bottom, h))
        if (y1 - g < MIN || x1 - x0 < MIN) return
        const grow = Math.max(0, Math.min(1, (y1 - h) / Math.max(ph, 2 * pr, Rm, MIN)))
        loops.push(_roundRect(x0, g, x1, y1, Math.max(pr, Rm * grow), pr + (Rm - pr) * grow))
    }
    const lW = _num(top("left").width, 0)
    const cW = _num(top("center").width, 0)
    const rW = _num(top("right").width, 0)
    pill(g, lW, top("left").bottom)
    pill(W / 2 - cW / 2, W / 2 + cW / 2, top("center").bottom)
    pill(W - rW, W - g, top("right").bottom)

    const card = (x0, y0, x1, y1) => {
        if (x1 - x0 < MIN || y1 - y0 < MIN) return
        loops.push(_roundRect(x0, y0, x1, y1, Rm, Rm))
    }
    const lc = geo.leftCenter || {}, rc = geo.rightCenter || {}
    const lD = _num(lc.depth, 0), lH = _num(lc.height, 0)
    const rD = _num(rc.depth, 0), rH = _num(rc.height, 0)
    card(g, H / 2 - lH / 2, g + lD, H / 2 + lH / 2)
    card(W - g - rD, H / 2 - rH / 2, W - g, H / 2 + rH / 2)

    // The bottom-center region is r wider on each side (frame's flares), and
    // its content uses that room.
    const bc = geo.bottomCenter || {}
    const bcW = _num(bc.width, 0), bcD = _num(bc.height, 0)
    if (bcW >= MIN) card(W / 2 - bcW / 2 - r, H - g - bcD, W / 2 + bcW / 2 + r, H - g)

    const br = geo.bottomRight || {}
    card(W - g - _num(br.width, 0), H - g - _num(br.height, 0), W - g, H - g)

    return loops.map(_svg).join(" ")
}

// Exported for node (tests); in QML the file is imported as a JS module.
if (typeof module !== "undefined") module.exports = { build }
