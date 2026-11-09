pragma Singleton
import QtQuick
import Quickshell.Io

// ============================================================
// ClockState — the clock engine: wall clock, timer, stopwatch and alarms.
//
// Single source of truth for every clock view: the dashboard's ClockCard
// (services/home/clock/*) and the centre notch (CenterContent) read these
// properties and change them only through the functions below. Runs from
// the first access (the bar's centre notch, at startup), so timers,
// the stopwatch and alarms keep going while the dashboard is closed.
// ============================================================

QtObject {
    id: root

    // ── Wall clock (updated every second) ──────────────────────────────────
    property int hours:   0
    property int minutes: 0
    property int seconds: 0

    // ── Timer ──────────────────────────────────────────────────────────────
    property int  timerTotal:   10 * 60
    property int  timerLeft:    10 * 60
    property bool timerRunning: false
    // True once started, until reset: keeps the timer in the centre notch.
    property bool timerStarted: false
    property bool _timerFired:  false

    readonly property string timerDisplay: _duration(timerLeft)
    readonly property real   timerProgress:
        timerTotal > 0 ? (timerTotal - timerLeft) / timerTotal : 0

    // ── Stopwatch ──────────────────────────────────────────────────────────
    property int  swMs:      0
    property bool swRunning: false
    // True once started, until reset: keeps the stopwatch in the centre notch.
    property bool swStarted: false

    readonly property string swDisplay: {
        var t = Math.floor(swMs / 1000)
        return zp(Math.floor(t / 60)) + ":" + zp(t % 60)
    }

    // ── Alarms — list of { id, hour, minute, label, enabled, firedToday } ──
    property var alarms:      []
    property int _alarmIdSeq: 0

    // Nearest upcoming enabled alarm: { hour, minute, label, minsUntil } or null
    property var nextAlarm: null

    // True when something is actively running
    readonly property bool hasActiveEvent:
        timerRunning || swRunning || nextAlarm !== null

    // ── Timer actions ──────────────────────────────────────────────────────
    function setTimer(totalSeconds) {
        if (totalSeconds <= 0) return
        timerTotal   = totalSeconds
        timerLeft    = totalSeconds
        timerRunning = false
        _timerFired  = false
    }

    function toggleTimer() {
        timerRunning = !timerRunning
        timerStarted = true
        _timerFired  = false
    }

    function resetTimer() {
        timerLeft    = timerTotal
        timerRunning = false
        _timerFired  = false
        timerStarted = false
    }

    // ── Stopwatch actions ──────────────────────────────────────────────────
    function toggleStopwatch() {
        swRunning = !swRunning
        swStarted = true
    }

    function resetStopwatch() {
        swMs      = 0
        swRunning = false
        swStarted = false
    }

    // ── Alarm actions ──────────────────────────────────────────────────────
    function addAlarm(hour, minute) {
        var list = alarms.slice()
        list.push({
            id:         _alarmIdSeq++,
            hour:       hour,
            minute:     minute,
            label:      "",
            enabled:    true,
            firedToday: false
        })
        alarms = list
    }

    function toggleAlarm(id) {
        var list = alarms.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = Object.assign({}, list[i], { enabled: !list[i].enabled })
                break
            }
        }
        alarms = list
    }

    function deleteAlarm(id) {
        alarms = alarms.filter(function(a) { return a.id !== id })
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    function zp(n) { return n < 10 ? "0" + n : "" + n }

    function _duration(secs) {
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        return h > 0 ? zp(h) + ":" + zp(m) + ":" + zp(s) : zp(m) + ":" + zp(s)
    }

    function _timerTotalLabel() {
        var h = Math.floor(timerTotal / 3600)
        var m = Math.floor((timerTotal % 3600) / 60)
        return h > 0 ? h + "h " + zp(m) + "m" : m + "m"
    }

    function _readClock() {
        var d = new Date()
        hours   = d.getHours()
        minutes = d.getMinutes()
        seconds = d.getSeconds()
    }

    function _checkAlarms() {
        var list = alarms.slice(), changed = false
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            if (!a.enabled) continue
            var now = a.hour === hours && a.minute === minutes
            if (now && !a.firedToday) {
                list[i] = Object.assign({}, a, { firedToday: true })
                changed = true
                _notify("Alarm", (a.label !== "" ? a.label : "Alarm") +
                        " — " + zp(a.hour) + ":" + zp(a.minute))
            }
            if (a.firedToday && !now) {
                list[i] = Object.assign({}, a, { firedToday: false })
                changed = true
            }
        }
        if (changed) alarms = list
    }

    function _updateNextAlarm() {
        var now = hours * 60 + minutes, best = null
        for (var i = 0; i < alarms.length; i++) {
            var a = alarms[i]
            if (!a.enabled) continue
            var t    = a.hour * 60 + a.minute
            var diff = t >= now ? t - now : t + 1440 - now
            if (best === null || diff < best.minsUntil)
                best = { hour: a.hour, minute: a.minute, label: a.label, minsUntil: diff }
        }
        nextAlarm = best
    }

    onAlarmsChanged: _updateNextAlarm()

    // ── Engine ─────────────────────────────────────────────────────────────
    property Process _notifyProc: Process { running: false }

    function _notify(title, body) {
        _notifyProc.command = ["notify-send", "-a", "Synapse", "-i", "alarm", title, body]
        _notifyProc.running = false
        _notifyProc.running = true
    }

    property Timer _tick: Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root._readClock()
            if (root.swRunning) root.swMs += 1000
            if (root.timerRunning && root.timerLeft > 0) {
                root.timerLeft--
                if (root.timerLeft === 0) {
                    root.timerRunning = false
                    if (!root._timerFired) {
                        root._timerFired = true
                        root._notify("Timer finished",
                            "Your " + root._timerTotalLabel() + " timer is done.")
                    }
                }
            }
            if (root.seconds === 0) root._checkAlarms()
            root._updateNextAlarm()
        }
    }

    Component.onCompleted: { _readClock(); _updateNextAlarm() }
}
