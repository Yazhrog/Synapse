import QtQuick
import "../../"

// KanbanDeleteDialog — a delete confirmation centred over whatever it fills:
// the whole dashboard for one task ("Delete task?"), a single column for
// "Clear" ("Delete N tasks?"). Shown while `shown`; a click around the box
// cancels. Enter / Esc are handled by the board. It draws no dim of its own
// (a black layer showed as a box on a translucent frame): the content behind
// it fades instead (KanbanBoard.modalOpen, DashboardContent's tab bar).

Item {
    id: root

    property bool   shown:   false
    property string heading: "Delete task?"
    property string detail:  ""
    signal confirmed()
    signal cancelled()

    visible: shown

    // Click catcher — swallows clicks around the box and cancels
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    Rectangle {
        anchors.centerIn: parent
        width:  Math.min(root.width - 16, Math.max(230, col.implicitWidth + 32))
        height: col.implicitHeight + 28
        radius: Theme.cornerRadius
        color: Qt.rgba(
            Math.min(1, Theme.background.r + 0.06),
            Math.min(1, Theme.background.g + 0.06),
            Math.min(1, Theme.background.b + 0.06), 0.98)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1

        // Swallow clicks so they don't reach the dim below
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.centerIn: parent; spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.heading; color: Theme.text; font.pixelSize: 12; font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width - 64, 260)
                visible: text !== ""
                text: root.detail
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: 11; color: Qt.rgba(1,1,1,0.50)
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                Rectangle {
                    width: 64; height: 24; radius: 6
                    color: cnH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.60) }
                    HoverHandler { id: cnH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
                }
                Rectangle {
                    width: 64; height: 24; radius: 6
                    color: cfH.hovered ? "#cc3a3a" : "#993030"
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 11; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: cfH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.confirmed() }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "↵ confirm · ⎋ cancel"; font.pixelSize: 9
                color: Qt.rgba(1,1,1,0.20)
            }
        }
    }
}
