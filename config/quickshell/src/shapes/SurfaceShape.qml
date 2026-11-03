import QtQuick
import QtQuick.Shapes
import "../"

// SurfaceShape — the whole frame (top strip with its 3 notches, side and
// bottom borders) drawn as ONE path, filled with the odd-even rule:
//
//   outer loop = the screen rectangle
//   inner loop = the inside edge of the frame (the transparent hole)
//
// Notches are bumps on the inner loop's top edge. Every size is a plain
// property, so animating a property morphs the shape (#37). Replaces
// SeamlessBarShape + Border's canvases once the surface is the default.
//
// Corner direction notes (y points down): "Clockwise" is clockwise as seen on
// screen. Hole corners that bulge into the hole (border flares, frame corners)
// turn clockwise; notch bottom corners, which bulge into the frame, turn
// counterclockwise.
Shape {
    id: root

    // ── Geometry ─────────────────────────────────────────────────────────────
    property real borderWidth:  Theme.borderWidth   // t: frame thickness
    property real notchBottom:  Theme.notchHeight   // h: y of the notches' bottom edge
    property real notchRadius:  Theme.notchRadius   // r: notch corners and flares
    property real cornerRadius: Theme.cornerRadius  // R: frame inner corners and border flares

    property real leftWidth:    Theme.lNotchMinWidth
    property real centerWidth:  Theme.cNotchMinWidth
    property real rightWidth:   Theme.rNotchMinWidth

    // Each top notch can grow down past the bar (e.g. the right notch for a
    // notification toast). Default: all at notchBottom.
    property real leftBottom:   notchBottom
    property real centerBottom: notchBottom
    property real rightBottom:  notchBottom

    // Side regions: bumps growing inward from the middle of the left border
    // (power menu) and right border (OSD, audio). depth 0 = closed.
    property real leftCenterDepth:   0
    property real leftCenterHeight:  0
    property real rightCenterDepth:  0
    property real rightCenterHeight: 0

    // Bottom regions: a panel growing up from the middle of the bottom border
    // (wallpaper) and one growing out of the bottom-right inner corner
    // (clipboard). Size 0 = closed. They're drawn as extra filled paths in
    // the frame colour on top of the frame, so a closed region leaves the
    // plain border and rounded corner untouched.
    property real bottomCenterWidth:  0
    property real bottomCenterHeight: 0
    property real bottomRightWidth:   0
    property real bottomRightHeight:  0

    property color color: Theme.background

    // ── Derived values ───────────────────────────────────────────────────────
    // Closed regions keep a tiny depth instead of 0 and every radius is
    // clamped to the room available, so the path never degenerates while
    // animating (e.g. into focus mode, where notchBottom → borderWidth).
    readonly property real _t:     borderWidth
    readonly property real _h:     Math.max(_t + 0.001, notchBottom)
    readonly property real _r:     Math.max(0.001, Math.min(notchRadius, (_h - _t) / 2))
    readonly property real _lh:    Math.max(_h, leftBottom)
    readonly property real _ch:    Math.max(_h, centerBottom)
    readonly property real _rh:    Math.max(_h, rightBottom)
    readonly property real _Rl:    Math.max(0.001, Math.min(cornerRadius, (height - _lh - _t) / 2))
    readonly property real _Rr:    Math.max(0.001, Math.min(cornerRadius, (height - _rh - _t) / 2))
    readonly property real _R:     Math.max(0.001, Math.min(cornerRadius, (height - _h - _t) / 2))

    // Right-center bump: closed regions keep a tiny depth, radii shrink with it.
    readonly property real _rcD:   Math.max(0.001, rightCenterDepth)
    readonly property real _rcH:   Math.max(0.002, rightCenterHeight)
    readonly property real _rcF:   Math.max(0.0005, Math.min(cornerRadius, _rcD / 2))   // flares into the border
    readonly property real _rcC:   Math.max(0.0005, Math.min(cornerRadius, _rcD / 2, _rcH / 2))   // convex corners
    readonly property real _rcTop: height / 2 - _rcH / 2
    readonly property real _rcBot: height / 2 + _rcH / 2
    readonly property real _rcX:   width - _t - _rcD

    readonly property real _lcD:   Math.max(0.001, leftCenterDepth)
    readonly property real _lcH:   Math.max(0.002, leftCenterHeight)
    readonly property real _lcF:   Math.max(0.0005, Math.min(cornerRadius, _lcD / 2))
    readonly property real _lcC:   Math.max(0.0005, Math.min(cornerRadius, _lcD / 2, _lcH / 2))
    readonly property real _lcTop: height / 2 - _lcH / 2
    readonly property real _lcBot: height / 2 + _lcH / 2
    readonly property real _lcX:   _t + _lcD

    readonly property real _bcL:   width / 2 - bottomCenterWidth / 2
    readonly property real _bcR:   width / 2 + bottomCenterWidth / 2
    readonly property real _bcTop: height - _t - bottomCenterHeight
    readonly property real _bcF:   Math.max(0.0005, Math.min(notchRadius, bottomCenterHeight / 2))
    readonly property real _bcC:   Math.max(0.0005, Math.min(cornerRadius, bottomCenterWidth / 2, bottomCenterHeight / 2))

    readonly property real _brL:   width - _t - bottomRightWidth
    readonly property real _brTop: height - _t - bottomRightHeight
    readonly property real _brF:   Math.max(0.0005, Math.min(cornerRadius, bottomRightWidth / 2, bottomRightHeight / 2))
    readonly property real _brC:   Math.max(0.0005, Math.min(cornerRadius, bottomRightWidth / 2, bottomRightHeight / 2))
    readonly property real _cS:    width / 2 - centerWidth / 2
    readonly property real _cE:    width / 2 + centerWidth / 2
    readonly property real _rS:    width - rightWidth

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor:   root.color
        strokeWidth: -1
        fillRule:    ShapePath.OddEvenFill

        // ── Outer loop: the screen ───────────────────────────────────────────
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.height }
        PathLine { x: 0;          y: root.height }
        PathLine { x: 0;          y: 0 }

        // ── Inner loop: the hole, clockwise from the left border ─────────────
        PathMove { x: root._t; y: root.height - root._t - root._R }

        // Left border, with the left-center bump halfway up
        PathLine { x: root._t; y: root._lcBot + root._lcF }
        PathArc  { x: root._t + root._lcF; y: root._lcBot
                   radiusX: root._lcF; radiusY: root._lcF; direction: PathArc.Clockwise }
        PathLine { x: root._lcX - root._lcC; y: root._lcBot }
        PathArc  { x: root._lcX; y: root._lcBot - root._lcC
                   radiusX: root._lcC; radiusY: root._lcC; direction: PathArc.Counterclockwise }
        PathLine { x: root._lcX; y: root._lcTop + root._lcC }
        PathArc  { x: root._lcX - root._lcC; y: root._lcTop
                   radiusX: root._lcC; radiusY: root._lcC; direction: PathArc.Counterclockwise }
        PathLine { x: root._t + root._lcF; y: root._lcTop }
        PathArc  { x: root._t; y: root._lcTop - root._lcF
                   radiusX: root._lcF; radiusY: root._lcF; direction: PathArc.Clockwise }

        // ... up to its flare under the left notch
        PathLine { x: root._t; y: root._lh + root._Rl }
        PathArc  { x: root._t + root._Rl; y: root._lh
                   radiusX: root._Rl; radiusY: root._Rl; direction: PathArc.Clockwise }

        // Left notch: bottom edge, convex corner, side, flare into the strip
        PathLine { x: root.leftWidth - root._r; y: root._lh }
        PathArc  { x: root.leftWidth; y: root._lh - root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root.leftWidth; y: root._t + root._r }
        PathArc  { x: root.leftWidth + root._r; y: root._t
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }

        // Top strip → center notch
        PathLine { x: root._cS - root._r; y: root._t }
        PathArc  { x: root._cS; y: root._t + root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }
        PathLine { x: root._cS; y: root._ch - root._r }
        PathArc  { x: root._cS + root._r; y: root._ch
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root._cE - root._r; y: root._ch }
        PathArc  { x: root._cE; y: root._ch - root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root._cE; y: root._t + root._r }
        PathArc  { x: root._cE + root._r; y: root._t
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }

        // Top strip → right notch
        PathLine { x: root._rS - root._r; y: root._t }
        PathArc  { x: root._rS; y: root._t + root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }
        PathLine { x: root._rS; y: root._rh - root._r }
        PathArc  { x: root._rS + root._r; y: root._rh
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }

        // Right notch bottom edge → flare into the right border
        PathLine { x: root.width - root._t - root._Rr; y: root._rh }
        PathArc  { x: root.width - root._t; y: root._rh + root._Rr
                   radiusX: root._Rr; radiusY: root._Rr; direction: PathArc.Clockwise }

        // Right border, with the right-center bump halfway down
        PathLine { x: root.width - root._t; y: root._rcTop - root._rcF }
        PathArc  { x: root.width - root._t - root._rcF; y: root._rcTop
                   radiusX: root._rcF; radiusY: root._rcF; direction: PathArc.Clockwise }
        PathLine { x: root._rcX + root._rcC; y: root._rcTop }
        PathArc  { x: root._rcX; y: root._rcTop + root._rcC
                   radiusX: root._rcC; radiusY: root._rcC; direction: PathArc.Counterclockwise }
        PathLine { x: root._rcX; y: root._rcBot - root._rcC }
        PathArc  { x: root._rcX + root._rcC; y: root._rcBot
                   radiusX: root._rcC; radiusY: root._rcC; direction: PathArc.Counterclockwise }
        PathLine { x: root.width - root._t - root._rcF; y: root._rcBot }
        PathArc  { x: root.width - root._t; y: root._rcBot + root._rcF
                   radiusX: root._rcF; radiusY: root._rcF; direction: PathArc.Clockwise }

        // Bottom-right corner, bottom border, bottom-left corner
        PathLine { x: root.width - root._t; y: root.height - root._t - root._R }
        PathArc  { x: root.width - root._t - root._R; y: root.height - root._t
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }
        PathLine { x: root._t + root._R; y: root.height - root._t }
        PathArc  { x: root._t; y: root.height - root._t - root._R
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }
    }

    // ── Bottom-center panel (wallpaper) ──────────────────────────────────────
    ShapePath {
        fillColor:   root.bottomCenterHeight >= 1 ? root.color : "transparent"
        strokeWidth: -1

        startX: root._bcL - root._bcF; startY: root.height - root._t
        PathArc  { x: root._bcL; y: root.height - root._t - root._bcF
                   radiusX: root._bcF; radiusY: root._bcF; direction: PathArc.Counterclockwise }
        PathLine { x: root._bcL; y: root._bcTop + root._bcC }
        PathArc  { x: root._bcL + root._bcC; y: root._bcTop
                   radiusX: root._bcC; radiusY: root._bcC; direction: PathArc.Clockwise }
        PathLine { x: root._bcR - root._bcC; y: root._bcTop }
        PathArc  { x: root._bcR; y: root._bcTop + root._bcC
                   radiusX: root._bcC; radiusY: root._bcC; direction: PathArc.Clockwise }
        PathLine { x: root._bcR; y: root.height - root._t - root._bcF }
        PathArc  { x: root._bcR + root._bcF; y: root.height - root._t
                   radiusX: root._bcF; radiusY: root._bcF; direction: PathArc.Counterclockwise }
        PathLine { x: root._bcR + root._bcF; y: root.height }
        PathLine { x: root._bcL - root._bcF; y: root.height }
        PathLine { x: root._bcL - root._bcF; y: root.height - root._t }
    }

    // ── Bottom-right panel (clipboard) ───────────────────────────────────────
    ShapePath {
        fillColor:   root.bottomRightHeight >= 1 ? root.color : "transparent"
        strokeWidth: -1

        startX: root.width - root._t; startY: root._brTop - root._brF
        PathArc  { x: root.width - root._t - root._brF; y: root._brTop
                   radiusX: root._brF; radiusY: root._brF; direction: PathArc.Clockwise }
        PathLine { x: root._brL + root._brC; y: root._brTop }
        PathArc  { x: root._brL; y: root._brTop + root._brC
                   radiusX: root._brC; radiusY: root._brC; direction: PathArc.Counterclockwise }
        PathLine { x: root._brL; y: root.height - root._t - root._brF }
        PathArc  { x: root._brL - root._brF; y: root.height - root._t
                   radiusX: root._brF; radiusY: root._brF; direction: PathArc.Clockwise }
        PathLine { x: root._brL - root._brF; y: root.height }
        PathLine { x: root.width; y: root.height }
        PathLine { x: root.width; y: root._brTop - root._brF }
        PathLine { x: root.width - root._t; y: root._brTop - root._brF }
    }
}
