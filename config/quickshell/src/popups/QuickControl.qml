import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../shapes"
import "../components"
import "../services"
import "../"

PopupWindow {
    id: root

    required property var anchorWindow

    // ── Config ────────────────────────────────────────────────────────────────
    readonly property int fw: Theme.cornerRadius
    readonly property int fh: Theme.cornerRadius
    readonly property int popupHeight: 340
    readonly property int popupWidth:  180 // Thinner than the 300px AudioPopup

    color:   "transparent"
    visible: slide.windowVisible
    mask:    Region { item: maskProxy }

    // ── Position: Right Center ────────────────────────────────────────────────
    anchor.window:  anchorWindow
    anchor.rect: Qt.rect(
        anchorWindow.width - root.fw,
        (root.screen.height + root.fh + 5)/2,
        0,
        0
    )
    anchor.gravity: Edges.Right
    
    Item {
        id:      maskProxy
        x:       root.popupWidth - sizer.width
        y:       ((root.popupHeight - sizer.height) / 2) - root.fh
        width:   sizer.width
        height:  sizer.height
    }

    implicitWidth:  popupWidth
    implicitHeight: popupHeight

    // ── Layout ────────────────────────────────────────────────────────────────
    PopupSlide {
        id: slide
        anchors.fill:     parent
        edge:             "right"
        open:             Popups.quickOpen 
        hoverEnabled:     true
        triggerHovered:   Popups.quickTriggerHovered 
        onCloseRequested: Popups.hideQuick()

        Item {
            id: sizer
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            width:  root.popupWidth
            height: root.popupHeight

            Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

            PopupShape {
                id: bg
                anchors.fill: parent
                attachedEdge: "right"
                color:        Theme.background
                radius:       Theme.cornerRadius
                flareWidth:   root.fw
                flareHeight:  root.fh
            }

            QuickControlContent {
                anchors {
                    fill:        parent
                    topMargin:   root.fh + 30
                    leftMargin:  8
                    rightMargin: 8
                }
                fastPoll: root.visible
            }
        }
    }
}
