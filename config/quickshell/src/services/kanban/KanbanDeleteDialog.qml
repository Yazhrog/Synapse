import QtQuick
import "../../"

// KanbanDeleteDialog — "Delete task?" confirmation, centred over the whole
// dashboard with a dim behind it. Shown while `taskId` >= 0; a click on the
// dim cancels. Enter / Esc are handled by the board.

Item {
    id: root

    property int taskId: -1
    signal confirmed()
    signal cancelled()

    readonly property var _task: taskId >= 0 ? KanbanService.task(taskId) : null

    visible: taskId >= 0

    // Dim — swallows clicks and cancels
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
    }

    Rectangle {
        anchors.centerIn: parent
        width:  Math.max(230, col.implicitWidth + 32)
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
                text: "Delete task?"; color: Theme.text; font.pixelSize: 12; font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, 260)
                visible: text !== ""
                text: root._task ? root._task.title : ""
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
