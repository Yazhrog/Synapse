pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// ============================================================
// TaskService — the task board's data: user_data/tasks.json, the task
// list and its mutations, plus the urgency and due-date helpers the cards use.
//
// Task: { id, title, column (0 To Do, 1 Ongoing, 2 Done), urgency
// ("" | "low" | "medium" | "high"), dueDate ("" | "YYYY-MM-DD" | "YYYY-MM-DD HH:MM") }.
// File: { tasks: [...], nextId }, owned by a JsonStore: created empty if
// missing, loaded at startup, written atomically after every mutation, never
// before the load is done (so an early change can't overwrite the tasks).
// ============================================================

Singleton {
    id: root

    readonly property var  tasks:  _store.data.tasks ?? []
    readonly property int  nextId: _store.data.nextId ?? 0
    readonly property bool loaded: _store.ready

    readonly property string filePath: Paths.userData("tasks.json")

    // Emitted after clear() has emptied the file and the list.
    signal cleared()
    // Emitted when clear() is done, ok or not (Config → Data & Storage).
    signal clearFinished(bool ok)

    // ── Mutations ───────────────────────────────────────────────────────────
    // Returns the new task's id.
    function addTask(column, title) {
        return _store.update(d => {
            const id = d.nextId++
            d.tasks.unshift({ id: id, title: title, column: column, urgency: "", dueDate: "" })
            return id
        })
    }

    // Moves a task one column left (-1) or right (+1); false if it can't move.
    function moveTask(id, dir) {
        const t = task(id)
        if (!t || t.column + dir < 0 || t.column + dir > 2) return false
        _store.update(d => { d.tasks.find(x => x.id === id).column += dir })
        return true
    }

    function removeTask(id) {
        _store.update(d => { d.tasks = d.tasks.filter(t => t.id !== id) })
    }

    // Removes every task of one column, with a single save.
    function clearColumn(column) {
        _store.update(d => { d.tasks = d.tasks.filter(t => t.column !== column) })
    }

    function patchTask(id, key, val) {
        _store.update(d => {
            const t = d.tasks.find(x => x.id === id)
            if (t) t[key] = val
        })
    }

    function task(id) {
        for (var i = 0; i < tasks.length; i++)
            if (tasks[i].id === id) return tasks[i]
        return null
    }

    // Empties the file first and the list only once that worked, so a failed
    // write can't leave an empty board that later saves over the tasks.
    function clear() {
        _clearing = true
        _store.clear()
    }

    // ── Urgency helpers ─────────────────────────────────────────────────────
    function urgColor(u) {
        if (u === "high")   return "#f38ba8"
        if (u === "medium") return "#f9e2af"
        if (u === "low")    return "#a6e3a1"
        return "transparent"
    }
    function urgLabel(u) {
        if (u === "high")   return "High"
        if (u === "medium") return "Med"
        if (u === "low")    return "Low"
        return ""
    }

    // ── Due date helpers ────────────────────────────────────────────────────
    function zp2(n) { return n < 10 ? "0" + n : "" + n }

    function todayString() {
        var now = new Date()
        return now.getFullYear() + "-" + zp2(now.getMonth() + 1) + "-" + zp2(now.getDate())
    }

    // "Today", "Mar 4", "Today  14:30", "Mar 4  09:00" …
    function formatDue(s) {
        if (!s || s === "") return ""
        var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        var datePart = s.length >= 10 ? s.substring(0, 10) : ""
        var timePart = s.length >= 16 ? s.substring(11, 16) : ""
        var dateLabel = ""
        if (datePart !== "") {
            if (datePart === todayString()) dateLabel = "Today"
            else {
                var dp = datePart.split("-")
                dateLabel = months[parseInt(dp[1]) - 1] + " " + parseInt(dp[2])
            }
        }
        if (dateLabel !== "" && timePart !== "") return dateLabel + "  " + timePart
        if (dateLabel !== "") return dateLabel
        if (timePart !== "") return "Today  " + timePart
        return ""
    }

    // ── Persistence ─────────────────────────────────────────────────────────
    property bool _clearing: false

    property JsonStore _store: JsonStore {
        path:     root.filePath
        defaults: ({ tasks: [], nextId: 0 })

        onCleared: {
            root._clearing = false
            root.cleared()
            root.clearFinished(true)
        }
        onFailed: function(message) {
            if (!root._clearing) return
            root._clearing = false
            root.clearFinished(false)
        }
    }
}
