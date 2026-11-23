import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.src.components.feedback
import qs.src.services.media
import qs.src.state
import qs.src.surface.shape
import qs.src.theme
// DynamicSurface — one fullscreen, transparent layer surface per screen that
// draws the whole frame (top notches + borders) as a single morphing shape
// and hosts everything on it: the bar, the interactive popups (each grows a
// region of the frame), the passive content (notification toast, Quick
// Controls OSD), the click shield and the border triggers (#37).
//
// The popups and the passive parts come from app/PopupManifest.qml
// (`manifest`): a popup's PopupSpec gives its region, size, placement, focus
// and content, so adding one never edits this file. The frame geometry is in
// Regions.qml, the popup loaders in SurfacePopupHost.qml.
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

    // app/PopupManifest.qml: popups (PopupSpec list), osd, recordingOptions
    required property var manifest
    // features/bar/BarWidgets.qml's widgets (BarWidgetSpec list)
    property var barWidgets: []

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
    readonly property var    openSpec: specs[openContent] ?? null
    readonly property var    openItem: popupScope.items[openContent] ?? null

    // The screen-recording setup (bar carousel) also wants Escape to cancel it.
    readonly property bool recSetup:      ShellModes.screenRecord && !ScreenRecService.recording
    readonly property bool wantsKeyboard: openSpec !== null || (recSetup && _focusedHere)

    // ── Fullscreen ───────────────────────────────────────────────────────────
    SurfaceFullscreen { id: fullscreen; screen: root.screen }
    readonly property bool fullscreenHere: fullscreen.active
    readonly property bool showingSomething: openContent !== "none" || quickShown || toastShown
                                             || recOptions.visible
    readonly property bool frameHidden: fullscreenHere && !showingSomething

    Binding { target: root.contentItem; property: "opacity"; value: root.frameHidden ? 0 : 1 }

    // ── Resolution scaling ───────────────────────────────────────────────────
    // Every frame and region size is a Theme.frame value times localScale, rounded
    // to whole pixels (see SurfaceState.scaleFor; off by default, because the
    // hosted contents aren't scaled yet).
    readonly property real localScale: SurfaceState.scaleFor(screen)
    function px(v) { return Math.round(v * localScale) }

    // Bar style (Config → Appearance): frame, bar or pills. borderWidth is the
    // frame's border; there are no borders in bar, and in pills it's the gap
    // between the floating shapes and the screen edges, so every region rect
    // and placement below works unchanged in the three styles.
    readonly property string barStyle: Theme.frame.barStyle
    readonly property bool   framed:   barStyle === "frame"
    readonly property bool   pills:    barStyle === "pills"
    readonly property int borderWidth:  framed ? px(Theme.frame.borderWidth)
                                        : pills ? px(Theme.frame.pillGap) : 0
    readonly property int notchHeight:  px(Theme.frame.notchHeight)
    readonly property int notchRadius:  px(Theme.radius.notch)
    readonly property int cornerRadius: px(Theme.radius.card)
    readonly property int notchPadding: px(Theme.frame.notchPadding)

    // ── Interactive popups (app/PopupManifest.qml) ──────────────────────────
    readonly property var popups: manifest ? manifest.popups : []
    readonly property var specs: {
        const m = {}
        for (let i = 0; i < popups.length; i++) m[popups[i].key] = popups[i]
        return m
    }

    // ── Passive content (#40) ────────────────────────────────────────────────
    // Notification toast: grows the right notch on the screen it was shown on.
    readonly property bool toastShown: ToastState.isOn(screenName) && ToastState.showing
                                       && openRegion !== "right" && regions.toastFits
    readonly property int  toastWidth: px(Theme.frame.notificationToastWidth + Theme.radius.notch + Theme.frame.toastNotchExtra)

    // Quick Controls OSD: right-center region, on the focused monitor or while
    // its border trigger is hovered, unless a popup owns that region.
    readonly property bool quickShown: ((Popups.quickOpen && _focusedHere) || triggers.quickHoverOpen)
                                       && openRegion !== "rightCenter" && regions.quickFits
    readonly property int  quickWidth:  px(Theme.frame.osdWidth)
    readonly property int  sideHeight:  px(Theme.frame.sideRegionHeight)
    readonly property real toastHeight: toastCard.implicitHeight

    // ── Frame geometry (Regions.qml) ─────────────────────────────────────────
    readonly property real barLeftWidth:   bar.leftContentWidth
    readonly property real barCenterWidth: bar.centerContentWidth
    readonly property real barRightWidth:  bar.rightContentWidth

    Regions { id: regions; surface: root }

    readonly property alias notchBottom:        regions.notchBottom
    readonly property alias lWidth:             regions.lWidth
    readonly property alias cWidth:             regions.cWidth
    readonly property alias centerBottom:       regions.centerBottom
    readonly property alias rWidth:             regions.rWidth
    readonly property alias rightBottom:        regions.rightBottom
    readonly property alias leftCenterDepth:    regions.leftCenterDepth
    readonly property alias leftCenterHeight:   regions.leftCenterHeight
    readonly property alias rightCenterDepth:   regions.rightCenterDepth
    readonly property alias rightCenterHeight:  regions.rightCenterHeight
    readonly property alias bottomCenterWidth:  regions.bottomCenterWidth
    readonly property alias bottomCenterHeight: regions.bottomCenterHeight
    readonly property alias bottomRightWidth:   regions.bottomRightWidth
    readonly property alias bottomRightHeight:  regions.bottomRightHeight

    // Current (animated) rectangle of a region, in surface coordinates.
    function regionRect(region) { return regions.rect(region) }

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
        widgets:      root.barWidgets
    }

    // ── Toast, inside the grown right notch ──────────────────────────────────
    ToastCard {
        id: toastCard
        notification: ToastState.current
        showing:      ToastState.showing
        duration:     ToastState.duration
        onDismissRequested: ToastState.dismiss()
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

        // Hovering keeps the OSD open (see IpcBridge's hide timer).
        HoverHandler { id: quickHover; onHoveredChanged: Popups.quickHeld = hovered }

        Loader {
            id:     osdLoader
            x:      root.px(8)
            y:      root.px(Theme.frame.osdTopPadding)
            width:  root.quickWidth - root.px(16)
            height: parent.height - root.px(Theme.frame.osdTopPadding)
            sourceComponent: root.manifest ? root.manifest.osd : null
            Binding { target: osdLoader.item; property: "fastPoll"; value: root.quickShown; when: osdLoader.item !== null }
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
    Loader {
        id: recOptions
        // Hangs just under the bar, aligned with the button that opened it
        // (like the other dropdowns), one pill gap below the notch.
        x:       Math.min(ScreenRecService.popupTargetX, root.width - width - root.px(Theme.frame.pillGap))
        y:       root.notchBottom + root.px(Theme.frame.pillGap)
        width:   item ? item.implicitWidth : 0
        height:  item ? item.implicitHeight : 0
        visible: ScreenRecService.openStrip !== "" && ScreenRecService.popupTargetScreen === root.screenName
        sourceComponent: root.manifest ? root.manifest.recordingOptions : null

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
        enabled: ShellModes.focusMode
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
