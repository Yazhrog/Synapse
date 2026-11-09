import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../shapes/"
import "../components/"
import "../services/"
import "../popups/"
import "../theme/"
import "../"
import "surface"

// DynamicSurface — one fullscreen, transparent layer surface per screen that
// draws the whole frame (top notches + borders) as a single morphing shape
// and hosts everything on it: the bar, the interactive popups (each grows a
// region of the frame), the passive content (notification toast, Quick
// Controls OSD), the click shield and the border triggers (#37).
//
// Adding a popup: one entry in `contents` (region, size, placement, focus,
// component) and its key in SurfaceState.regionOf. Regions: top (center
// notch), right (right notch), leftCenter / rightCenter (bumps on the side
// borders), bottomCenter / bottomRight (panels on the bottom border).
//
// Space for tiled windows is reserved by StrutWindow, not here: this window
// ignores exclusive zones. Clicks outside the visible frame pass through to
// the windows below thanks to the input mask.
//
// Keyboard focus (decided by the #38 spike): the surface asks for the
// keyboard with WlrKeyboardFocus.Exclusive only while `wantsKeyboard` is set
// (an interactive popup or the screen-recording setup is open), and None
// otherwise, so clicking the frame never takes focus from the active window.
// Passive content (OSD, toasts) must never set it.
PanelWindow {
    id: root

    component Anim: NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    component Fade: NumberAnimation { duration: Metrics.regionFadeDuration }

    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }
    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    // Overlay: Hyprland draws fullscreen windows above
    // the Top layer, so popups and the OSD would be invisible (and the keyboard
    // seemingly stuck) in a fullscreen app. On a screen showing a fullscreen
    // window, the frame hides itself unless it has something to show.
    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "synapse-frame"
    WlrLayershell.keyboardFocus: wantsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Screen and popup state ───────────────────────────────────────────────
    readonly property string screenName:   screen ? screen.name : ""
    readonly property bool   _focusedHere: !Hyprland.focusedMonitor || Hyprland.focusedMonitor.name === screenName

    // SurfaceState is global; this is what's open on this screen.
    readonly property string openRegion:
        SurfaceState.activeScreen === screenName ? SurfaceState.activeRegion : "none"
    readonly property string openContent:
        openRegion !== "none" ? SurfaceState.activeContent : "none"
    readonly property var    openSpec: contents[openContent] ?? null

    // The screen-recording setup (bar carousel) also wants Escape to cancel it.
    readonly property bool recSetup:      ShellState.screenRecord && !ScreenRecService.recording
    readonly property bool wantsKeyboard: openSpec !== null || (recSetup && _focusedHere)

    // ── Fullscreen ───────────────────────────────────────────────────────────
    // Only a real fullscreen window hides the frame, not a maximized one:
    // Hyprland's hasfullscreen is true for both, so look at the windows'
    // fullscreen mode (a bitmask: 1 maximized, 2 fullscreen).
    readonly property var  _monitor: Hyprland.monitorFor(screen)
    readonly property bool fullscreenHere: {
        const ws = _monitor ? _monitor.activeWorkspace : null
        if (!ws || !ws.hasFullscreen) return false
        const wins = ws.toplevels ? ws.toplevels.values : []
        for (let i = 0; i < wins.length; i++) {
            const ipc = wins[i].lastIpcObject
            if (ipc && ((ipc.fullscreen ?? 0) & 2)) return true
        }
        return false
    }
    readonly property bool showingSomething: openContent !== "none" || quickShown || toastShown
                                             || recOptions.visible
    readonly property bool frameHidden: fullscreenHere && !showingSomething

    Binding { target: root.contentItem; property: "opacity"; value: root.frameHidden ? 0 : 1 }

    // hasFullscreen is only refreshed with the workspace list, and each
    // window's fullscreen mode with the toplevel list.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") {
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
            }
        }
    }

    // ── Resolution scaling ───────────────────────────────────────────────────
    // Every frame and region size is a Metrics value times localScale, rounded
    // to whole pixels (see SurfaceState.scaleFor; off by default, because the
    // hosted contents aren't scaled yet).
    readonly property real localScale: SurfaceState.scaleFor(screen)
    function px(v) { return Math.round(v * localScale) }

    // Bar style (Config → Appearance): frame, bar or pills. borderWidth is the
    // frame's border; there are no borders in bar, and in pills it's the gap
    // between the floating shapes and the screen edges, so every region rect
    // and placement below works unchanged in the three styles.
    readonly property string barStyle: Theme.barStyle
    readonly property bool   framed:   barStyle === "frame"
    readonly property bool   pills:    barStyle === "pills"
    readonly property int borderWidth:  framed ? px(Theme.borderWidth)
                                        : pills ? px(Metrics.pillGap) : 0
    readonly property int notchHeight:  px(Theme.notchHeight)
    readonly property int notchRadius:  px(Theme.notchRadius)
    readonly property int cornerRadius: px(Theme.cornerRadius)
    readonly property int notchPadding: px(Theme.notchPadding)

    // ── Interactive popups ───────────────────────────────────────────────────
    // size():  the region's target size, in px —
    //            top:          [notch width, notch bottom y]
    //            right:        [notch width, notch bottom y]
    //            leftCenter / rightCenter: [depth, height]
    //            bottomCenter / bottomRight: [width, height]
    // place(w, h): where the content goes inside its region's clip item.
    // focus(item): gives the keyboard to the content once it's open.
    // afterClose(item): runs once the close animation is over.
    readonly property var contents: ({
        powerMenu: {
            region: "leftCenter",
            component: powerComp,
            size:  () => [px(Metrics.powerMenuWidth + 2 * Metrics.powerMenuPadding),
                          px(Metrics.powerMenuHeight + 2 * Metrics.powerMenuPadding)],
            place: (w, h) => Qt.rect(px(4), px(Metrics.powerMenuPadding),
                                     px(Metrics.powerMenuWidth), px(Metrics.powerMenuHeight)),
            focus: item => item.reset()
        },
        audio: {
            region: "rightCenter",
            component: audioComp,
            size:  () => [px(Metrics.audioPageWidths[root._audioPage] ?? 300), px(Metrics.sideRegionHeight)],
            place: (w, h) => Qt.rect(px(10), px(6), px(Metrics.audioPageWidths[root._audioPage] ?? 300) - px(16), h - px(12)),
            focus: item => popupScope.forceActiveFocus(),
            afterClose: item => item.reset()
        },
        notifications: {
            region: "right",
            component: notifComp,
            size:  () => [px(Theme.notificationsWidth + Theme.notchRadius) + borderWidth,
                          notchBottom + root._notifListHeight + px(2 * Theme.popupPadding + 4)],
            place: (w, h) => Qt.rect(px(Theme.notchRadius + 4), px(4),
                                     px(Theme.notificationsWidth - 8), h),
            focus: item => popupScope.forceActiveFocus()
        },
        network: {
            region: "right",
            component: networkComp,
            size:  () => [px(Metrics.networkPopupBodyWidth) + borderWidth,
                          px(Metrics.networkPopupHeight - Theme.notchRadius)],
            place: (w, h) => Qt.rect(px(Theme.notchRadius), 0,
                                     px(Metrics.networkPopupBodyWidth - Theme.notchRadius - 7),
                                     px(Metrics.networkPopupHeight - Theme.notchRadius - Theme.cornerRadius) - notchHeight),
            focus: item => popupScope.forceActiveFocus()
        },
        dashboard: {
            region: "top",
            component: dashboardComp,
            size:  () => [px(Popups.dashboardPageWidth), px(Theme.dashboardHeight)],
            place: (w, h) => Qt.rect(px(8), px(Theme.notchRadius + 8),
                                     px(Popups.dashboardPageWidth - 16),
                                     px(Theme.dashboardHeight - Theme.notchRadius - 16)),
            focus: item => item.focusPage(),
            afterClose: item => item.reset()
        },
        wallpaper: {
            region: "bottomCenter",
            component: wallpaperComp,
            size:  () => [px(Metrics.wallpaperPanelWidth), px(Metrics.wallpaperPanelHeight)],
            place: (w, h) => Qt.rect((w - px(Metrics.wallpaperPanelWidth) - 2 * notchRadius) / 2, 0,
                                     px(Metrics.wallpaperPanelWidth) + 2 * notchRadius,
                                     px(Metrics.wallpaperPanelHeight)),
            focus: item => item.focusSearch()
        },
        clipboard: {
            region: "bottomRight",
            component: clipboardComp,
            size:  () => [px(Metrics.clipboardPanelWidth), px(Metrics.clipboardPanelHeight)],
            place: (w, h) => Qt.rect(px(10), px(8), px(Metrics.clipboardPanelWidth - 10),
                                     px(Metrics.clipboardPanelHeight - 16)),
            focus: item => item.forceActiveFocus()
        }
    })
    readonly property var contentKeys: Object.keys(contents)

    // Fed by the contents themselves (their size depends on them).
    property real   _notifListHeight: 0
    property string _audioPage:       Popups.audioPage

    Component { id: powerComp;     PowerMenu {} }
    Component { id: audioComp;     AudioControl {
        onPageChanged: root._audioPage = page
        Component.onCompleted: root._audioPage = page
    } }
    // Wrapped, so the Loader resizes the wrapper and the list keeps the
    // height it computes for itself (the region's size follows it).
    Component {
        id: notifComp
        Item {
            NotificationList {
                width: parent.width
                onHeightChanged:       root._notifListHeight = height
                Component.onCompleted: root._notifListHeight = height
            }
        }
    }
    Component { id: networkComp;   NetworkContent { page: Popups.networkPage || "wifi" } }
    Component { id: dashboardComp; DashboardContent {} }
    Component {
        id: wallpaperComp
        WallpaperContent {
            fw:   root.notchRadius
            fh:   root.notchRadius
            edgeInset: root.framed ? root.borderWidth : 0
            open: root.openContent === "wallpaper"
        }
    }
    Component {
        id: clipboardComp
        FocusScope {
            Keys.onEscapePressed: Popups.close("clipboard")
            HistoryTab { anchors.fill: parent }
        }
    }

    // ── Passive content (#40) ────────────────────────────────────────────────
    // Notification toast: grows the right notch on the screen it was shown on.
    readonly property bool toastShown: ToastState.isOn(screenName) && ToastState.showing
                                       && openRegion !== "right" && _toastFits
    readonly property int  toastWidth: px(Theme.notificationToastWidth + Theme.notchRadius + Metrics.toastNotchExtra)

    // Quick Controls OSD: right-center region, on the focused monitor or while
    // its border trigger is hovered, unless a popup owns that region.
    readonly property bool quickShown: ((Popups.quickOpen && _focusedHere) || triggers.quickHoverOpen)
                                       && openRegion !== "rightCenter" && _quickFits
    readonly property int  quickWidth:  px(Metrics.osdWidth)
    readonly property int  sideHeight:  px(Metrics.sideRegionHeight)

    // ── Region targets ───────────────────────────────────────────────────────
    // The open popup's size, or the passive content's, or closed ([0, 0]).
    // Targets are kept separate from the animated sizes so the collision checks
    // compare final sizes, not mid-animation ones.
    function _target(region) {
        if (openSpec && openSpec.region === region) return openSpec.size()
        if (region === "right" && toastShown)
            return [toastWidth, notchBottom + toastCard.implicitHeight + px(26)]
        if (region === "rightCenter" && quickShown) return [quickWidth, sideHeight]
        return [0, 0]
    }
    readonly property var _topT:          _target("top")
    readonly property var _rightT:        _target("right")
    readonly property var _leftCenterT:   _target("leftCenter")
    readonly property var _rightCenterT:  _target("rightCenter")
    readonly property var _bottomCenterT: _target("bottomCenter")
    readonly property var _bottomRightT:  _target("bottomRight")

    // ── Region collisions ────────────────────────────────────────────────────
    // Interactive popups never overlap (one at a time); passive content yields
    // when it would hit the open popup's region.
    // Toast: the grown right notch must stay clear of the center notch.
    readonly property bool _toastFits:
        width - toastWidth - notchRadius > (width + cWidth) / 2 + notchRadius
    // OSD: the right notch (plus both flares) must stay above the right-center
    // region, and the clipboard panel must stay below it.
    readonly property bool _quickFits: {
        const top = (height - sideHeight) / 2, bottom = (height + sideHeight) / 2
        const rightBottom = openSpec && openSpec.region === "right" ? openSpec.size()[1] : notchBottom
        const clipTop = openSpec && openSpec.region === "bottomRight"
                      ? height - borderWidth - openSpec.size()[1] : height
        return rightBottom + 2 * cornerRadius < top && bottom + 2 * cornerRadius < clipTop
    }

    // ── Frame geometry (animated) ────────────────────────────────────────────
    property real notchBottom: ShellState.focusMode ? borderWidth : notchHeight
    Behavior on notchBottom { Anim {} }

    readonly property int lWidth: Math.max(
        px(Theme.lNotchMinWidth),
        Math.min(px(Theme.lNotchMaxWidth), bar.leftContentWidth + notchPadding * 2))

    property real cWidth: _topT[0] > 0 ? _topT[0]
        : Math.max(px(Theme.cNotchMinWidth),
                   Math.min(px(Theme.cNotchMaxWidth), bar.centerContentWidth + notchPadding * 2))
    Behavior on cWidth { Anim {} }
    property real _cDrop: Math.max(0, _topT[1] - notchBottom)
    Behavior on _cDrop { Anim {} }
    readonly property real centerBottom: notchBottom + _cDrop

    // The right notch follows its content instantly; only a popup or the
    // toast morph it.
    readonly property int _rBase: Math.max(
        px(Theme.rNotchMinWidth),
        Math.min(px(Theme.rNotchMaxWidth), bar.rightContentWidth + notchPadding * 2))
    property real _rGrow: _rightT[0]
    Behavior on _rGrow { Anim {} }
    property real _rDrop: Math.max(0, _rightT[1] - notchBottom)
    Behavior on _rDrop { Anim {} }
    readonly property real rWidth:      Math.max(_rBase, _rGrow)
    readonly property real rightBottom: notchBottom + _rDrop

    property real leftCenterDepth:    _leftCenterT[0]
    property real leftCenterHeight:   _leftCenterT[1] > 0 ? _leftCenterT[1] : sideHeight
    property real rightCenterDepth:   _rightCenterT[0]
    property real rightCenterHeight:  _rightCenterT[1] > 0 ? _rightCenterT[1] : sideHeight
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
    function regionRect(region) {
        switch (region) {
        case "top":
            return Qt.rect((width - cWidth) / 2, 0, cWidth, centerBottom)
        case "right":
            return Qt.rect(width - rWidth, notchHeight, rWidth - borderWidth,
                           Math.max(0, rightBottom - notchHeight))
        case "leftCenter":
            return Qt.rect(borderWidth, (height - leftCenterHeight) / 2, leftCenterDepth, leftCenterHeight)
        case "rightCenter":
            return Qt.rect(width - borderWidth - rightCenterDepth, (height - rightCenterHeight) / 2,
                           rightCenterDepth, rightCenterHeight)
        case "bottomCenter":
            return Qt.rect((width - bottomCenterWidth) / 2 - notchRadius,
                           height - borderWidth - bottomCenterHeight,
                           bottomCenterWidth + 2 * notchRadius, bottomCenterHeight)
        case "bottomRight":
            return Qt.rect(width - borderWidth - bottomRightWidth, height - borderWidth - bottomRightHeight,
                           bottomRightWidth, bottomRightHeight)
        }
        return Qt.rect(0, 0, 0, 0)
    }

    // ── Click shield (#42) ───────────────────────────────────────────────────
    // On the screen owning the open popup (switching monitor closes it via
    // ShellHost), the whole surface takes clicks and a click outside the popup,
    // the bar and the borders closes it. It sits below everything else, so the
    // popups and the bar still get their own clicks first.
    readonly property bool shieldActive: openContent !== "none" || (recSetup && _focusedHere)

    SurfaceClickShield {
        anchors.fill: parent
        surface:      root
        recOptions:   recOptions
    }

    // ── Shape ────────────────────────────────────────────────────────────────
    SurfaceShape {
        anchors.fill: parent
        style:        root.barStyle
        borderWidth:  root.borderWidth
        notchRadius:  root.notchRadius
        cornerRadius: root.cornerRadius
        notchBottom:  root.notchBottom
        leftWidth:    root.lWidth
        centerWidth:  root.cWidth
        rightWidth:   root.rWidth
        centerBottom: root.centerBottom
        rightBottom:  root.rightBottom
        leftCenterDepth:    root.leftCenterDepth
        leftCenterHeight:   root.leftCenterHeight
        rightCenterDepth:   root.rightCenterDepth
        rightCenterHeight:  root.rightCenterHeight
        bottomCenterWidth:  root.bottomCenterWidth
        bottomCenterHeight: root.bottomCenterHeight
        bottomRightWidth:   root.bottomRightWidth
        bottomRightHeight:  root.bottomRightHeight
    }

    // ── Bar content (fades out in focus mode) ────────────────────────────────
    SurfaceBar {
        id: bar
        anchors.fill: parent
        surface:      root
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
        Behavior on opacity { Fade {} }
    }

    // ── Quick Controls OSD, inside the right-center region ───────────────────
    Item {
        id: quickRegion
        readonly property rect r: root.regionRect("rightCenter")
        x: r.x; y: r.y; width: r.width; height: r.height
        clip:   true
        visible: opacity > 0
        opacity: root.quickShown ? 1 : 0
        Behavior on opacity { Fade {} }

        // Hovering keeps the OSD open (see IpcManager's hide timer).
        HoverHandler { id: quickHover; onHoveredChanged: Popups.quickHeld = hovered }

        QuickControlContent {
            x:        root.px(8)
            y:        root.px(Metrics.osdTopPadding)
            width:    root.quickWidth - root.px(16)
            height:   parent.height - root.px(Metrics.osdTopPadding)
            fastPoll: root.quickShown
        }
    }

    // ── Interactive popups ───────────────────────────────────────────────────
    // Each content grows out of its region; see SurfacePopupHost.
    SurfacePopupHost {
        id: popupScope
        anchors.fill: parent
        surface:      root
    }

    // ── Border triggers (#42): OSD hover, wallpaper and clipboard taps ───────
    SurfaceTriggers {
        id: triggers
        anchors.fill: parent
        surface:      root
        osdHovered:   quickHover.hovered
    }

    // ── Screen-recording options (capture / audio), under the center notch ──
    ScreenRecOptions {
        id: recOptions
        x:       ScreenRecService.popupTargetX + ScreenRecService.popupTargetWidth / 2
        y:       root.notchHeight + 25
        width:   implicitWidth
        height:  implicitHeight
        visible: ScreenRecService.openStrip !== "" && ScreenRecService.popupTargetScreen === root.screenName

        HoverHandler {
            onHoveredChanged: {
                if (hovered) ScreenRecService.keepStripOpen()
                else         ScreenRecService.scheduleStripClose()
            }
        }
    }

    // ── Focus mode: the bar is a thin strip; tapping its centre opens the
    // dashboard (the keybind works as usual).
    Item {
        id: focusDashTrigger
        x:       (root.width - root.cWidth) / 2
        y:       0
        width:   root.cWidth
        height:  Math.max(1, root.borderWidth)
        enabled: ShellState.focusMode
        TapHandler { onTapped: Popups.toggle("dashboard", root.screenName) }
    }

    // ── Input mask: only the visible frame takes clicks ──────────────────────
    SurfaceInputMask {
        id: inputMask
        surface:    root
        triggers:   triggers
        recOptions: recOptions
    }
    mask: inputMask.region
}
