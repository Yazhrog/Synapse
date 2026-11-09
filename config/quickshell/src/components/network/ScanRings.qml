import QtQuick
import "../../"

// ScanRings — expanding rings around a pulsing glyph while `running`
// (the Wi-Fi and Bluetooth scans).

Item {
    id: ringsRoot
    property bool   running:     false
    property string centerGlyph: "󰤨"
    property int    glyphSize:   18
    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            anchors.centerIn: parent
            width: ringsRoot.width; height: ringsRoot.width; radius: ringsRoot.width / 2
            color: "transparent"
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.80)
            border.width: 1.5; opacity: 0; scale: 0.08
            SequentialAnimation {
                running: ringsRoot.running; loops: Animation.Infinite
                PauseAnimation { duration: index * 650 }
                ParallelAnimation {
                    NumberAnimation { property: "scale";   from: 0.08; to: 1.0; duration: 2200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0.80; to: 0.0; duration: 2200; easing.type: Easing.OutQuad  }
                }
            }
        }
    }
    Text {
        anchors.centerIn: parent; text: ringsRoot.centerGlyph; font.pixelSize: ringsRoot.glyphSize
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
        SequentialAnimation on opacity {
            running: ringsRoot.running; loops: Animation.Infinite
            NumberAnimation { to: 0.20; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.80; duration: 700; easing.type: Easing.InOutSine }
        }
    }
}
