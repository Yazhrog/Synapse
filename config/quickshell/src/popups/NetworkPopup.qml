import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../"

PanelWindow {
    id: root

    readonly property int popupWidth:  Theme.networkPopupWidth   // 480
    readonly property int popupHeight: 648
    readonly property int fw:          Theme.notchRadius
    readonly property int fh:          Theme.notchRadius

    property string page: Popups.networkPage

    anchors.right: true
    anchors.top:   true

    // Window height = popup content only — sizer starts at y:0
    implicitWidth:  popupWidth + fw
    implicitHeight: popupHeight

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Mask tracks sizer — limits input region to visible content only
    mask: Region { item: maskProxy }

    Item {
        id: maskProxy
        x:      root.implicitWidth - sizer.width
        y:      0
        width:  sizer.width
        height: sizer.height
    }

    // ── Visibility gate ───────────────────────────────────────────────────────
    property var hostScreen: null

    property bool windowVisible: false
    visible: windowVisible

    // sizer owns the Escape handler; tab inputs (Wi-Fi password, BT PIN,
    // hotspot) take focus from it themselves once the grab is live.
    PopupFocusGrab {
        window:       root
        screen:       root.hostScreen
        active:       Popups.networkOpen
        onFocused:    sizer.forceActiveFocus()
        onDismissed:  Popups.close("network")
    }

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen) {
                closeTimer.stop()
                root.windowVisible = true
                // Use requested page if set, otherwise default to wifi
                root.page = (Popups.networkPage && Popups.networkPage !== "")
                    ? Popups.networkPage : "wifi"
            } else {
                closeTimer.restart()
            }
        }

        function onNetworkPageChanged() {
            root.page = Popups.networkPage
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: { if (!Popups.networkOpen) root.windowVisible = false }
    }

    // ── Sizer — clip container, grows downward from y:0 ──────────────────────
    Item {
        id: sizer
        anchors.right: parent.right
        anchors.rightMargin: Theme.borderWidth
        y: 0
        clip: true

        width: Popups.networkOpen
               ? root.popupWidth + 9
               : Theme.rNotchMinWidth + root.fw

        height: Popups.networkOpen ? root.popupHeight : 0

        Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "right"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }
        
        Keys.onEscapePressed: Popups.close("network")

        Item {
            id: contentArea
            anchors {
                fill:         parent
                topMargin:    Theme.notchHeight
                leftMargin:   root.fw
                rightMargin:  root.fw/2
                bottomMargin: root.fh + Theme.cornerRadius
            }

            opacity: Popups.networkOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.networkOpen
                        ? Theme.animDuration * 0.5
                        : Theme.animDuration * 0.15
                }
            }

            NetworkContent {
                anchors.fill: parent
                page:         root.page
            }
        }
    }
}
