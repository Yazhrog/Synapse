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
//   • Clear column: the header's "Clear" dims that column with "Delete N
//     tasks?"; Enter = confirm, Esc / click outside = cancel.
//   • Keyboard: ← → focus a column, ↑ ↓ select a task in it, Shift+← → move
//     the selected task, + adds a task to the focused column, Delete asks to
//     delete the selected one.

Item {
    id: root
    focus: true

    // ── Animation tracking ────────────────────────────────────────────────────
    // Plain objects — mutated in-place, no signal needed, checked once per card.
    property var newCardIds:      ({})   // id → true  (no entry animation)
    property var entryDirections: ({})   // id → dir   (x spring on column move)

    // ── Delete confirm ────────────────────────────────────────────────────────
    property int delConfirmId: -1   // task id with the dialog open, -1 = none

    // ── Clear column confirm ──────────────────────────────────────────────────
    property int clearConfirmCol: -1   // column with the overlay open, -1 = none

    // ── Keyboard selection ────────────────────────────────────────────────────
    property int  selectedId: -1    // task highlighted by the arrow keys, -1 = none
    property int  focusCol:   0     // column the keys act on (follows the selection)
    property bool keyNav:     false // the keys have been used: show the column focus

    onSelectedIdChanged: {
        var t = KanbanService.task(selectedId)
        if (t) focusCol = t.column
    }

    // Where the delete dialog is drawn (the whole dashboard); the board itself if unset.
    property Item overlayParent: null

    // ── Actions used by the columns and cards ─────────────────────────────────
    function addTask(col, title) {
        // Recorded before the model changes, so the new card can read it
        newCardIds[KanbanService.nextId] = true
        var id = KanbanService.addTask(col, title)
        if (keyNav) selectedId = id
    }

    function moveTask(id, dir) {
        var t = KanbanService.task(id)
        if (!t || t.column + dir < 0 || t.column + dir > 2) return
        entryDirections[id] = dir
        KanbanService.moveTask(id, dir)
        if (id === selectedId) focusCol = t.column + dir
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

    // Asks to clear a column (its header's "Clear"); closes the other dialogs.
    function askClearColumn(col) {
        if (!tasksIn(col).length) return
        delConfirmId = -1
        datePicker.close()
        clearConfirmCol = col
    }

    function clearColumn(col) {
        clearConfirmCol = -1
        var sel = KanbanService.task(selectedId)
        if (sel && sel.column === col) selectedId = -1
        KanbanService.clearColumn(col)
    }

    function tasksIn(col) {
        return KanbanService.tasks.filter(function(t) { return t.column === col })
    }

    // dx: ±1 to the next column (empty ones too), keeping the row where
    // possible; dy: ±1 within the focused column (nothing selected → its first task).
    function navigate(dx, dy) {
        keyNav = true
        var sel  = KanbanService.task(selectedId)
        var list = tasksIn(focusCol)
        var row  = sel ? list.findIndex(function(t) { return t.id === sel.id }) : -1
        if (dy !== 0) {
            if (row < 0) { if (list.length) selectedId = list[0].id; return }
            var ni = row + dy
            if (ni >= 0 && ni < list.length) selectedId = list[ni].id
            return
        }
        var nc = focusCol + dx
        if (nc < 0 || nc > 2) return
        var next = tasksIn(nc)
        focusCol   = nc
        selectedId = next.length ? next[Math.min(Math.max(row, 0), next.length - 1)].id : -1
    }

    // Opens the draft card of the focused column.
    function addInFocusedColumn() {
        keyNav = true
        var col = columns.itemAt(focusCol)
        if (col) col.openDraft()
    }

    Keys.onPressed: function(ev) {
        // Clear overlay open: Enter confirms, Esc cancels, nothing else
        if (clearConfirmCol >= 0) {
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) clearColumn(clearConfirmCol)
            else if (ev.key === Qt.Key_Escape) clearConfirmCol = -1
            ev.accepted = true
            return
        }
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
        case Qt.Key_Plus:
            addInFocusedColumn()
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
            root.delConfirmId    = -1
            root.clearConfirmCol = -1
            root.selectedId   = -1
            datePicker.close()
        }
    }

    // ── Reset state when dashboard closes ─────────────────────────────────────
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) {
                root.delConfirmId    = -1
                root.clearConfirmCol = -1
                root.selectedId   = -1
                root.keyNav       = false
                datePicker.close()
            }
        }
    }

    // The dialog lives outside the board: cancel it when leaving the Tasks tab.
    // Shown: take the keyboard for the arrows and Delete.
    onVisibleChanged: {
        if (visible) forceActiveFocus()
        else { delConfirmId = -1; clearConfirmCol = -1 }
    }

    // The dialog's Enter / Esc reach the board (e.g. after a click on ✕).
    onDelConfirmIdChanged: {
        if (delConfirmId >= 0) forceActiveFocus()
    }
    onClearConfirmColChanged: {
        if (clearConfirmCol >= 0) forceActiveFocus()
    }

    // ── Columns ───────────────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: hints.top }
        anchors.topMargin: 8
        anchors.bottomMargin: 6
        spacing: 8

        Repeater {
            id: columns
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

    // ── Keyboard hints ────────────────────────────────────────────────────────
    Row {
        id: hints
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
        spacing: 14
        opacity: root.activeFocus || root.keyNav ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Repeater {
            model: [
                { keys: ["←", "→"],      label: "column" },
                { keys: ["↑", "↓"],      label: "task"   },
                { keys: ["⇧", "←", "→"], label: "move"   },
                { keys: ["+"],           label: "add"    },
                { keys: ["Del"],         label: "delete" }
            ]
            delegate: Row {
                required property var modelData
                spacing: 3

                Repeater {
                    model: modelData.keys
                    delegate: Rectangle {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(16, keyT.implicitWidth + 8); height: 16; radius: 4
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                        Text {
                            id: keyT; anchors.centerIn: parent
                            text: modelData; font.pixelSize: 9
                            color: Qt.rgba(1, 1, 1, 0.55)
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 2
                    text: modelData.label; font.pixelSize: 9
                    color: Qt.rgba(1, 1, 1, 0.30)
                }
            }
        }
    }

    // ── Delete confirm dialog (dims the whole dashboard while open) ──────────
    KanbanDeleteDialog {
        parent:       root.overlayParent || root
        anchors.fill: parent
        z:            40
        shown:        root.delConfirmId >= 0
        detail:       { var t = KanbanService.task(root.delConfirmId); return t ? t.title : "" }
        onConfirmed:  root.removeTask(root.delConfirmId)
        onCancelled:  root.delConfirmId = -1
    }

    // ── Clear column confirm (dims that column; a click anywhere else cancels) ─
    MouseArea {
        anchors.fill: parent
        z:            30
        visible:      root.clearConfirmCol >= 0
        onClicked:    root.clearConfirmCol = -1
    }

    KanbanDeleteDialog {
        readonly property real colW: (mainRow.width - mainRow.spacing * 2) / 3
        // Stays on the last column while hiding, so it doesn't jump.
        property int col: 0
        x:      mainRow.x + col * (colW + mainRow.spacing)
        y:      mainRow.y
        width:  colW
        height: mainRow.height
        z:      31
        shown:   root.clearConfirmCol >= 0
        heading: { var n = root.tasksIn(col).length; return "Delete " + n + (n === 1 ? " task?" : " tasks?") }
        detail:  columns.model[col].label
        onShownChanged: if (shown) col = root.clearConfirmCol
        onConfirmed:    root.clearColumn(root.clearConfirmCol)
        onCancelled:    root.clearConfirmCol = -1
    }

    // ── Due-date picker (dims the board while open) ───────────────────────────
    KanbanDatePicker {
        id: datePicker
        anchors.fill: parent
        z: 29
    }
}
