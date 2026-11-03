import QtQuick
import QtQuick.Shapes
import "../"
import "surfacePath.js" as SurfacePath

// SurfaceShape — the whole frame (top strip with its 3 notches, side and
// bottom borders, and every region grown out of it) drawn as ONE path.
//
// The path itself is built by surfacePath.js (pure JS, unit-tested in
// tests/surface-path.test.mjs) and filled with the non-zero rule, so regions
// that overlap the frame are filled once — no double alpha once the frame
// becomes translucent (#34). Every size is a plain property: animating one
// morphs the shape (#37). Replaces SeamlessBarShape + Border's canvases once
// the surface is the default.
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
    // (clipboard). Size 0 = closed: the plain border and rounded corner.
    property real bottomCenterWidth:  0
    property real bottomCenterHeight: 0
    property real bottomRightWidth:   0
    property real bottomRightHeight:  0

    property color color: Theme.background

    readonly property string path: SurfacePath.build({
        width:  root.width,
        height: root.height,
        t:      root.borderWidth,
        r:      root.notchRadius,
        R:      root.cornerRadius,
        notchBottom: root.notchBottom,
        left:   { width: root.leftWidth,   bottom: root.leftBottom },
        center: { width: root.centerWidth, bottom: root.centerBottom },
        right:  { width: root.rightWidth,  bottom: root.rightBottom },
        leftCenter:   { depth: root.leftCenterDepth,  height: root.leftCenterHeight },
        rightCenter:  { depth: root.rightCenterDepth, height: root.rightCenterHeight },
        bottomCenter: { width: root.bottomCenterWidth, height: root.bottomCenterHeight },
        bottomRight:  { width: root.bottomRightWidth,  height: root.bottomRightHeight }
    })

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor:   root.color
        strokeWidth: -1
        fillRule:    ShapePath.WindingFill
        PathSvg { path: root.path }
    }
}
