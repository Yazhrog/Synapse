import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components"
import "../services"
import "../"

// ScreenRecOptionsPopup — minimal dropdown under the center notch.
//
// No checkboxes, no radio dots. Selection shown by background highlight only.
// Window sized exactly to content — no mask, no dead space.

PopupWindow {
    id: root

    required property var anchorWindow

    implicitWidth:  options.implicitWidth
    implicitHeight: options.implicitHeight

    anchor.window:     root.anchorWindow
    anchor.gravity:    Edges.Bottom
    anchor.adjustment: PopupAdjustment.None
    anchor.rect: Qt.rect(
       ScreenRecService.popupTargetX + (ScreenRecService.popupTargetWidth / 2),
        25,
        root.implicitWidth,
        Theme.notchHeight
    )

    color:   "transparent"
    visible: ScreenRecService.openStrip !== ""

    HoverHandler {
        onHoveredChanged: {
            if (hovered) ScreenRecService.keepStripOpen()
            else         ScreenRecService.scheduleStripClose()
        }
    }

    ScreenRecOptions {
        id: options
        anchors.fill: parent
    }
}
