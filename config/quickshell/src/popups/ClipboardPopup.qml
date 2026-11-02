import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../"

PanelWindow {
    id: root

    readonly property int popupWidth:  420
    readonly property int popupHeight: 560
    readonly property int fw: Theme.cornerRadius
    readonly property int fh: Theme.cornerRadius

    anchors.right:  true
    anchors.bottom: true

    implicitWidth:  popupWidth  + fw
    implicitHeight: popupHeight + fh

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x:      root.implicitWidth  - sizer.width
        y:      root.implicitHeight - sizer.height
        width:  sizer.width
        height: sizer.height
    }

    property var hostScreen: null

    property bool windowVisible: false
    visible: windowVisible

    PopupFocusGrab {
        window:       root
        screen:       root.hostScreen
        active:       Popups.clipboardOpen
        onFocused:    content.forceActiveFocus()
        onDismissed:  Popups.clipboardOpen = false
    }

    Connections {
        target: Popups
        function onClipboardOpenChanged() {
            if (Popups.clipboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: {
            if (!Popups.clipboardOpen)
                root.windowVisible = false
        }
    }
    
    Item {
        id: sizer
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Theme.borderWidth
        anchors.bottomMargin: Theme.borderWidth
        clip: true

        width:  Popups.clipboardOpen ? root.popupWidth  + root.fw : 0
        height: Popups.clipboardOpen ? root.popupHeight + root.fh : 0

        Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "bottom-right"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        // FocusScope so it can take focus from the grab and handle Escape —
        // PopupDismiss can't see keys while this popup holds the grab.
        FocusScope {
            id: content
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 10
                bottomMargin: 8
            }

            opacity: Popups.clipboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.clipboardOpen ? Theme.animDuration * 0.5 : Theme.animDuration * 0.15
                }
            }

            Keys.onEscapePressed: Popups.clipboardOpen = false

            HistoryTab { anchors.fill: parent }
        }
    }
}
