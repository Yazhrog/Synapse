import QtQuick
import qs.src.theme
// BrightnessSlider — the dashboard's labelled brightness slider
// (BRIGHTNESS + %, sun icons, track with thumb, click/drag/scroll).
// Presentational: shows `value` (0–1) and reports moved(v); Quick Settings
// binds it to the brightness service.

Item {
    id: root
    height: 52

    property real value: 0
    signal moved(real value)

    Text {
        id: brightLbl
        anchors { left: parent.left; top: parent.top }
        text: "BRIGHTNESS"; font.pixelSize: 9; font.weight: Font.Bold
        color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.55)
    }
    Text {
        anchors { right: parent.right; top: parent.top }
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; font.weight: Font.Bold
        color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.7)
    }

    Row {
        anchors { left: parent.left; right: parent.right; top: brightLbl.bottom; topMargin: 8 }
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃞"; font.pixelSize: 13
            color: Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.35)
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
                color: Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.12)
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(parent.radius * 2, parent.width * root.value)
                    radius: parent.radius; color: Theme.color.accent
                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    function _c(mx) {
                        return Math.max(0.0, Math.min(1.0,
                            (mx - btw.thumbD/2) / (btrack.width - btw.thumbD)))
                    }
                    onPressed:         root.moved(_c(mouseX))
                    onPositionChanged: if (pressed) root.moved(_c(mouseX))
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(e) {
                    root.moved(root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
            Rectangle {
                width: btw.thumbD; height: btw.thumbD; radius: btw.thumbD / 2
                color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(btw.width - width, root.value * (btw.width - width)))
                Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰃠"; font.pixelSize: 13
            color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.75)
        }
    }
}
