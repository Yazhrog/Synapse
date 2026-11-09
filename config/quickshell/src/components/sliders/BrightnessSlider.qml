import QtQuick
import "../../"

// BrightnessSlider — the dashboard's labelled brightness slider
// (BRIGHTNESS + %, sun icons, track with thumb, click/drag/scroll).
// Reads and writes BrightnessService.

Item {
    id: root
    height: 52

    Text {
        id: brightLbl
        anchors { left: parent.left; top: parent.top }
        text: "BRIGHTNESS"; font.pixelSize: 9; font.weight: Font.Bold
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
    }
    Text {
        anchors { right: parent.right; top: parent.top }
        text: Math.round(BrightnessService.value * 100) + "%"
        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
    }

    Row {
        anchors { left: parent.left; right: parent.right; top: brightLbl.bottom; topMargin: 8 }
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃞"; font.pixelSize: 13
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
        }

        Item {
            id: btw
            width: parent.width - 13 - 13 - parent.spacing * 2
            height: 30; anchors.verticalCenter: parent.verticalCenter
            readonly property int thumbD: 14

            Rectangle {
                id: btrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 5; radius: height / 2
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.radius * 2, parent.width * BrightnessService.value)
                    radius: parent.radius; color: Theme.active
                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    function _c(mx) {
                        return Math.max(0.0, Math.min(1.0,
                            (mx - btw.thumbD/2) / (btrack.width - btw.thumbD)))
                    }
                    onPressed:         BrightnessService.set(_c(mouseX))
                    onPositionChanged: if (pressed) BrightnessService.set(_c(mouseX))
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) {
                    BrightnessService.set(BrightnessService.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
            Rectangle {
                width: btw.thumbD; height: btw.thumbD; radius: btw.thumbD / 2
                color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(btw.width - width, BrightnessService.value * (btw.width - width)))
                Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃠"; font.pixelSize: 13
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.75)
        }
    }
}
