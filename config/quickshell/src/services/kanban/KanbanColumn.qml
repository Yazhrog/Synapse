import QtQuick
import "../../"

// KanbanColumn — one board column: header (name, task count, + button),
// the draft card for a new task (saved on Enter or focus loss with text)
// and the scrollable task list.

Item {
    id: colItem

    required property Item   board
    required property int    cIdx
    required property string cLabel
    readonly property var    cTasks: {
        var ci = cIdx
        return KanbanService.tasks.filter(function(t) { return t.column === ci })
    }

    property bool draftOpen: false

    Rectangle {
        anchors.fill: parent; radius: Theme.cornerRadius
        color:        Qt.rgba(1, 1, 1, 0.03)
        border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1
    }

    Column {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // Header
        Item {
            width: parent.width; height: 26

            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: colItem.cLabel; color: Theme.active
                    font.pixelSize: 12; font.weight: Font.DemiBold
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: cntT.implicitWidth + 10; height: 16; radius: 8
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                    Text {
                        id: cntT; anchors.centerIn: parent
                        text: colItem.cTasks.length
                        color: Theme.active; font.pixelSize: 9; font.weight: Font.Bold
                    }
                }
            }

            // Add (+) button
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 22; height: 22; radius: 6
                color: addH.hovered
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                    : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "+"; color: Theme.active; font.pixelSize: 15 }
                HoverHandler { id: addH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { colItem.draftOpen = true; draftTimer.restart() }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

        Timer {
            id: draftTimer; interval: 50
            onTriggered: if (colItem.draftOpen) draftInput.forceActiveFocus()
        }

        // Content area
        Item {
            width:  parent.width
            height: parent.height - 26 - 1 - parent.spacing * 2

            // Draft card — slides in from top
            Item {
                id: draftWrap; z: 2; width: parent.width
                height: colItem.draftOpen ? draftRect.implicitHeight + 6 : 0
                clip:   true
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: draftRect
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 3 }
                    radius: 8
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.06)
                    border.color: draftInput.activeFocus
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50)
                        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                    border.width: 1
                    implicitHeight: draftInput.contentHeight + 24
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        visible: draftInput.text === ""
                        text: "Task title…"; color: Qt.rgba(1,1,1,0.25); font.pixelSize: 12
                    }

                    TextInput {
                        id: draftInput
                        anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        color: Theme.text; font.pixelSize: 12
                        wrapMode: TextInput.WordWrap
                        selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)

                        function commit() {
                            var t = text.trim()
                            if (t !== "") colItem.board.addTask(colItem.cIdx, t)
                            colItem.draftOpen = false; text = ""
                            colItem.board.forceActiveFocus()
                        }

                        Keys.onReturnPressed: function(ev) { commit(); ev.accepted = true }
                        Keys.onEscapePressed: function(ev) { colItem.draftOpen = false; text = ""; ev.accepted = true; colItem.board.forceActiveFocus() }
                        onActiveFocusChanged: if (!activeFocus && colItem.draftOpen) commit()
                    }
                }
            }

            // Task list
            Flickable {
                anchors.top:       draftWrap.bottom
                anchors.left:      parent.left
                anchors.right:     parent.right
                anchors.topMargin: colItem.draftOpen ? 4 : 0
                height:            parent.height - draftWrap.height - (colItem.draftOpen ? 4 : 0)
                contentWidth:      width
                contentHeight:     taskCol.implicitHeight + 4
                clip:              true
                boundsBehavior:    Flickable.StopAtBounds

                Column {
                    id: taskCol
                    width: parent.width; spacing: 6

                    Repeater {
                        model: colItem.cTasks
                        delegate: KanbanTaskCard {
                            required property var modelData
                            board:    colItem.board
                            width:    parent.width
                            taskData: modelData
                            colIdx:   colItem.cIdx
                        }
                    }
                }
            }
        }
    }
}
