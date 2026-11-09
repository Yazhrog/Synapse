import QtQuick
import "../../"

// QuickFilterPicker — the shader list that floats over the Quick Settings
// tiles: "Off" first, then every shader of ScreenFilterService.
// The parent opens it through `open` and closes it on closeRequested().

Rectangle {
    id: root

    property bool open: false
    signal closeRequested()

    visible: open
    z:       20

    // The picker takes the keyboard while it's shown, so Escape closes it
    // instead of the dashboard; `returnFocusTo` gets it back afterwards.
    property Item returnFocusTo: null
    onVisibleChanged: {
        if (visible) forceActiveFocus()
        else if (returnFocusTo) returnFocusTo.forceActiveFocus()
    }
    Keys.onEscapePressed: function(event) {
        root.closeRequested()
        event.accepted = true
    }

    width:  180
    // Fits "Off" + every shader row, capped at 280
    height: Math.min(280, pickerCol.implicitHeight + 16)
    radius: Theme.cornerRadius

    color: Qt.rgba(
        Math.min(1, Theme.background.r + 0.05),
        Math.min(1, Theme.background.g + 0.05),
        Math.min(1, Theme.background.b + 0.05),
        0.98)
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
    border.width: 1

    // Subtle entrance scale + fade
    opacity: open ? 1 : 0
    scale:   open ? 1 : 0.95
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    transformOrigin: Item.BottomRight

    // Swallow clicks so they don't fall through to the tiles below
    MouseArea { anchors.fill: parent; onClicked: {} }

    component ShaderRow: Rectangle {
        id: row
        required property string name     // "" = Off
        property bool isActive: ScreenFilterService.current === name

        width:  pickerCol.width
        height: 28
        radius: 6
        color: isActive
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
            : rowH.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                text:           row.isActive ? "●" : "○"
                font.pixelSize: 9
                color: row.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            Text {
                text:           row.name === "" ? "Off" : row.name
                font.pixelSize: 12
                color: row.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: row.name === "" ? implicitWidth : pickerCol.width - 38
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }
        HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                ScreenFilterService.apply(row.name)
                root.closeRequested()
            }
        }
    }

    Flickable {
        anchors { fill: parent; margins: 8 }
        contentWidth:   width
        contentHeight:  pickerCol.implicitHeight
        clip:           true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: pickerCol
            width: parent.width
            spacing: 2

            Text {
                width: parent.width
                text: "SHADER"
                font.pixelSize: 9; font.weight: Font.Bold
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                leftPadding: 4
                bottomPadding: 4
            }

            ShaderRow { name: "" }

            Rectangle {
                width: parent.width; height: 1
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
            }

            Repeater {
                model: ScreenFilterService.list
                delegate: ShaderRow {
                    required property string modelData
                    name: modelData
                }
            }

            // Shown while the list is still loading
            Text {
                width:   parent.width
                visible: ScreenFilterService.list.length === 0
                text:    "Loading…"
                font.pixelSize: 11
                color:   Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                horizontalAlignment: Text.AlignHCenter
                topPadding: 4
            }
        }
    }
}
