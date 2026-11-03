import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../modules/Center/"
import '../services/'
import "../"

// Dashboard — PanelWindow required for TextInput keyboard focus on Wayland.
// Keyboard focus comes from PopupFocusGrab; WlrKeyboardFocus.Exclusive is kept
// so the layer surface accepts key events once it has focus.
//
// Positioning mirrors the original PopupWindow behaviour: the sizer's top sits
// exactly at the notch-bar bottom (topMargin: Theme.notchHeight), so there is
// no vertical offset compared to the PopupWindow version.

PanelWindow {
    id: root

    // Kept so existing instantiation sites that pass anchorWindow: … still compile.
    required property var anchorWindow
    property var hostScreen: null

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    color:   "transparent"
    visible: windowVisible

    anchors.top:   true
    anchors.left:  true
    anchors.right: true
    anchors.bottom: true

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    // Exclusive focus only when fully open and visible.
    WlrLayershell.keyboardFocus: (windowVisible && Popups.dashboardOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool windowVisible: false

    PopupFocusGrab {
        window:       root
        screen:       root.hostScreen
        active:       Popups.dashboardOpen
        onFocused:    dashboardContent.focusPage()
        onDismissed:  Popups.close("dashboard")
    }

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }

    }

    Timer {
        id: closeTimer
        interval: root.animDuration + 20
        onTriggered: {
            root.windowVisible = false
            dashboardContent.reset()
        }
    }

    // ── Backdrop — closes popup when clicking outside the sizer ──────────────
    MouseArea {
        anchors.fill: parent
        onClicked:    Popups.close("dashboard")
    }

    // ── Sizer ─────────────────────────────────────────────────────────────────
    // topMargin: Theme.notchHeight places the sizer top exactly at the notch
    // bottom — identical to where PopupWindow put it. No fh subtraction, which
    // was the source of the vertical offset in the text-working variant.
    Item {
        id: sizer
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  Popups.dashboardOpen ? Popups.dashboardPageWidth + 2 * root.fw : Theme.cNotchMinWidth + 2 * root.fw
        height: Popups.dashboardOpen ? Theme.dashboardHeight : Theme.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        
        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        // ── Background ────────────────────────────────────────────────────────
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        // ── Content ───────────────────────────────────────────────────────────
        Item {
            id: content
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            opacity: Popups.dashboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.dashboardOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            DashboardContent {
                id: dashboardContent
                anchors.fill: parent
            }
        }
    }
}
