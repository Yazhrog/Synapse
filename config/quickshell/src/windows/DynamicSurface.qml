import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../shapes/"
import "../components/"
import "../"

// DynamicSurface — one fullscreen, transparent layer surface per screen that
// draws the whole frame (top notches + borders) as a single morphing shape
// and hosts the bar content (#37, prototype phase #38) and the passive
// content (#40): the notification toast grows the right notch, the Quick
// Controls OSD opens the right-center region.
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

    // Follows its content instantly, like TopBar; only the toast (and the
    // popups, #41) morph it, through _rGrow/_rDrop.
    readonly property int _rBase: Math.max(
        px(Theme.rNotchMinWidth),
        Math.min(px(Theme.rNotchMaxWidth), rightContent.implicitWidth + notchPadding * 2))
    readonly property int rWidth: Math.max(_rBase, _rGrow)
    readonly property real rightBottom: notchBottom + _rDrop

    // ── Passive content (#40) ────────────────────────────────────────────────
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool   _focusedHere: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName

    // Notification toast: grows the right notch on the screen it was shown on.
    // An interactive popup in the right region wins and hides it.
    readonly property bool toastShown: ToastState.isOn(screenName) && ToastState.showing
                                       && openRegion !== "right"
    readonly property int  toastWidth: px(Theme.notificationToastWidth + Theme.notchRadius + Theme.notchPadding - 3)

    property real _rGrow: toastShown ? toastWidth : 0
    Behavior on _rGrow { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    property real _rDrop: toastShown ? toastCard.implicitHeight + px(26) : 0
    Behavior on _rDrop { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    // Quick Controls OSD: right-center region, on the focused monitor, unless
    // an interactive popup (audio, #41) owns that region.
    readonly property bool quickShown: Popups.quickOpen && _focusedHere && openRegion !== "rightCenter"
    readonly property int  quickDepth:  px(180)
    readonly property int  quickHeight: px(340 - 2 * Theme.cornerRadius)

    property real rightCenterDepth: quickShown ? quickDepth : 0
    Behavior on rightCenterDepth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

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
        rightBottom:  root.rightBottom
        rightCenterDepth:  root.rightCenterDepth
        rightCenterHeight: root.quickHeight
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

    // ── Toast, inside the grown right notch ──────────────────────────────────
    ToastCard {
        id: toastCard
        x:        root.width - root.rWidth + root.px(14)
        y:        root.notchHeight + root.px(4)
        width:    root.toastWidth - root.px(14) - root.borderWidth - root.notchPadding
        barWidth: width
        visible:  opacity > 0
        opacity:  root.toastShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ── Quick Controls OSD, inside the right-center region ───────────────────
    Item {
        id: quickRegion
        x:      root.width - root.borderWidth - root.rightCenterDepth
        y:      (root.height - root.quickHeight) / 2
        width:  root.rightCenterDepth
        height: root.quickHeight
        clip:   true
        visible: opacity > 0
        opacity: root.quickShown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Hovering keeps the OSD open (see IpcManager's hide timer).
        HoverHandler { onHoveredChanged: Popups.quickHeld = hovered }

        QuickControlContent {
            x:        root.px(8)
            y:        root.px(30)
            width:    root.quickDepth - root.px(16)
            height:   parent.height - root.px(30)
            fastPoll: root.quickShown
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
    Item { id: maskRightNotch;  x: rightNotch.x;  y: 0; width: rightNotch.width;  height: root.rightBottom }
    Item { id: maskQuick; x: quickRegion.x; y: quickRegion.y; width: quickRegion.width; height: quickRegion.height }

    mask: Region {
        Region { item: maskTop;         intersection: Intersection.Combine }
        Region { item: maskLeft;        intersection: Intersection.Combine }
        Region { item: maskRight;       intersection: Intersection.Combine }
        Region { item: maskBottom;      intersection: Intersection.Combine }
        Region { item: maskLeftNotch;   intersection: Intersection.Combine }
        Region { item: maskCenterNotch; intersection: Intersection.Combine }
        Region { item: maskRightNotch;  intersection: Intersection.Combine }
        Region { item: maskQuick;       intersection: Intersection.Combine }
    }
}
