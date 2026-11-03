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

    property color color: Theme.background

    // ── Derived values ───────────────────────────────────────────────────────
    // Closed regions keep a tiny depth instead of 0 and every radius is
    // clamped to the room available, so the path never degenerates while
    // animating (e.g. into focus mode, where notchBottom → borderWidth).
    readonly property real _t:     borderWidth
    readonly property real _h:     Math.max(_t + 0.001, notchBottom)
    readonly property real _r:     Math.max(0.001, Math.min(notchRadius, (_h - _t) / 2))
    readonly property real _R:     Math.max(0.001, Math.min(cornerRadius, (height - _h - _t) / 2))
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

        // Left border, up to its flare under the left notch
        PathLine { x: root._t; y: root._h + root._R }
        PathArc  { x: root._t + root._R; y: root._h
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }

        // Left notch: bottom edge, convex corner, side, flare into the strip
        PathLine { x: root.leftWidth - root._r; y: root._h }
        PathArc  { x: root.leftWidth; y: root._h - root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root.leftWidth; y: root._t + root._r }
        PathArc  { x: root.leftWidth + root._r; y: root._t
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }

        // Top strip → center notch
        PathLine { x: root._cS - root._r; y: root._t }
        PathArc  { x: root._cS; y: root._t + root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }
        PathLine { x: root._cS; y: root._h - root._r }
        PathArc  { x: root._cS + root._r; y: root._h
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root._cE - root._r; y: root._h }
        PathArc  { x: root._cE; y: root._h - root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }
        PathLine { x: root._cE; y: root._t + root._r }
        PathArc  { x: root._cE + root._r; y: root._t
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }

        // Top strip → right notch
        PathLine { x: root._rS - root._r; y: root._t }
        PathArc  { x: root._rS; y: root._t + root._r
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Clockwise }
        PathLine { x: root._rS; y: root._h - root._r }
        PathArc  { x: root._rS + root._r; y: root._h
                   radiusX: root._r; radiusY: root._r; direction: PathArc.Counterclockwise }

        // Right notch bottom edge → flare into the right border
        PathLine { x: root.width - root._t - root._R; y: root._h }
        PathArc  { x: root.width - root._t; y: root._h + root._R
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }

        // Right border, bottom-right corner, bottom border, bottom-left corner
        PathLine { x: root.width - root._t; y: root.height - root._t - root._R }
        PathArc  { x: root.width - root._t - root._R; y: root.height - root._t
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }
        PathLine { x: root._t + root._R; y: root.height - root._t }
        PathArc  { x: root._t; y: root.height - root._t - root._R
                   radiusX: root._R; radiusY: root._R; direction: PathArc.Clockwise }
    }
}
