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
    readonly property var  _monitor: Hyprland.monitorFor(screen)
    readonly property bool fullscreenHere: !!(_monitor && _monitor.activeWorkspace
                                              && _monitor.activeWorkspace.hasFullscreen)
    readonly property bool showingSomething: openContent !== "none" || quickShown || toastShown
                                             || recOptions.visible
    readonly property bool frameHidden: fullscreenHere && !showingSomething

    Binding { target: root.contentItem; property: "opacity"; value: root.frameHidden ? 0 : 1 }

    // hasFullscreen is only refreshed with the workspace list.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen") Hyprland.refreshWorkspaces()
        }
    }

    // ── Resolution scaling ───────────────────────────────────────────────────
    // Every frame and region size is a Metrics value times localScale, rounded
    // to whole pixels (see SurfaceState.scaleFor; off by default, because the
    // hosted contents aren't scaled yet).
    readonly property real localScale: SurfaceState.scaleFor(screen)
    function px(v) { return Math.round(v * localScale) }

    readonly property int borderWidth:  px(Theme.borderWidth)
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
    readonly property bool quickShown: ((Popups.quickOpen && _focusedHere) || _quickHoverOpen)
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
        Math.min(px(Theme.lNotchMaxWidth), leftContent.implicitWidth + notchPadding * 2))

    property real cWidth: _topT[0] > 0 ? _topT[0]
        : Math.max(px(Theme.cNotchMinWidth),
                   Math.min(px(Theme.cNotchMaxWidth), centerContent.implicitWidth + notchPadding * 2))
    Behavior on cWidth { Anim {} }
    property real _cDrop: Math.max(0, _topT[1] - notchBottom)
    Behavior on _cDrop { Anim {} }
    readonly property real centerBottom: notchBottom + _cDrop

    // The right notch follows its content instantly; only a popup or the
    // toast morph it.
    readonly property int _rBase: Math.max(
        px(Theme.rNotchMinWidth),
        Math.min(px(Theme.rNotchMaxWidth), rightContent.implicitWidth + notchPadding * 2))
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

    MouseArea {
        id: clickShield
        anchors.fill:    parent
        enabled:         root.shieldActive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (root._insideFrameOrPopup(mouse.x, mouse.y)) return
            Popups.closeAll()
        }
    }

    function _inRect(r, x, y) {
        return x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height
    }

    function _insideFrameOrPopup(x, y) {
        if (x < borderWidth || x > width - borderWidth || y < borderWidth || y > height - borderWidth)
            return true
        if (_inRect(Qt.rect(0, 0, lWidth, notchBottom), x, y)
                || _inRect(Qt.rect((width - cWidth) / 2, 0, cWidth, centerBottom), x, y)
                || _inRect(Qt.rect(width - rWidth, 0, rWidth, rightBottom), x, y))
            return true
        if (recOptions.visible && _inRect(Qt.rect(recOptions.x, recOptions.y, recOptions.width, recOptions.height), x, y))
            return true
        return openSpec !== null && _inRect(regionRect(openSpec.region), x, y)
    }

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
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity { Anim {} }

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
                // The dashboard covers the notch while open.
                opacity: root.openRegion === "top" ? 0 : 1
                Behavior on opacity { Fade {} }
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
    // One clip item per content, following its region's animated rectangle
    // (so the content appears to grow out of the frame) and fading with its
    // content flag. Contents are created on this screen the first time they
    // open here, then kept. The scope gets keyboard focus while one is open;
    // Escape closes the popup from anywhere inside.
    property var _loaded: ({})
    property var _items:  ({})

    FocusScope {
        id: popupScope
        anchors.fill: parent
        Keys.onEscapePressed: {
            Popups.closeAll()
            if (root.recSetup) ScreenRecService.cancelSetup()
        }

        Repeater {
            model: root.contentKeys
            delegate: Item {
                id: regionClip
                required property string modelData
                readonly property var  spec: root.contents[modelData]
                readonly property rect r:    root.regionRect(spec.region)
                x: r.x; y: r.y; width: r.width; height: r.height
                clip:    true
                visible: opacity > 0
                opacity: root.openContent === modelData ? 1 : 0
                Behavior on opacity { Fade {} }

                Loader {
                    readonly property rect p: regionClip.spec.place(regionClip.width, regionClip.height)
                    x: p.x; y: p.y; width: p.width; height: p.height
                    active:          !!root._loaded[regionClip.modelData]
                    sourceComponent: regionClip.spec.component
                    onLoaded:        root._items[regionClip.modelData] = item
                }
            }
        }
    }

    // Hand the keyboard to the opened popup once the compositor has given it
    // to the surface, and clean up the previous one after its close animation.
    property string _lastContent: "none"
    onOpenContentChanged: {
        const prev = _lastContent
        _lastContent = openContent
        if (prev !== "none" && contents[prev] && contents[prev].afterClose) {
            afterCloseTimer.key = prev
            afterCloseTimer.restart()
        }
        // (openSpec may not be re-evaluated yet inside this handler.)
        if (!contents[openContent]) return
        if (!_loaded[openContent]) {
            const loaded = Object.assign({}, _loaded)
            loaded[openContent] = true
            _loaded = loaded
        }
        focusTimer.restart()
    }
    onWantsKeyboardChanged: if (wantsKeyboard && !openSpec) focusTimer.restart()

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            const spec = root.contents[root.openContent]
            const item = root._items[root.openContent]
            if (spec && item) spec.focus(item)
            else popupScope.forceActiveFocus()
        }
    }

    Timer {
        id: afterCloseTimer
        property string key: ""
        interval: Theme.animDuration + 20
        onTriggered: {
            const item = root._items[key]
            if (item && root.openContent !== key) root.contents[key].afterClose(item)
        }
    }

    // ── Border triggers (#42) ────────────────────────────────────────────────
    // Each zone is one corner radius deep, so it's easy to hit at the screen
    // edge.
    readonly property int _triggerDepth: cornerRadius

    // Right border middle: hovering shows the Quick Controls OSD.
    Item {
        id: rightTrigger
        x: root.width - width; y: (root.height - height) / 2
        width: root._triggerDepth; height: root.px(Metrics.sideTriggerLength)
        HoverHandler { id: rightTriggerHover }
    }

    // Bottom border centre: tap toggles the wallpaper picker.
    Item {
        id: bottomTrigger
        x: (root.width - width) / 2; y: root.height - height
        width: root.px(Metrics.bottomTriggerWidth); height: root._triggerDepth
        TapHandler   { onTapped: Popups.toggle("wallpaper", root.screenName) }
    }

    // Bottom-right corner: tap toggles the clipboard.
    Item {
        id: cornerTrigger
        x: root.width - width; y: root.height - height
        width: root.px(Metrics.cornerTriggerWidth); height: root._triggerDepth
        TapHandler { onTapped: Popups.toggle("clipboard", root.screenName) }
    }

    // Hover-open of the OSD: opens at once on the trigger, closes after
    // Popups.hoverCloseDelay once neither the trigger nor the OSD is hovered.
    property bool _quickHoverOpen: false
    readonly property bool _quickHovered: rightTriggerHover.hovered || quickHover.hovered
    on_QuickHoveredChanged: {
        if (_quickHovered) {
            quickHoverCloseTimer.stop()
            if (rightTriggerHover.hovered) _quickHoverOpen = true
        } else if (_quickHoverOpen) {
            quickHoverCloseTimer.restart()
        }
    }
    Timer {
        id: quickHoverCloseTimer
        interval: Popups.hoverCloseDelay
        onTriggered: if (!root._quickHovered) root._quickHoverOpen = false
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
    readonly property int _edge: Math.max(1, borderWidth)

    component RegionMask: Item {
        property rect r
        x: r.x; y: r.y; width: r.width; height: r.height
    }

    Item { id: maskTop;    x: 0; y: 0; width: root.width; height: root._edge }
    Item { id: maskLeft;   x: 0; y: 0; width: root._edge; height: root.height }
    Item { id: maskRight;  x: root.width - root._edge; y: 0; width: root._edge; height: root.height }
    Item { id: maskBottom; x: 0; y: root.height - root._edge; width: root.width; height: root._edge }
    Item { id: maskLeftNotch;   x: 0; y: 0; width: root.lWidth; height: root.notchBottom }
    Item { id: maskCenterNotch; x: (root.width - root.cWidth) / 2; y: 0; width: root.cWidth; height: root.centerBottom }
    Item { id: maskRightNotch;  x: root.width - root.rWidth; y: 0; width: root.rWidth; height: root.rightBottom }
    RegionMask { id: maskLeftCenter; r: root.regionRect("leftCenter") }
    RegionMask { id: maskRightCenter; r: root.regionRect("rightCenter") }
    RegionMask { id: maskBottomCenter; r: root.regionRect("bottomCenter") }
    RegionMask { id: maskBottomRight; r: root.regionRect("bottomRight") }
    Item { id: maskRecOptions; x: recOptions.x; y: recOptions.y
           width: recOptions.visible ? recOptions.width : 0; height: recOptions.visible ? recOptions.height : 0 }
    Item { id: maskShield;  width: root.shieldActive ? root.width : 0; height: root.shieldActive ? root.height : 0 }
    Item { id: maskVisible; width: root.frameHidden ? 0 : root.width; height: root.frameHidden ? 0 : root.height }

    mask: Region {
        Region { item: maskTop;          intersection: Intersection.Combine }
        Region { item: maskLeft;         intersection: Intersection.Combine }
        Region { item: maskRight;        intersection: Intersection.Combine }
        Region { item: maskBottom;       intersection: Intersection.Combine }
        Region { item: maskLeftNotch;    intersection: Intersection.Combine }
        Region { item: maskCenterNotch;  intersection: Intersection.Combine }
        Region { item: maskRightNotch;   intersection: Intersection.Combine }
        Region { item: maskLeftCenter;   intersection: Intersection.Combine }
        Region { item: maskRightCenter;  intersection: Intersection.Combine }
        Region { item: maskBottomCenter; intersection: Intersection.Combine }
        Region { item: maskBottomRight;  intersection: Intersection.Combine }
        Region { item: rightTrigger;     intersection: Intersection.Combine }
        Region { item: bottomTrigger;    intersection: Intersection.Combine }
        Region { item: cornerTrigger;    intersection: Intersection.Combine }
        Region { item: maskShield;       intersection: Intersection.Combine }
        Region { item: maskRecOptions;   intersection: Intersection.Combine }
        // Hidden over a fullscreen window: take no input at all.
        Region { item: maskVisible;      intersection: Intersection.Intersect }
    }
}
