import QtQuick
import QtQuick.Effects
import "../../"

// NotchMusicItem — the player's round cover art (or ♪) and the cava bars.

Item {
    id: root

    property string artUrl: ""

    readonly property int artSize: 20
    readonly property int artPad:  7

    Item {
        x: root.artPad
        anchors.verticalCenter: parent.verticalCenter
        width:  root.artSize
        height: root.artSize

        Rectangle {
            anchors.fill: parent
            radius:       width / 2
            color:        Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38)
            border.width: 1
            visible:      root.artUrl === ""
            Text { anchors.centerIn: parent; text: "♪"; font.pixelSize: 9; color: Theme.active }
        }

        Rectangle {
            id: artMask
            anchors.fill:  parent
            radius:        width / 2
            visible:       false
            layer.enabled: true
        }

        Image {
            anchors.fill: parent
            source:       root.artUrl
            fillMode:     Image.PreserveAspectCrop
            smooth:       true
            cache:        true
            visible:      root.artUrl !== ""
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled:      true
                maskSource:       artMask
                maskThresholdMin: 0.5
                maskSpreadAtMin:  1.0
            }
        }
    }

    CavaBars {
        id: bars
        visible: CavaService.enabled
        anchors {
            left: parent.left; leftMargin: root.artPad + root.artSize + 5
            right: parent.right; rightMargin: 5
            top: parent.top; bottom: parent.bottom
        }
        bars:       CavaService.bars
        barWidth:   5
        barSpacing: Math.max(1, (width - barWidth * CavaService.barCount) / Math.max(1, CavaService.barCount - 1))
    }
}
