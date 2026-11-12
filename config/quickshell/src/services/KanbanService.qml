pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// KanbanService — the task board's data: user_data/tasks.json, the task
// list and its mutations, plus the urgency and due-date helpers the cards use.
//
// Task: { id, title, column (0 To Do, 1 Ongoing, 2 Done), urgency
// ("" | "low" | "medium" | "high"), dueDate ("" | "YYYY-MM-DD" | "YYYY-MM-DD HH:MM") }.
// File: { tasks: [...], nextId }. Created empty if missing, loaded at startup;
// every mutation saves the whole file. Nothing is saved before the load is
// done, so an early change can't overwrite the tasks on disk.
// ============================================================

Singleton {
    id: root

    property var  tasks:  []
    property int  nextId: 0
    property bool loaded: false

    readonly property string filePath: Paths.userData("tasks.json")

    // Emitted after clear() has emptied the file and the list.
    signal cleared()
    // Emitted when clear() is done, ok or not (Config → Data & Storage).
    signal clearFinished(bool ok)

    // ── Mutations ───────────────────────────────────────────────────────────
    // Returns the new task's id.
    function addTask(column, title) {
        var id   = nextId++
        var list = tasks.slice()
        list.unshift({ id: id, title: title, column: column, urgency: "", dueDate: "" })
        tasks = list
        _save()
        return id
    }

    // Moves a task one column left (-1) or right (+1); false if it can't move.
    function moveTask(id, dir) {
        var list = tasks.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id) continue
            var nc = list[i].column + dir
            if (nc < 0 || nc > 2) return false
            list[i] = Object.assign({}, list[i], { column: nc })
            tasks = list
            _save()
            return true
        }
        return false
    }

    function removeTask(id) {
        tasks = tasks.filter(function(t) { return t.id !== id })
        _save()
    }

    // Removes every task of one column, with a single save.
    function clearColumn(column) {
        tasks = tasks.filter(function(t) { return t.column !== column })
        _save()
    }

    function patchTask(id, key, val) {
        var list = tasks.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id) continue
            var t = Object.assign({}, list[i]); t[key] = val; list[i] = t; break
        }
        tasks = list
        _save()
    }

    function task(id) {
        for (var i = 0; i < tasks.length; i++)
            if (tasks[i].id === id) return tasks[i]
        return null
    }

    // Empties the file first and the list only once that worked, so a failed
    // write can't leave an empty board that later saves over the tasks.
    function clear() {
        clearProc.command = ["bash", "-c",
            "printf '%s' '{\"tasks\":[],\"nextId\":0}' > " + Paths.shellQuote(filePath)]
        clearProc.running = false; clearProc.running = true
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
    function _save() {
        if (!loaded) return
        var s = JSON.stringify({ tasks: tasks, nextId: nextId })
        wrProc.command = ["bash", "-c",
            "printf '%s' " + Paths.shellQuote(s) + " > " + Paths.shellQuote(filePath)]
        wrProc.running = false; wrProc.running = true
    }

    // Creates the file if missing, then prints it.
    Process {
        id: rdProc
        command: ["bash", "-c",
            "[ -f " + Paths.shellQuote(root.filePath) + " ] || " +
            "(mkdir -p " + Paths.shellQuote(Paths.userDataDir) + " && " +
            "printf '%s' '{\"tasks\":[],\"nextId\":0}' > " + Paths.shellQuote(root.filePath) + "); " +
            "cat " + Paths.shellQuote(root.filePath)]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text)
                    root.tasks  = o.tasks  || []
                    root.nextId = o.nextId || 0
                } catch(e) { root.tasks = []; root.nextId = 0 }
                root.loaded = true
            }
        }
    }

    Process { id: wrProc; command: []; running: false }

    Process {
        id: clearProc; command: []; running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.tasks  = []
                root.nextId = 0
                root.cleared()
            }
            root.clearFinished(exitCode === 0)
        }
    }

    Component.onCompleted: rdProc.running = true
}
