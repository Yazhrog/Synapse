import QtQuick
import Quickshell.Io

// Exec — runs one external command and reports how it ended.
//
//   Exec {
//       id: scan
//       command: ["nmcli", "-t", "-f", "SSID", "dev", "wifi", "list"]
//       parse: Nmcli.parseWifiList                   // optional, pure
//       onSucceeded: result => root._networks = result
//       onFailed: (code, stderr) => root._networks = []
//   }
//   scan.run()
//
// `command` is an argument list. Data (an SSID, a path, a name) is always its
// own element, never pasted into a shell string: a script that needs a shell
// takes data as positional arguments, ["bash", "-c", 'nmcli con up "$1"', "--", name].
//
// Each run() starts a fresh process; calling it while one is running cancels
// that one first, and a cancelled run reports nothing. When a run ends:
//   succeeded(result)   exit code 0; result = parse(stdout), or stdout
//   failed(code, err)   any other exit code, a timeout (124), a parse error
//                       (-1) or a command that could not start (-2)
//   finished(ok)        after either, for "whatever happened" handlers
// With `stream: true`, every stdout line is emitted as line(text) while the
// command runs, and succeeded() gets "" (for long-running commands: cava,
// nmcli monitor). With `discardOutput: true`, stdout and stderr aren't read
// at all and succeeded()/failed() get "": for a command that runs for hours
// and logs (a recorder, an idle inhibitor, a launched app), whose output
// would otherwise pile up in memory until it exits.
QtObject {
    id: root

    property var    command:     []      // list<string>
    property var    environment: ({})    // extra variables, name → value
    property string stdinText:   ""      // written once at start, then stdin is closed
    property var    parse:       null    // function(stdout) → result
    property int    timeout:     0       // ms, 0 = none
    property bool   stream:      false
    property bool   discardOutput: false

    readonly property bool busy: _current !== null
    property string lastError:  ""       // stderr (or reason) of the last failed run

    signal succeeded(var result)
    signal failed(int code, string stderr)
    signal finished(bool ok)
    signal line(string text)

    // Starts the command (`args` replaces `command` for this run only).
    function run(args) {
        cancel()
        const argv = args !== undefined ? args : command
        if (!argv || argv.length === 0) {
            console.warn("Exec: empty command")
            return
        }
        const comp = discardOutput ? _discardComp : stream ? _streamComp : _collectComp
        const run = comp.createObject(root, {
            command: argv,
            environment: environment,
            stdinEnabled: stdinText !== ""
        })
        _current = run
        run._start(timeout)
    }

    function cancel() {
        const r = _current
        if (!r) return
        _current = null
        r._cancel()
    }

    // ── Implementation ──────────────────────────────────────────────────────
    property var _current: null

    function _ended(run, code, out, err) {
        if (run !== _current) return          // cancelled or replaced
        _current = null
        let ok = code === 0, result = out
        if (ok && parse && !stream) {
            try { result = parse(out) }
            catch (e) { ok = false; code = -1; err = "parse error: " + e }
        }
        if (ok) {
            succeeded(result)
        } else {
            lastError = err
            failed(code, err)
        }
        finished(ok)
    }

    // One run: the process, its collectors and its timeout.
    component Run: Process {
        id: proc
        property bool   _exited:  false
        property bool   _outDone: false
        property bool   _errDone: false
        property bool   _started: false
        property bool   _dead:    false
        property int    _code:    0
        property string _out:     ""
        property string _err:     ""

        function _start(ms) {
            if (ms > 0) { killTimer.interval = ms; killTimer.start() }
            startCheck.start()
            running = true
        }
        function _cancel() {
            _dead = true
            killTimer.stop(); startCheck.stop()
            if (running) running = false
            Qt.callLater(proc.destroy)
        }
        function _maybeEnd() {
            if (_dead || !_exited || !_outDone || !_errDone) return
            _dead = true
            killTimer.stop()
            root._ended(proc, _code, _out, _err)
            Qt.callLater(proc.destroy)
        }

        onStarted: {
            _started = true
            if (root.stdinText !== "") { write(root.stdinText); stdinEnabled = false }
        }
        onExited: function(code) { _exited = true; if (_code === 0) _code = code; _maybeEnd() }

        // A command that can't start (binary not found) reports running = false
        // without ever having been running, and never exits.
        property bool _wasRunning: false
        onRunningChanged: {
            if (running) _wasRunning = true
            else if (!_wasRunning) _failToStart()
        }
        function _failToStart() {
            if (_dead) return
            _dead = true
            killTimer.stop(); startCheck.stop()
            root._ended(proc, -2, "", "could not start " + (command[0] ?? ""))
            Qt.callLater(proc.destroy)
        }

        property Timer killTimer: Timer {
            onTriggered: { proc._code = 124; proc._err = "timed out"; proc.running = false }
        }
        // Fallback, should the running signal above ever not come.
        property Timer startCheck: Timer {
            interval: 2000
            onTriggered: if (!proc._started) proc._failToStart()
        }
    }

    property Component _collectComp: Component {
        Run {
            id: run
            stdout: StdioCollector { onStreamFinished: { run._out = text; run._outDone = true; run._maybeEnd() } }
            stderr: StdioCollector { onStreamFinished: { run._err = text; run._errDone = true; run._maybeEnd() } }
        }
    }

    property Component _streamComp: Component {
        Run {
            id: run
            _outDone: true
            stdout: SplitParser { onRead: data => root.line(data) }
            stderr: StdioCollector { onStreamFinished: { run._err = text; run._errDone = true; run._maybeEnd() } }
        }
    }

    // Neither stream is read (no collector: the output goes nowhere).
    property Component _discardComp: Component {
        Run { _outDone: true; _errDone: true }
    }
}
