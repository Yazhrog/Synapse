import QtQuick
import "../../"

// KanbanTaskCard — one task: inline-editable title, urgency and due badges,
// the expandable urgency / due-date fields, ← → move and delete buttons,
// swipe to move (with tilt and tint) and the delete-confirm overlay.

Item {
    id: card

    // The KanbanBoard: delete confirm, moves (with their entry animation),
    // the due-date picker.
    required property Item board
    property var taskData
    property int colIdx

    property bool showExtra: false
    property real xEntry:    0
    property real dragX:     0

    height: cardBg.implicitHeight + 2

    transform: [
        Translate { x: card.dragX + card.xEntry },
        // 3D Tilt: card physically tilts in the direction you drag it
        Rotation {
            origin.x: card.width / 2; origin.y: card.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: (card.dragX / 65.0) * -12
            Behavior on angle { SpringAnimation { spring: 2.5; damping: 0.3 } }
        }
    ]

    // Lift Effect: card scales down slightly when grabbed
    scale: dragHandler.active ? 0.94 : 1.0
    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

    // Fluid Column Jumps: smooth gliding instead of teleporting
    Behavior on x { SpringAnimation { spring: 2.0; damping: 0.25 } }
    Behavior on y { SpringAnimation { spring: 2.0; damping: 0.25 } }

    // ── Entry animation ────────────────────────────────────────────────────
    // New cards: no x offset (draft gives enough visual feedback).
    // Moved cards: appear at ±36px in move direction, spring to 0.
    Component.onCompleted: {
        var id = card.taskData.id
        if (card.board.newCardIds[id]) {
            delete card.board.newCardIds[id]
            // No extra animation — draft open/close is the creation affordance
        } else if (card.board.entryDirections[id] !== undefined) {
            var dir = card.board.entryDirections[id]
            delete card.board.entryDirections[id]
            // dir=1 (moved right) → xEntry=+36 (card overshoots right, bounces left to 0)
            // dir=-1 (moved left) → xEntry=-36 (card overshoots left, bounces right to 0)
            card.xEntry = dir * 36
            xSpringAnim.restart()
        }
    }

    // Spring to 0 with OutBack rubber-band feel
    NumberAnimation {
        id: xSpringAnim
        target:           card; property: "xEntry"; to: 0
        duration:         400
        easing.type:      Easing.OutBack
        easing.overshoot: 1.6
    }

    // ── Swipe to move ─────────────────────────────────────────────────────
    DragHandler {
        id: dragHandler
        target: null
        xAxis.enabled: true; yAxis.enabled: false; dragThreshold: 12
        
        onActiveChanged: {
            if (!active) {
                var d = card.dragX; snapAnim.start()
                var dir = d > 0 ? 1 : -1
                if (Math.abs(d) > 50 && card.colIdx + dir >= 0 && card.colIdx + dir <= 2)
                    card.board.moveTask(card.taskData.id, dir)
            }
        }
        onTranslationChanged: {
            if (active) card.dragX = Math.max(-65, Math.min(65, translation.x))
        }
    }

    // Elastic Snap: wobbles slightly when snapping back to place
    NumberAnimation {
        id: snapAnim; target: card; property: "dragX"; to: 0
        duration: 600
        easing.type:      Easing.OutElastic
        easing.amplitude: 1.2
        easing.period:    0.6
    }

    // Dynamic Glow: stronger, smoother color tinting
    readonly property real dragAmt:  Math.abs(dragX) / 65.0
    readonly property color dragTint: {
        if (dragX >  2) return Qt.rgba(166/255, 227/255, 161/255, dragAmt * 0.35)
        if (dragX < -2) return Qt.rgba(243/255, 139/255, 168/255, dragAmt * 0.35)
        return "transparent"
    }

    // ── Card body ─────────────────────────────────────────────────────────
    Rectangle {
        id: cardBg
        width: parent.width; radius: 8
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: {
            var u = card.taskData.urgency
            if (u === "high")   return Qt.rgba(243/255, 139/255, 168/255, 0.45)
            if (u === "medium") return Qt.rgba(249/255, 226/255, 175/255, 0.35)
            if (u === "low")    return Qt.rgba(166/255, 227/255, 161/255, 0.35)
            return Qt.rgba(1, 1, 1, 0.10)
        }
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 150 } }
        implicitHeight: body.implicitHeight + 18

        // Drag direction tint
        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: card.dragTint
            Behavior on color { ColorAnimation { duration: 60 } }
        }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; top: parent.top; topMargin: 9 }
            spacing: 6

            // Title (inline edit)
            TextInput {
                width: parent.width
                text:           card.taskData.title
                color:          Theme.text; font.pixelSize: 12; font.weight: Font.Medium
                wrapMode:       TextInput.WordWrap
                selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                onEditingFinished: { var t = text.trim(); if (t !== "") KanbanService.patchTask(card.taskData.id, "title", t) }
            }

            // Badges row
            Row {
                visible: card.taskData.urgency !== "" || (card.taskData.dueDate || "") !== ""
                spacing: 6
                Rectangle {
                    visible: card.taskData.urgency !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: urgL.implicitWidth + 12; height: 16; radius: 8
                    color: KanbanService.urgColor(card.taskData.urgency); opacity: 0.85
                    Text { id: urgL; anchors.centerIn: parent; text: KanbanService.urgLabel(card.taskData.urgency); font.pixelSize: 9; font.weight: Font.Bold; color: "#1e1e2e" }
                }
                Row {
                    visible: (card.taskData.dueDate || "") !== ""
                    anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Text { text: "📅"; font.pixelSize: 9 }
                    Text { text: KanbanService.formatDue(card.taskData.dueDate || ""); font.pixelSize: 9; color: Qt.rgba(1,1,1,0.50) }
                }
            }

            // Expandable extra fields
            Column {
                visible: card.showExtra; width: parent.width; spacing: 6

                // Urgency picker
                Row {
                    spacing: 5
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Urgency"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                    Repeater {
                        model: ["", "low", "medium", "high"]
                        delegate: Rectangle {
                            required property string modelData
                            property bool sel: card.taskData.urgency === modelData
                            width: uT.implicitWidth + 12; height: 17; radius: 9
                            color: sel ? (modelData === "" ? Qt.rgba(1,1,1,0.15) : KanbanService.urgColor(modelData))
                                       : (uH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05))
                            border.color: Qt.rgba(1,1,1, sel ? 0.20 : 0.08); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                id: uT; anchors.centerIn: parent; font.pixelSize: 9
                                text: modelData === "" ? "None" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                color: (sel && modelData !== "") ? "#1e1e2e" : Qt.rgba(1,1,1,0.65)
                            }
                            HoverHandler { id: uH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: KanbanService.patchTask(card.taskData.id, "urgency", modelData) }
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
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                            : Qt.rgba(1,1,1,0.07)
                        border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            id: dueLbl; anchors.centerIn: parent; font.pixelSize: 9
                            text:  (card.taskData.dueDate || "") !== "" ? KanbanService.formatDue(card.taskData.dueDate) : "Set due date"
                            color: (card.taskData.dueDate || "") !== "" ? Theme.active : Qt.rgba(1,1,1,0.40)
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                        HoverHandler { id: dueBH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: card.board.openPicker(card.taskData.id) }
                    }

                    // Clear ✕
                    Rectangle {
                        visible: (card.taskData.dueDate || "") !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8
                        color: clrDH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: Qt.rgba(1,1,1,0.35) }
                        HoverHandler { id: clrDH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: KanbanService.patchTask(card.taskData.id, "dueDate", "") }
                    }
                }
            }

            // Action bar
            Item {
                width: parent.width; height: 22

                // ▾/▴ extra fields
                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 20; height: 20; radius: 5
                    color: optH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: card.showExtra ? "▴" : "▾"; font.pixelSize: 9; color: Qt.rgba(1,1,1, optH.hovered ? 0.70 : 0.30) }
                    HoverHandler { id: optH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: card.showExtra = !card.showExtra }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    // ← left
                    Rectangle {
                        visible: card.colIdx > 0
                        width: 20; height: 20; radius: 5
                        color: lH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 10; color: Qt.rgba(1,1,1, lH.hovered ? 0.80 : 0.40) }
                        HoverHandler { id: lH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: card.board.moveTask(card.taskData.id, -1) }
                    }

                    // → right
                    Rectangle {
                        visible: card.colIdx < 2
                        width: 20; height: 20; radius: 5
                        color: rH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10; color: Qt.rgba(1,1,1, rH.hovered ? 0.80 : 0.40) }
                        HoverHandler { id: rH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: card.board.moveTask(card.taskData.id, 1) }
                    }

                    // ✕ delete
                    Rectangle {
                        width: 20; height: 20; radius: 5
                        color: dH.hovered ? Qt.rgba(248/255,113/255,113/255,0.20) : Qt.rgba(1,1,1,0.04)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            anchors.centerIn: parent; text: "✕"; font.pixelSize: 10
                            color: Qt.rgba(248/255,113/255,113/255, dH.hovered ? 1.0 : 0.60)
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                        HoverHandler { id: dH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: card.board.delConfirmId = card.taskData.id }
                    }
                }
            }
        }
    }
}
