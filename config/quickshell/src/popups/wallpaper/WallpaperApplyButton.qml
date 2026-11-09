import QtQuick
import "../../"
import "../../services"

// WallpaperApplyButton — "Apply", grows in while there is something to
// apply (`active`); shows … while WallpaperService is applying.

Rectangle {
    id: applyBtn
    property bool active: false
    signal clicked()
    width:                  active ? 90 : 0
    height:                 32
    radius:                 8
    opacity:                active ? 1 : 0
    clip:                   true
    color: applyBtnMA.containsMouse
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
    border.color: applyBtnMA.containsMouse
        ? Theme.active
        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
    border.width: 1
    Behavior on width        { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity      { NumberAnimation { duration: 160 } }
    Behavior on color        { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }
    Text {
        anchors.centerIn: parent
        text:             WallpaperService.applying ? "…" : "Apply"
        font.pixelSize:   12
        font.weight:      Font.Medium 
        color:            Theme.active
        opacity:          applyBtn.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
    MouseArea {
        id:           applyBtnMA
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        enabled:      applyBtn.active && !WallpaperService.applying
        onClicked:    applyBtn.clicked()
    }
}
