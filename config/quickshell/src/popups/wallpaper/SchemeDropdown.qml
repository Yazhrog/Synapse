import QtQuick
import QtQuick.Layouts
import "../../"
import "../../services"

// SchemeDropdown — the matugen colour-scheme menu that opens above the
// picker's scheme button; picking one sets WallpaperService.scheme.

Rectangle {
    id: schemeDropdown

    property bool open:       false
    // Placed just above this item (the scheme button), inside `bounds`
    property Item anchorItem: null
    property Item bounds:     parent

    signal closeRequested()

    visible: open
    clip:    false

    width:  schemeDropdownCol.implicitWidth + 32
    height: schemeDropdownCol.implicitHeight + 16
    radius: Theme.cornerRadius

    color:        Theme.background
    border.color: Theme.active
    border.width: 1

    opacity:            open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    onVisibleChanged: {
        if (visible) {
            var pos = anchorItem.mapToItem(bounds, 0, 0)
            x = Math.min(pos.x, bounds.width - width - 4)
            y = pos.y - height - 6
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked:    {}
    }

    ColumnLayout {
        id:               schemeDropdownCol
        anchors.centerIn: parent
        spacing:          4

        Repeater {
            model: WallpaperService.schemes
            delegate: Rectangle {
                id: schemeItem
                required property string modelData
                property bool sel: WallpaperService.scheme === modelData

                Layout.fillWidth: true
                // Pad minimumWidth to ensure space between text and rectangle edges
                Layout.minimumWidth: schemeItemText.implicitWidth + 40 
                Layout.preferredHeight: 32

                radius: 8
                color: schemeItemMA.containsMouse 
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14) 
                    : (sel ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : "transparent")

                border.color: (sel || schemeItemMA.containsMouse) 
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                    : "transparent"
                border.width: 1

                Behavior on color        { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    spacing: 10

                    Text {
                        text:                   sel ? "●" : "○"
                        font.pixelSize:         10
                        color:                  (sel || schemeItemMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.3)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id:                     schemeItemText
                        text:                   modelData
                        font.pixelSize:         13
                        color:                  (sel || schemeItemMA.containsMouse) ? Theme.text : Qt.rgba(1,1,1,0.65)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id:           schemeItemMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        WallpaperService.scheme = modelData
                        schemeDropdown.closeRequested()
                    }
                }
            }
        }
    }
}
