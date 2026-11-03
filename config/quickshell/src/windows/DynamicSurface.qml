import Quickshell
import Quickshell.Wayland
import QtQuick
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../shapes/"
import "../"

// DynamicSurface — one fullscreen, transparent layer surface per screen that
// draws the whole frame (top notches + borders) as a single morphing shape
// and hosts the bar content (#37, prototype phase #38).
//
// Space for tiled windows is reserved by StrutWindow, not here: this window
// ignores exclusive zones. Clicks outside the visible frame pass through to
// the windows below thanks to the input mask.
//
// Keyboard focus (decided by the #38 spike): the surface asks for the
// keyboard with WlrKeyboardFocus.Exclusive only while `wantsKeyboard` is set
// (an interactive popup is open), and None otherwise, so clicking the frame
// never takes focus from the active window. Passive content (OSD, toasts)
// must never set it.
PanelWindow {
    id: root

    property bool wantsKeyboard: false

    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }
    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:     WlrLayer.Top
    WlrLayershell.namespace: "synapse-frame"
    WlrLayershell.keyboardFocus: wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Popup state for this screen (SurfaceState is global) ─────────────────
    readonly property string openRegion:
        screen && SurfaceState.activeScreen === screen.name ? SurfaceState.activeRegion : "none"
    readonly property string openContent:
        openRegion !== "none" ? SurfaceState.activeContent : "none"

    // ── Resolution scaling ───────────────────────────────────────────────────
    // Every frame size is a Metrics value times localScale, rounded to whole
    // pixels. Hosted contents get localScale too (default 1.0) and can adopt
    // it progressively.
    readonly property real localScale: SurfaceState.scaleFor(screen)
    function px(v) { return Math.round(v * localScale) }

    readonly property int borderWidth:  px(Theme.borderWidth)
    readonly property int notchHeight:  px(Theme.notchHeight)
    readonly property int notchRadius:  px(Theme.notchRadius)
    readonly property int cornerRadius: px(Theme.cornerRadius)
    readonly property int notchPadding: px(Theme.notchPadding)

    // ── Frame geometry (same rules TopBar uses today) ────────────────────────
    property real notchBottom: ShellState.focusMode ? borderWidth : notchHeight
    Behavior on notchBottom {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    readonly property int lWidth: Math.max(
        px(Theme.lNotchMinWidth),
        Math.min(px(Theme.lNotchMaxWidth), leftContent.implicitWidth + notchPadding * 2))

    property int cWidth: Math.max(
        px(Theme.cNotchMinWidth),
        Math.min(px(Theme.cNotchMaxWidth), centerContent.implicitWidth + notchPadding * 2))
    Behavior on cWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    property int rWidth: Math.max(
        px(Theme.rNotchMinWidth),
        Math.min(px(Theme.rNotchMaxWidth), rightContent.implicitWidth + notchPadding * 2))
    // Not animated, like TopBar: only popup states (#41) will animate it.

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // ── Shape ────────────────────────────────────────────────────────────────
    SurfaceShape {
        anchors.fill: parent
        borderWidth:  root.borderWidth
        notchRadius:  root.notchRadius
        cornerRadius: root.cornerRadius
        notchBottom:  root.notchBottom
        leftWidth:    root.lWidth
        centerWidth:  root.cWidth
        rightWidth:   root.rWidth
    }

    // ── Bar content (fades out in focus mode) ────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }

        Item {
            id: leftNotch
            x: 0; y: 0
            width:  root.lWidth
            height: root.notchHeight

            LeftContent {
                id: leftContent
                localScale: root.localScale
                anchors.centerIn: parent
            }
        }

        Item {
            id: centerNotch
            x: (root.width - root.cWidth) / 2; y: 0
            width:  root.cWidth
            height: root.notchHeight

            CenterContent {
                id: centerContent
                localScale: root.localScale
                anchors.centerIn: parent
            }
        }

        Item {
            id: rightNotch
            x: root.width - root.rWidth; y: 0
            width:  root.rWidth
            height: root.notchHeight
            clip:   true

            RightContent {
                id: rightContent
                localScale: root.localScale
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin:    root.notchPadding
            }
        }
    }

    // ── Input mask: only the visible frame takes clicks ──────────────────────
    readonly property int _edge: Math.max(1, borderWidth)

    Item { id: maskTop;    x: 0; y: 0; width: root.width; height: root._edge }
    Item { id: maskLeft;   x: 0; y: 0; width: root._edge; height: root.height }
    Item { id: maskRight;  x: root.width - root._edge; y: 0; width: root._edge; height: root.height }
    Item { id: maskBottom; x: 0; y: root.height - root._edge; width: root.width; height: root._edge }
    Item { id: maskLeftNotch;   x: leftNotch.x;   y: 0; width: leftNotch.width;   height: root.notchBottom }
    Item { id: maskCenterNotch; x: centerNotch.x; y: 0; width: centerNotch.width; height: root.notchBottom }
    Item { id: maskRightNotch;  x: rightNotch.x;  y: 0; width: rightNotch.width;  height: root.notchBottom }

    mask: Region {
        Region { item: maskTop;         intersection: Intersection.Combine }
        Region { item: maskLeft;        intersection: Intersection.Combine }
        Region { item: maskRight;       intersection: Intersection.Combine }
        Region { item: maskBottom;      intersection: Intersection.Combine }
        Region { item: maskLeftNotch;   intersection: Intersection.Combine }
        Region { item: maskCenterNotch; intersection: Intersection.Combine }
        Region { item: maskRightNotch;  intersection: Intersection.Combine }
    }
}
