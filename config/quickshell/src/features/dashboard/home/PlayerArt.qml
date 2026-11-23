import QtQuick
import QtQuick.Effects
import qs.src.theme
// PlayerArt — PlayerCard's background: the cover art blurred and darkened
// towards the bottom, clipped to the card's rounded corners.
Item {
    id: art
    property string artUrl: ""

    Item {
        id: bgSource
        anchors.fill:  parent
        opacity:       0
        layer.enabled: true

        Item {
            id: artSource
            anchors.fill:  parent
            layer.enabled: true
            Image {
                anchors.fill: parent
                source:   art.artUrl
                fillMode: Image.PreserveAspectCrop
                smooth:   true
            }
        }

        MultiEffect {
            source:       artSource
            anchors.fill: parent
            visible:      art.artUrl !== ""
            opacity:      art.artUrl !== "" ? 1 : 0
            blurEnabled:  true
            blur:         0.5
            blurMax:      32
            saturation:   0.2
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.38) }
                GradientStop { position: 0.4; color: Qt.rgba(0,0,0,0.50) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.88) }
            }
        }
    }

    Rectangle {
        id: bgMask
        anchors.fill:  parent
        radius:        Theme.radius.card
        visible:       false
        layer.enabled: true
    }

    MultiEffect {
        source:           bgSource
        anchors.fill:     parent
        maskEnabled:      true
        maskSource:       bgMask
        maskThresholdMin: 0.5
        maskSpreadAtMin:  1.0
    }
}
