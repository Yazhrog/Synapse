import QtQuick
import QtQuick.Effects
import "../../"
import "../../services"

// WallpaperCard — one wallpaper in the strip: rounded thumbnail and name,
// wider with an accent ring while previewed, a faint ring if current.
// The picker decides what a click does (preview, then apply).

Item {
    id:                      cardDelegate
    required property string modelData
    required property int    index
    // Height of the strip the card sits in
    property real stripHeight: 0
    property bool isPreview: WallpaperService.previewWall === modelData
    property bool isCurrent: WallpaperService.currentWall === modelData
    readonly property int labelH: 30

    signal clicked()

    width:  isPreview ? (130 * 1.2) : 130
    height: isPreview ? stripHeight : stripHeight - 14
    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.InOutCubic } }

    Item {
        id:           cardContent
        anchors.fill: parent
        visible:      false

        Image {
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            height:        parent.height - cardDelegate.labelH
            source:        modelData.indexOf("://") !== -1 ? modelData : "file://" + modelData
            fillMode:      Image.PreserveAspectCrop
            asynchronous:  true
            cache:         true
        }

        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            height: cardDelegate.labelH
            color: isPreview
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                : Qt.rgba(1,1,1,0.09)

            Text {
                anchors.centerIn: parent
                width:               parent.width - 10
                text:                modelData.split("/").pop().replace(/\.[^/.]+$/, "")
                color:               isPreview ? Theme.active : Qt.rgba(1,1,1,0.65)
                font.pixelSize:      10
                font.weight:         isPreview ? Font.Medium : Font.Normal
                elide:               Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Rectangle {
        id: cardMask
        anchors.fill: parent
        radius: 10
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        source: cardContent
        anchors.fill: parent
        maskEnabled: true
        maskSource: cardMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "transparent"
        border.width: isPreview ? 2 : 1
        border.color: isPreview ? Theme.active
            : isCurrent ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
            : Qt.rgba(1,1,1,0.15)
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on border.width { NumberAnimation  { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked:    cardDelegate.clicked()
    }
}
