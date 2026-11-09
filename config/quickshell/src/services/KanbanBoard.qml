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
//   • Delete confirm: a dialog over the whole dashboard; Enter = confirm,
//     Esc = cancel; dashboard close cancels automatically.
//   • Keyboard: ↑ ↓ select a task in its column, ← → the next column with
//     tasks, Shift+← → move the selected task, Delete asks to delete it.

Item {
    id: root
    focus: true

    // ── Animation tracking ────────────────────────────────────────────────────
    // Plain objects — mutated in-place, no signal needed, checked once per card.
    property var newCardIds:      ({})   // id → true  (no entry animation)
    property var entryDirections: ({})   // id → dir   (x spring on column move)

    // ── Delete confirm ────────────────────────────────────────────────────────
    property int delConfirmId: -1   // task id with the dialog open, -1 = none

    // ── Keyboard selection ────────────────────────────────────────────────────
    property int selectedId: -1     // task highlighted by the arrow keys, -1 = none

    // Where the delete dialog is drawn (the whole dashboard); the board itself if unset.
    property Item overlayParent: null

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
        if (selectedId === id) {
            // Keep a selection in the same column: the next task, else the previous
            var t = KanbanService.task(id)
            var list = t ? tasksIn(t.column) : []
            var i = list.findIndex(function(x) { return x.id === id })
            var next = list[i + 1] || list[i - 1]
            selectedId = next ? next.id : -1
        }
        KanbanService.removeTask(id)
    }

    function tasksIn(col) {
        return KanbanService.tasks.filter(function(t) { return t.column === col })
    }

    // dy: ±1 within the column; dx: ±1 to the next column that has tasks,
    // keeping the row where possible. Nothing selected yet → the first task.
    function navigate(dx, dy) {
        var cols = [tasksIn(0), tasksIn(1), tasksIn(2)]
        var sel  = KanbanService.task(selectedId)
        if (!sel) {
            for (var c0 = 0; c0 < 3; c0++)
                if (cols[c0].length) { selectedId = cols[c0][0].id; return }
            return
        }
        var c = sel.column
        var i = cols[c].findIndex(function(t) { return t.id === sel.id })
        if (dy !== 0) {
            var ni = i + dy
            if (ni >= 0 && ni < cols[c].length) selectedId = cols[c][ni].id
            return
        }
        for (var nc = c + dx; nc >= 0 && nc <= 2; nc += dx) {
            if (cols[nc].length) {
                selectedId = cols[nc][Math.min(i, cols[nc].length - 1)].id
                return
            }
        }
    }

    Keys.onPressed: function(ev) {
        // Delete dialog open: Enter confirms, Esc cancels, nothing else
        if (delConfirmId >= 0) {
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) removeTask(delConfirmId)
            else if (ev.key === Qt.Key_Escape) delConfirmId = -1
            ev.accepted = true
            return
        }
        // Date picker open: Esc closes it
        if (datePicker.pickerTaskId >= 0) {
            if (ev.key === Qt.Key_Escape) { datePicker.close(); ev.accepted = true }
            return
        }
        var shift = ev.modifiers & Qt.ShiftModifier
        switch (ev.key) {
        case Qt.Key_Up:    navigate(0, -1); break
        case Qt.Key_Down:  navigate(0,  1); break
        case Qt.Key_Left:
            if (shift) { if (selectedId >= 0) moveTask(selectedId, -1) } else navigate(-1, 0)
            break
        case Qt.Key_Right:
            if (shift) { if (selectedId >= 0) moveTask(selectedId, 1) } else navigate(1, 0)
            break
        case Qt.Key_Delete:
            if (KanbanService.task(selectedId)) delConfirmId = selectedId
            break
        default:
            return
        }
        ev.accepted = true
    }

    function openPicker(taskId) { datePicker.open(taskId) }

    // Config → Data & Storage → Clear task board
    Connections {
        target: KanbanService
        function onCleared() {
            root.delConfirmId = -1
            root.selectedId   = -1
            datePicker.close()
        }
    }

    // ── Reset state when dashboard closes ─────────────────────────────────────
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) {
                root.delConfirmId = -1
                root.selectedId   = -1
                datePicker.close()
            }
        }
    }

    // The dialog lives outside the board: cancel it when leaving the Tasks tab.
    // Shown: take the keyboard for the arrows and Delete.
    onVisibleChanged: {
        if (visible) forceActiveFocus()
        else delConfirmId = -1
    }

    // The dialog's Enter / Esc reach the board (e.g. after a click on ✕).
    onDelConfirmIdChanged: {
        if (delConfirmId >= 0) forceActiveFocus()
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

    // ── Delete confirm dialog (dims the whole dashboard while open) ──────────
    KanbanDeleteDialog {
        parent:       root.overlayParent || root
        anchors.fill: parent
        z:            40
        taskId:       root.delConfirmId
        onConfirmed:  root.removeTask(root.delConfirmId)
        onCancelled:  root.delConfirmId = -1
    }

    // ── Due-date picker (dims the board while open) ───────────────────────────
    KanbanDatePicker {
        id: datePicker
        anchors.fill: parent
        z: 29
    }
}
