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

    // Interactive popups hosted by the surface (#41).
    readonly property var hostedContents: ["powerMenu", "audio", "notifications", "network",
                                           "clipboard", "wallpaper", "dashboard"]
    readonly property bool hostedOpen: hostedContents.indexOf(openContent) >= 0
    // The screen-recording setup (bar carousel) also wants Escape to cancel it.
    readonly property bool recSetup: ShellState.screenRecord && !ScreenRecService.recording
    readonly property bool wantsKeyboard: hostedOpen || (recSetup && _focusedHere)

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

    // The dashboard grows the center notch to its page width (like TopBar).
    property int cWidth: openContent === "dashboard"
        ? px(Popups.dashboardPageWidth)
        : Math.max(px(Theme.cNotchMinWidth),
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

    // Right region size: network and notifications grow the right notch;
    // otherwise a toast does.
    readonly property int networkWidth:  px(Theme.networkPopupWidth + 9) + borderWidth
    readonly property int networkBottom: px(648 - Theme.notchRadius)
    readonly property int notifWidth:    px(Theme.notificationsWidth + Theme.notchRadius) + borderWidth

    property real _rGrow: openContent === "network"       ? networkWidth
                        : openContent === "notifications" ? notifWidth
                        : toastShown                      ? toastWidth : 0
    Behavior on _rGrow { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    property real _rDrop: openContent === "network"       ? networkBottom - notchBottom
                        : openContent === "notifications" ? notifList.height + px(2 * Theme.popupPadding + 4)
                        : toastShown                      ? toastCard.implicitHeight + px(26) : 0
    Behavior on _rDrop { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    // Quick Controls OSD: right-center region, on the focused monitor, unless
    // an interactive popup (audio, #41) owns that region.
    // Also opens while the right-border trigger (or the OSD itself) is hovered.
    readonly property bool quickShown: ((Popups.quickOpen && _focusedHere) || _quickHoverOpen)
                                       && openRegion !== "rightCenter"
    readonly property int  quickDepth:  px(180)
    readonly property int  quickHeight: px(340 - 2 * Theme.cornerRadius)

    // Right-center region: the audio popup (width follows its page) or the OSD.
    readonly property var audioPageWidths: ({ output: 200, input: 200, mixer: 300 })
    readonly property int audioWidth: px(audioPageWidths[audioControl.page] ?? 300)

    property real rightCenterDepth: openContent === "audio" ? audioWidth
                                  : quickShown              ? quickDepth : 0
    Behavior on rightCenterDepth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    // Top region: the dashboard drops the center notch to its height.
    readonly property int dashboardBottom: px(Theme.dashboardHeight)
    property real _cDrop: openContent === "dashboard" ? dashboardBottom - notchBottom : 0
    Behavior on _cDrop { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    readonly property real centerBottom: notchBottom + _cDrop

    // Bottom regions: wallpaper (bottom-center) and clipboard (bottom-right).
    readonly property int wallpaperWidth:  px(980)
    readonly property int wallpaperHeight: px(420)
    readonly property int clipboardWidth:  px(420)
    readonly property int clipboardHeight: px(560)

    property real bottomCenterWidth:  openContent === "wallpaper" ? wallpaperWidth  : 0
    property real bottomCenterHeight: openContent === "wallpaper" ? wallpaperHeight : 0
    property real bottomRightWidth:   openContent === "clipboard" ? clipboardWidth  : 0
    property real bottomRightHeight:  openContent === "clipboard" ? clipboardHeight : 0
    Behavior on bottomCenterWidth  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    Behavior on bottomCenterHeight { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    Behavior on bottomRightWidth   { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
    Behavior on bottomRightHeight  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    // Left-center region: the power menu.
    readonly property int powerWidth:  px(216)
    readonly property int powerHeight: px(258)
    property real leftCenterDepth: openContent === "powerMenu" ? powerWidth + px(12) : 0
    Behavior on leftCenterDepth { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // ── Click shield (#42) ───────────────────────────────────────────────────
    // While a popup is open (on any screen, like the legacy PopupDismiss), the
    // whole surface takes clicks and a click outside the open popup and the
    // bar closes it. It sits below everything else, so the popups and the bar
    // still get their own clicks first.
    readonly property bool shieldActive: SurfaceState.anyOpen || recSetup

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

    function _insideFrameOrPopup(x, y) {
        if (y < root.notchBottom || x < root.borderWidth || x > root.width - root.borderWidth
                || y > root.height - root.borderWidth)
            return true
        const regions = {
            powerMenu: powerRegion, audio: audioRegion, notifications: notifRegion,
            network: networkRegion, dashboard: dashboardRegion,
            wallpaper: wallpaperRegion, clipboard: clipboardRegion
        }
        if (recOptions.visible && x >= recOptions.x && x <= recOptions.x + recOptions.width
                && y >= recOptions.y && y <= recOptions.y + recOptions.height)
            return true
        const r = regions[root.openContent]
        return !!r && x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height
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
        rightBottom:  root.rightBottom
        rightCenterDepth:  root.rightCenterDepth
        rightCenterHeight: root.quickHeight
        leftCenterDepth:   root.leftCenterDepth
        leftCenterHeight:  root.powerHeight + px(12)
        centerBottom:      root.centerBottom
        bottomCenterWidth:  root.bottomCenterWidth
        bottomCenterHeight: root.bottomCenterHeight
        bottomRightWidth:   root.bottomRightWidth
        bottomRightHeight:  root.bottomRightHeight
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
                // The dashboard covers the notch while open.
                opacity: root.openContent === "dashboard" ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
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
        HoverHandler { id: quickHover; onHoveredChanged: Popups.quickHeld = hovered }

        QuickControlContent {
            x:        root.px(8)
            y:        root.px(30)
            width:    root.quickDepth - root.px(16)
            height:   parent.height - root.px(30)
            fastPoll: root.quickShown
        }
    }

    // ── Interactive popups (#41) ─────────────────────────────────────────────
    // Each content sits in a clip Item that follows its region's animated size,
    // so it appears to grow out of the frame, and fades with its content flag.
    // The scope gets keyboard focus while one is open (wantsKeyboard); Escape
    // closes the popup from anywhere inside.
    FocusScope {
        id: popupScope
        anchors.fill: parent
        Keys.onEscapePressed: {
            Popups.closeAll()
            if (root.recSetup) ScreenRecService.cancelSetup()
        }

        // Power menu — left-center
        Item {
            id: powerRegion
            x:      root.borderWidth
            y:      (root.height - root.powerHeight - root.px(12)) / 2
            width:  root.leftCenterDepth
            height: root.powerHeight + root.px(12)
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "powerMenu" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Item {
                x: root.px(4); y: root.px(6)
                width: root.powerWidth; height: root.powerHeight
                PowerMenu { id: powerMenu }
            }
        }

        // Audio — right-center (shares the region with the OSD)
        Item {
            id: audioRegion
            x:      root.width - root.borderWidth - root.rightCenterDepth
            y:      (root.height - root.quickHeight) / 2
            width:  root.rightCenterDepth
            height: root.quickHeight
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "audio" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            AudioControl {
                id: audioControl
                x: root.px(10); y: root.px(6)
                width:  root.audioWidth - root.px(16)
                height: parent.height - root.px(12)
            }

            // Back to the default page once the close animation is done.
            Timer {
                id: audioResetTimer
                interval: Theme.animDuration + 20
                onTriggered: audioControl.reset()
            }
            Connections {
                target: Popups
                function onAudioOpenChanged() {
                    if (!Popups.audioOpen) audioResetTimer.restart()
                    else audioControl.page = Popups.audioPage
                }
            }
        }

        // Notifications — right notch, below the bar
        Item {
            id: notifRegion
            x:      root.width - root.rWidth
            y:      root.notchHeight
            width:  root.rWidth - root.borderWidth
            height: Math.max(0, root.rightBottom - root.notchHeight)
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "notifications" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            NotificationList {
                id: notifList
                x:     root.px(Theme.notchRadius + 4)
                y:     root.px(4)
                width: root.notifWidth - root.borderWidth - root.px(Theme.notchRadius + 8)
            }
        }

        // Network — right notch, below the bar
        Item {
            id: networkRegion
            x:      root.width - root.rWidth
            y:      root.notchHeight
            width:  root.rWidth - root.borderWidth
            height: Math.max(0, root.rightBottom - root.notchHeight)
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "network" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            NetworkContent {
                x:      root.px(Theme.notchRadius)
                width:  root.networkWidth - root.borderWidth - root.px(Theme.notchRadius) - root.px(7)
                height: root.networkBottom - root.notchHeight - root.px(Theme.cornerRadius)
                page:   Popups.networkPage || "wifi"
            }
        }
    }

    // ── Second half of the interactive popups ────────────────────────────────
    Item {
        anchors.fill: parent

        // Dashboard — the center notch, grown down
        Item {
            id: dashboardRegion
            x:      (root.width - root.cWidth) / 2
            y:      0
            width:  root.cWidth
            height: root.centerBottom
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "dashboard" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            DashboardContent {
                id: dashboardContent
                x:      root.px(8)
                y:      root.px(Theme.notchRadius + 8)
                width:  root.px(Popups.dashboardPageWidth) - root.px(16)
                height: root.dashboardBottom - root.px(Theme.notchRadius + 16)
            }
        }

        // Wallpaper — bottom-center panel
        Item {
            id: wallpaperRegion
            x:      (root.width - root.bottomCenterWidth) / 2 - root.notchRadius
            y:      root.height - root.borderWidth - root.bottomCenterHeight
            width:  root.bottomCenterWidth + 2 * root.notchRadius
            height: root.bottomCenterHeight
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "wallpaper" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            WallpaperContent {
                id: wallpaperContent
                anchors.horizontalCenter: parent.horizontalCenter
                y:      0
                width:  root.wallpaperWidth + 2 * root.notchRadius
                height: root.wallpaperHeight
                fw:     root.notchRadius
                fh:     root.notchRadius
                open:   root.openContent === "wallpaper"
            }
        }

        // Clipboard — bottom-right panel
        Item {
            id: clipboardRegion
            x:      root.width - root.borderWidth - root.bottomRightWidth
            y:      root.height - root.borderWidth - root.bottomRightHeight
            width:  root.bottomRightWidth
            height: root.bottomRightHeight
            clip:   true
            visible: opacity > 0
            opacity: root.openContent === "clipboard" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            FocusScope {
                id: clipboardScope
                x:      root.px(10)
                y:      root.px(8)
                width:  root.clipboardWidth - root.px(10)
                height: root.clipboardHeight - root.px(16)
                Keys.onEscapePressed: Popups.close("clipboard")
                HistoryTab { anchors.fill: parent }
            }
        }
    }

    // Reset the dashboard tabs once its close animation is done.
    Timer {
        id: dashboardResetTimer
        interval: Theme.animDuration + 20
        onTriggered: dashboardContent.reset()
    }
    Connections {
        target: Popups
        function onDashboardOpenChanged() { if (!Popups.dashboardOpen) dashboardResetTimer.restart() }
    }

    // Hand the keyboard to the opened popup once the compositor has given it
    // to the surface.
    onOpenContentChanged: if (hostedOpen) focusTimer.restart()
    onWantsKeyboardChanged: if (wantsKeyboard && !hostedOpen) focusTimer.restart()
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            switch (root.openContent) {
            case "powerMenu": powerMenu.reset(); break
            case "dashboard": dashboardContent.focusPage(); break
            case "wallpaper": wallpaperContent.focusSearch(); break
            case "clipboard": clipboardScope.forceActiveFocus(); break
            default:          popupScope.forceActiveFocus()
            }
        }
    }

    // ── Border triggers (#42), same zones as the legacy Border windows ───────
    // Each zone is one corner radius deep, so it's easy to hit at the screen
    // edge. Flags are kept on Popups for the legacy popups and future
    // per-popup hover settings.
    readonly property int _triggerDepth: cornerRadius

    // Left border middle: hover flag only (the power menu opens on click).
    Item {
        id: leftTrigger
        x: 0; y: (root.height - height) / 2
        width: root._triggerDepth; height: root.px(300)
        HoverHandler { onHoveredChanged: Popups.archMenuTriggerHovered = hovered }
    }

    // Right border middle: hovering shows the Quick Controls OSD.
    Item {
        id: rightTrigger
        x: root.width - width; y: (root.height - height) / 2
        width: root._triggerDepth; height: root.px(300)
        HoverHandler {
            id: rightTriggerHover
            onHoveredChanged: {
                Popups.quickTriggerHovered = hovered
                Popups.audioTriggerHovered = hovered
            }
        }
    }

    // Bottom border centre: tap toggles the wallpaper picker.
    Item {
        id: bottomTrigger
        x: (root.width - width) / 2; y: root.height - height
        width: root.px(420); height: root._triggerDepth
        HoverHandler { onHoveredChanged: Popups.wallpaperTriggerHovered = hovered }
        TapHandler   { onTapped: Popups.toggle("wallpaper", root.screenName) }
    }

    // Bottom-right corner: tap toggles the clipboard.
    Item {
        id: cornerTrigger
        x: root.width - width; y: root.height - height
        width: root.px(80); height: root._triggerDepth
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
        visible: ScreenRecService.openStrip !== "" && root._focusedHere

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

    Item { id: maskTop;    x: 0; y: 0; width: root.width; height: root._edge }
    Item { id: maskLeft;   x: 0; y: 0; width: root._edge; height: root.height }
    Item { id: maskRight;  x: root.width - root._edge; y: 0; width: root._edge; height: root.height }
    Item { id: maskBottom; x: 0; y: root.height - root._edge; width: root.width; height: root._edge }
    Item { id: maskRecOptions; x: recOptions.x; y: recOptions.y
           width: recOptions.visible ? recOptions.width : 0; height: recOptions.visible ? recOptions.height : 0 }
    Item { id: maskShield; x: 0; y: 0; width: root.shieldActive ? root.width : 0; height: root.shieldActive ? root.height : 0 }
    Item { id: maskLeftNotch;   x: leftNotch.x;   y: 0; width: leftNotch.width;   height: root.notchBottom }
    Item { id: maskCenterNotch; x: centerNotch.x; y: 0; width: centerNotch.width; height: root.centerBottom }
    Item { id: maskRightNotch;  x: rightNotch.x;  y: 0; width: rightNotch.width;  height: root.rightBottom }
    Item { id: maskQuick; x: quickRegion.x; y: quickRegion.y; width: quickRegion.width; height: quickRegion.height }
    Item { id: maskPower; x: powerRegion.x; y: powerRegion.y; width: powerRegion.width; height: powerRegion.height }
    Item { id: maskWallpaper; x: wallpaperRegion.x; y: wallpaperRegion.y; width: wallpaperRegion.width; height: wallpaperRegion.height }
    Item { id: maskClipboard; x: clipboardRegion.x; y: clipboardRegion.y; width: clipboardRegion.width; height: clipboardRegion.height }

    mask: Region {
        Region { item: maskTop;         intersection: Intersection.Combine }
        Region { item: maskLeft;        intersection: Intersection.Combine }
        Region { item: maskRight;       intersection: Intersection.Combine }
        Region { item: maskBottom;      intersection: Intersection.Combine }
        Region { item: maskLeftNotch;   intersection: Intersection.Combine }
        Region { item: maskCenterNotch; intersection: Intersection.Combine }
        Region { item: maskRightNotch;  intersection: Intersection.Combine }
        Region { item: maskQuick;       intersection: Intersection.Combine }
        Region { item: maskPower;       intersection: Intersection.Combine }
        Region { item: maskWallpaper;   intersection: Intersection.Combine }
        Region { item: maskClipboard;   intersection: Intersection.Combine }
        Region { item: leftTrigger;     intersection: Intersection.Combine }
        Region { item: rightTrigger;    intersection: Intersection.Combine }
        Region { item: bottomTrigger;   intersection: Intersection.Combine }
        Region { item: cornerTrigger;   intersection: Intersection.Combine }
        Region { item: maskShield;      intersection: Intersection.Combine }
        Region { item: maskRecOptions;  intersection: Intersection.Combine }
    }
}
