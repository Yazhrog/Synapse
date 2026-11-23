import QtQuick
import qs.src.services.data
import qs.src.theme
// TaskExtraFields — a TaskCard's expandable fields: the urgency chips and
// the due date (opens the board's picker; ✕ clears it).
Column {
    id: fields
    property var taskData: ({ id: -1, urgency: "", dueDate: "" })
    signal dueDateRequested()

    spacing: 6

    // Urgency picker
    Row {
        spacing: 5
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Urgency"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
        Repeater {
            model: ["", "low", "medium", "high"]
            delegate: Rectangle {
                required property string modelData
                property bool sel: fields.taskData.urgency === modelData
                width: uT.implicitWidth + 12; height: 17; radius: 9
                color: sel ? (modelData === "" ? Qt.rgba(1,1,1,0.15) : TaskService.urgColor(modelData))
                           : (uH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05))
                border.color: Qt.rgba(1,1,1, sel ? 0.20 : 0.08); border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text {
                    id: uT; anchors.centerIn: parent; font.pixelSize: 9
                    text: modelData === "" ? "None" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    color: (sel && modelData !== "") ? "#1e1e2e" : Qt.rgba(1,1,1,0.65)
                }
                HoverHandler { id: uH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: TaskService.patchTask(fields.taskData.id, "urgency", modelData) }
            }
        }
    }

    // Due date button row
    Row {
        spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter; text: "Due"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width:  dueLbl.implicitWidth + 20; height: 20; radius: 10
            color: dueBH.hovered
                ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.15)
                : Qt.rgba(1,1,1,0.07)
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Behavior on color { ColorAnimation { duration: 80 } }
            Text {
                id: dueLbl; anchors.centerIn: parent; font.pixelSize: 9
                text:  (fields.taskData.dueDate || "") !== "" ? TaskService.formatDue(fields.taskData.dueDate) : "Set due date"
                color: (fields.taskData.dueDate || "") !== "" ? Theme.color.accent : Qt.rgba(1,1,1,0.40)
                Behavior on color { ColorAnimation { duration: 80 } }
            }
            HoverHandler { id: dueBH; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: fields.dueDateRequested() }
        }

        // Clear ✕
        Rectangle {
            visible: (fields.taskData.dueDate || "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16; radius: 8
            color: clrDH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
            Behavior on color { ColorAnimation { duration: 80 } }
            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: Qt.rgba(1,1,1,0.35) }
            HoverHandler { id: clrDH; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: TaskService.patchTask(fields.taskData.id, "dueDate", "") }
        }
    }
}
