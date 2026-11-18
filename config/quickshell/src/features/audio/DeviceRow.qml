import QtQuick
import qs.src.theme
// DeviceRow — one device of the mixer page; the default one is highlighted.
Item {
    id: row
    implicitHeight: 28

    property string label:     ""
    property bool   isDefault: false
    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius - 4
        color:  row.isDefault
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                    : (rowHov.hovered ? Qt.rgba(1,1,1,0.05) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: row.isDefault ? Theme.active : Qt.rgba(1,1,1,0.2)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text:           row.label
            color:          row.isDefault ? Theme.text : Qt.rgba(1,1,1,0.5)
            font.pixelSize: 11
            elide:          Text.ElideRight
            width:          parent.width - 14 - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: row.clicked() }
}
