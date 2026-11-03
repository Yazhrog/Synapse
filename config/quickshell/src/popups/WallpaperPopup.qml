import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Layouts
import "../shapes"
import "../components"
import "../services"
import "../"

PanelWindow {
    id: root

    anchors.top:    true
    anchors.left:   true
    anchors.right:  true
    anchors.bottom: true

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (windowVisible && Popups.wallpaperOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int panelWidth:  980
    readonly property int panelHeight: 420
    readonly property int fw:          Theme.notchRadius
    readonly property int fh:          Theme.notchRadius

    property var hostScreen: null

    property bool windowVisible: false
    visible: windowVisible

    // ── Self-hover tracking ───────────────────────────────────────────────────
    property bool selfHovered: true
    
    property bool allowHover: false

    // ── Hover close timer ─────────────────────────────────────────────────────
    // Fires when both the trigger region and the popup itself are no longer hovered.
    Timer {
        id: hoverCloseTimer
        interval: Popups.hoverCloseDelay
        onTriggered: {
            if (root.allowHover && !Popups.wallpaperTriggerHovered && !root.selfHovered)
                Popups.close("wallpaper")
        }
    }

    onSelfHoveredChanged: {
        if (root.allowHover) {
            if (!selfHovered && !Popups.wallpaperTriggerHovered) hoverCloseTimer.restart()
            else                                                  hoverCloseTimer.stop()
        }
    }

    PopupFocusGrab {
        window:       root
        screen:       root.hostScreen
        active:       Popups.wallpaperOpen
        onFocused:    wallpaperContent.focusSearch()
        onDismissed:  Popups.close("wallpaper")
    }

    Connections {
        target: Popups
        function onWallpaperTriggerHoveredChanged() {
            if (Popups.wallpaperTriggerHovered) {
                if (root.allowHover) {
                    hoverCloseTimer.stop()
                    if (!Popups.wallpaperOpen) {
                        closeTimer.stop()
                        root.windowVisible           = true
                        Popups.open("wallpaper")
                    }
                }
            } else {
                if (root.allowHover && !root.selfHovered) hoverCloseTimer.restart()
            }
        }

        function onWallpaperOpenChanged() {
            if (Popups.wallpaperOpen) {
                closeTimer.stop()
                hoverCloseTimer.stop()
                root.windowVisible           = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: { if (!Popups.wallpaperOpen) root.windowVisible = false }
    }

    MouseArea {
        anchors.fill: parent
        onClicked:    Popups.close("wallpaper")
    }

    Item {
        id: sizer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     Theme.borderWidth
        clip: true

        width:  Popups.wallpaperOpen ? root.panelWidth + 2 * root.fw : Theme.cNotchMinWidth + 2 * root.fw
        height: Popups.wallpaperOpen ? root.panelHeight : 0

        Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

        HoverHandler {
            onHoveredChanged: root.selfHovered = hovered
        }

        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "bottom"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        WallpaperContent {
            id: wallpaperContent
            anchors.fill: parent
            open: Popups.wallpaperOpen
            fw:   root.fw
            fh:   root.fh
        }
    }
}
