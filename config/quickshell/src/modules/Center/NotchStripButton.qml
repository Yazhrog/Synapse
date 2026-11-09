import QtQuick
import Quickshell
import "../../"

// NotchStripButton — a record-setup pill (capture mode, audio source).
// Hovering opens its option strip under the notch (ScreenRecService);
// leaving schedules it to close.

Item {
    id: root

    property string strip: ""      // "capture" | "audio"
    property string icon:  ""
    property string label: ""
    // Emoji icons keep their own colours
    property bool   tintIcon: true

    readonly property bool open: ScreenRecService.openStrip === strip

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width:  row.implicitWidth + 14
    height: 22

    Rectangle {
        anchors.fill: parent
        radius:       height / 2
        color: root.open
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
            : hov.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
        border.color: root.open
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.3)
            : Qt.rgba(1,1,1,0.1)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Text {
            text: root.icon
            font.pixelSize: root.tintIcon ? 13 : 12
            color: root.open ? Theme.active : Qt.rgba(1,1,1,0.7)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            text: root.label
            font.pixelSize: 11
            color: root.open ? Theme.active : Qt.rgba(1,1,1,0.7)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            text: "▾"; font.pixelSize: 8
            color: Qt.rgba(1,1,1,0.35)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hov
        onHoveredChanged: {
            if (hovered) {
                var pos = root.mapToItem(null, 0, 0)
                ScreenRecService.popupTargetX      = pos.x
                ScreenRecService.popupTargetScreen = QsWindow.window?.screen?.name ?? ""
                ScreenRecService.popupTargetWidth  = root.width
                ScreenRecService.openStrip = root.strip
                ScreenRecService.keepStripOpen()
            } else {
                ScreenRecService.scheduleStripClose()
            }
        }
    }
}
