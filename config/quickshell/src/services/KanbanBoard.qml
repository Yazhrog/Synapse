import QtQuick
import "../"
import "../components"
import "kanban"

// KanbanBoard — the dashboard's task board: three columns over KanbanService
// (user_data/tasks.json).
//
// Key behaviours:
//   • Draft: task only saved when Enter pressed or focus lost with text.
//   • Arrow move: card appears in new column offset by ±dir*36px, springs
//     to 0 with OutBack overshoot (rubber-band feel).
//   • Due date: mini calendar + optional time picker, both optional.
//     Time-only → today's date prepended automatically.
//   • Delete confirm: Enter = confirm, Esc = cancel; only active when overlay
//     is showing; dashboard close cancels automatically.

Item {
    id: root
    focus: true

    // ── Animation tracking ────────────────────────────────────────────────────
    // Plain objects — mutated in-place, no signal needed, checked once per card.
    property var newCardIds:      ({})   // id → true  (no entry animation)
    property var entryDirections: ({})   // id → dir   (x spring on column move)

    // ── Delete confirm ────────────────────────────────────────────────────────
    property int delConfirmId: -1   // task id with overlay open, -1 = none

    // ── Actions used by the columns and cards ─────────────────────────────────
    function addTask(col, title) {
        // Recorded before the model changes, so the new card can read it
        newCardIds[KanbanService.nextId] = true
        KanbanService.addTask(col, title)
    }

    function moveTask(id, dir) {
        var t = KanbanService.task(id)
        if (!t || t.column + dir < 0 || t.column + dir > 2) return
        entryDirections[id] = dir
        KanbanService.moveTask(id, dir)
    }

    function removeTask(id) {
        if (delConfirmId === id) delConfirmId = -1
        KanbanService.removeTask(id)
    }

    function openPicker(taskId) { datePicker.open(taskId) }

    // Config → Data & Storage → Clear task board
    Connections {
        target: KanbanService
        function onCleared() {
            root.delConfirmId = -1
            datePicker.close()
        }
    }

    // ── Reset state when dashboard closes ─────────────────────────────────────
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) {
                root.delConfirmId = -1
                datePicker.close()
            }
        }
    }

    // ── Delete keyboard handler ───────────────────────────────────────────────
    // Grabs focus when delete confirm opens; Enter = delete, Esc = cancel.
    Item {
        id: deleteKeyHandler
        Keys.onReturnPressed: function(ev) {
            if (root.delConfirmId >= 0) {
                root.removeTask(root.delConfirmId)
                ev.accepted = true
            }
        }
        Keys.onEscapePressed: function(ev) {
            if (root.delConfirmId >= 0) {
                root.delConfirmId = -1
                ev.accepted = true
            }
        }
    }

    onDelConfirmIdChanged: {
        if (delConfirmId >= 0) deleteKeyHandler.forceActiveFocus()
    }

    // ── Columns ───────────────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 8

        Repeater {
            model: [
                { idx: 0, label: "To Do"   },
                { idx: 1, label: "Ongoing" },
                { idx: 2, label: "Done"    }
            ]
            delegate: KanbanColumn {
                required property var modelData
                board:  root
                cIdx:   modelData.idx
                cLabel: modelData.label
                width:  (mainRow.width - mainRow.spacing * 2) / 3
                height: mainRow.height
            }
        }
    }

    // ── Due-date picker (dims the board while open) ───────────────────────────
    KanbanDatePicker {
        id: datePicker
        anchors.fill: parent
        z: 29
    }
}
