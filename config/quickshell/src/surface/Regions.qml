import QtQuick
import qs.src.state
import qs.src.theme
// Regions — the frame geometry of one DynamicSurface: each region's target
// size (the open popup's spec, or the passive content's), the collision rules
// between them, and the animated sizes and rectangles the shape, the popups
// and the input mask follow.
//
// Regions: top (center notch), right (right notch), leftCenter / rightCenter
// (bumps on the side borders), bottomCenter / bottomRight (panels on the
// bottom border). The left notch only follows the bar.
Item {
    id: g

    // The DynamicSurface: open spec and item, passive content, sizes, bar
    required property var surface
    readonly property var s: surface

    component Anim: NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }

    // ── Targets ──────────────────────────────────────────────────────────────
    // The open popup's size, or the passive content's, or closed ([0, 0]).
    // Targets are kept separate from the animated sizes so the collision checks
    // compare final sizes, not mid-animation ones.
    function _target(region) {
        const spec = s.openSpec
        if (spec && spec.region === region) return spec.size(s, s.openItem)
        if (region === "right" && s.toastShown)
            return [s.toastWidth, notchBottom + s.toastHeight + s.px(26)]
        if (region === "rightCenter" && s.quickShown) return [s.quickWidth, s.sideHeight]
        return [0, 0]
    }
    readonly property var _topT:          _target("top")
    readonly property var _rightT:        _target("right")
    readonly property var _leftCenterT:   _target("leftCenter")
    readonly property var _rightCenterT:  _target("rightCenter")
    readonly property var _bottomCenterT: _target("bottomCenter")
    readonly property var _bottomRightT:  _target("bottomRight")

    // ── Collisions ───────────────────────────────────────────────────────────
    // Interactive popups never overlap (one at a time); passive content yields
    // when it would hit the open popup's region.
    // Toast: the grown right notch must stay clear of the center notch.
    readonly property bool toastFits:
        s.width - s.toastWidth - s.notchRadius > (s.width + cWidth) / 2 + s.notchRadius
    // OSD: the right notch (plus both flares) must stay above the right-center
    // region, and the clipboard panel must stay below it.
    readonly property bool quickFits: {
        const spec = s.openSpec
        const top = (s.height - s.sideHeight) / 2, bottom = (s.height + s.sideHeight) / 2
        const rightBottom = spec && spec.region === "right" ? spec.size(s, s.openItem)[1] : notchBottom
        const clipTop = spec && spec.region === "bottomRight"
                      ? s.height - s.borderWidth - spec.size(s, s.openItem)[1] : s.height
        return rightBottom + 2 * s.cornerRadius < top && bottom + 2 * s.cornerRadius < clipTop
    }

    // ── Animated geometry ────────────────────────────────────────────────────
    property real notchBottom: ShellModes.focusMode ? s.borderWidth : s.notchHeight
    Behavior on notchBottom { Anim {} }

    readonly property int lWidth: Math.max(
        s.px(Theme.lNotchMinWidth),
        Math.min(s.px(Theme.lNotchMaxWidth), s.barLeftWidth + s.notchPadding * 2))

    property real cWidth: _topT[0] > 0 ? _topT[0]
        : Math.max(s.px(Theme.cNotchMinWidth),
                   Math.min(s.px(Theme.cNotchMaxWidth), s.barCenterWidth + s.notchPadding * 2))
    Behavior on cWidth { Anim {} }
    property real _cDrop: Math.max(0, _topT[1] - notchBottom)
    Behavior on _cDrop { Anim {} }
    readonly property real centerBottom: notchBottom + _cDrop

    // The right notch follows its content instantly; only a popup or the
    // toast morph it.
    readonly property int _rBase: Math.max(
        s.px(Theme.rNotchMinWidth),
        Math.min(s.px(Theme.rNotchMaxWidth), s.barRightWidth + s.notchPadding * 2))
    property real _rGrow: _rightT[0]
    Behavior on _rGrow { Anim {} }
    property real _rDrop: Math.max(0, _rightT[1] - notchBottom)
    Behavior on _rDrop { Anim {} }
    readonly property real rWidth:      Math.max(_rBase, _rGrow)
    readonly property real rightBottom: notchBottom + _rDrop

    property real leftCenterDepth:    _leftCenterT[0]
    property real leftCenterHeight:   _leftCenterT[1] > 0 ? _leftCenterT[1] : s.sideHeight
    property real rightCenterDepth:   _rightCenterT[0]
    property real rightCenterHeight:  _rightCenterT[1] > 0 ? _rightCenterT[1] : s.sideHeight
    property real bottomCenterWidth:  _bottomCenterT[0]
    property real bottomCenterHeight: _bottomCenterT[1]
    property real bottomRightWidth:   _bottomRightT[0]
    property real bottomRightHeight:  _bottomRightT[1]
    Behavior on leftCenterDepth    { Anim {} }
    Behavior on rightCenterDepth   { Anim {} }
    Behavior on bottomCenterWidth  { Anim {} }
    Behavior on bottomCenterHeight { Anim {} }
    Behavior on bottomRightWidth   { Anim {} }
    Behavior on bottomRightHeight  { Anim {} }

    // Current (animated) rectangle of a region, in surface coordinates.
    function rect(region) {
        const w = s.width, h = s.height, b = s.borderWidth
        switch (region) {
        case "top":
            return Qt.rect((w - cWidth) / 2, 0, cWidth, centerBottom)
        case "right":
            return Qt.rect(w - rWidth, s.notchHeight, rWidth - b,
                           Math.max(0, rightBottom - s.notchHeight))
        case "leftCenter":
            return Qt.rect(b, (h - leftCenterHeight) / 2, leftCenterDepth, leftCenterHeight)
        case "rightCenter":
            return Qt.rect(w - b - rightCenterDepth, (h - rightCenterHeight) / 2,
                           rightCenterDepth, rightCenterHeight)
        case "bottomCenter":
            return Qt.rect((w - bottomCenterWidth) / 2 - s.notchRadius,
                           h - b - bottomCenterHeight,
                           bottomCenterWidth + 2 * s.notchRadius, bottomCenterHeight)
        case "bottomRight":
            return Qt.rect(w - b - bottomRightWidth, h - b - bottomRightHeight,
                           bottomRightWidth, bottomRightHeight)
        }
        return Qt.rect(0, 0, 0, 0)
    }
}
