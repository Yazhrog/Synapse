pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.data
// ScreenRecService — owns all screen recording state.
//
// Audio routing (fixed):
//   none        → no -a flag; launch directly
//   mic only    → pactl get-default-source → pass directly to wf-recorder
//   system only → SynapseMixer null sink + loopback from sink.monitor
//   both        → SynapseMixer null sink + loopback from sink.monitor
//                 + loopback from default source (mic)
//
// The null sink is torn down after every recording (saved or discarded).
// Notifications are sent via notify-send with action buttons (requires
// libnotify ≥ 0.8 and a daemon that supports actions, e.g. dunst/mako).
// Every path, geometry and device name goes to its command as an argument.
//
// `setupOpen` is the recording setup in the bar (capture / audio choice
// before starting); ShellState.screenRecord mirrors it for the surface.

Singleton {
    id: root

    // ── Persisted options ─────────────────────────────────────────────────────
    property string captureTarget: "screen"
    property bool   audioMic:      false
    property bool   audioSystem:   false

    // ── Display helpers ───────────────────────────────────────────────────────
    readonly property var _captureIcons:  ({ screen: "󰍹", window: "󱂬", region: "󰩭" })
    readonly property var _captureLabels: ({ screen: "Screen", window: "Window", region: "Region" })
    readonly property string captureIcon:  _captureIcons[captureTarget]  ?? "󰍹"
    readonly property string captureLabel: _captureLabels[captureTarget] ?? "Screen"

    readonly property string audioLabel: {
        if (audioMic && audioSystem) return "Mic + Sys"
        if (audioMic)                return "Mic"
        if (audioSystem)             return "Sys"
        return "Non"
    }

    // ── Strip hover (open = "capture" | "audio" | "") ─────────────────────────
    property string openStrip: ""
    property real popupTargetX: 0
    property string popupTargetScreen: ""   // screen whose bar opened the options list
    property real popupTargetWidth: 0

    property var _stripTimer: Timer {
        interval: 280
        onTriggered: root.openStrip = ""
    }
    function keepStripOpen()      { _stripTimer.stop()    }
    function scheduleStripClose() { _stripTimer.restart() }

    // ── Setup ─────────────────────────────────────────────────────────────────
    property bool setupOpen: false
    function openSetup() { setupOpen = true }

    // ── Recording state ───────────────────────────────────────────────────────
    property bool   recording:      false
    property int    elapsed:        0
    property string _currentFile:   ""   // tracked so discard can delete it
    property bool   _discarding:    false // true when discardRecording() was called
    property bool   _usingNullSink: false // true while SynapseMixer is active

    readonly property string elapsedDisplay: {
        var m = Math.floor(elapsed / 60)
        var s = elapsed % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    property var _elapsedTimer: Timer {
        interval: 1000
        running:  root.recording
        repeat:   true
        onTriggered: root.elapsed++
    }

    // ── Audio bars — 6 bars, always active during recording ───────────────────
    property var audioBars: [0, 0, 0, 0, 0, 0]

    // ── Config (user_data/screenrec.json) ─────────────────────────────────────
    property JsonStore _config: JsonStore {
        path:     Paths.userData("screenrec.json")
        defaults: ({ captureTarget: "screen", audioMic: false, audioSystem: false })
        onLoaded: {
            const o = data
            if (o.captureTarget) root.captureTarget = o.captureTarget
            if (typeof o.audioMic    === "boolean") root.audioMic    = o.audioMic
            if (typeof o.audioSystem === "boolean") root.audioSystem = o.audioSystem
        }
    }

    function saveConfig() {
        _config.set({
            captureTarget: root.captureTarget,
            audioMic:      root.audioMic,
            audioSystem:   root.audioSystem
        })
    }

    // ── Recording process ─────────────────────────────────────────────────────
    property string _pendingGeometry: ""
    property string _resolvedAudioDevice: ""

    // slurp prints the picked geometry ("x,y wxh"); cancelling exits non-zero
    property Exec _pickerProc: Exec {
        onFinished: ok => {
            const g = lastOutput.trim()
            if (ok && g !== "") {
                root._pendingGeometry = g
                root._resolveAudio()
            } else {
                root._pendingGeometry = ""
            }
        }
    }

    // Step 1: resolve/set up audio device, then launch.
    // Reads the resolved device name from stdout (last non-empty line).
    property Exec _audioDeviceProc: Exec {
        onFinished: {
            const lines = lastOutput.split("\n").map(l => l.trim()).filter(l => l !== "")
            if (lines.length > 0) root._resolvedAudioDevice = lines[lines.length - 1]
            root._launch()
        }
    }

    // ── Audio resolution ──────────────────────────────────────────────────────
    //
    // none:        call _launch() immediately — no audio device, no null sink.
    // mic only:    get default PulseAudio source; pass straight to wf-recorder.
    // system only: create SynapseMixer null sink, route sink.monitor into it.
    // both:        create SynapseMixer null sink, route sink.monitor AND
    //              default source (mic) into it via two loopback modules.
    //
    function _resolveAudio() {
        root._resolvedAudioDevice = ""
        root._usingNullSink       = false

        if (!root.audioMic && !root.audioSystem) {
            // No audio — skip device resolution entirely
            root._launch()
            return
        }

        if (root.audioMic && !root.audioSystem) {
            // Mic only — use the default source directly; no null sink needed
            _audioDeviceProc.run(["pactl", "get-default-source"])
            return
        }

        // System audio (alone or combined with mic) — needs SynapseMixer
        root._usingNullSink = true

        var script =
            // Clean up any stale modules from a previous crashed session
            "pactl unload-module module-loopback 2>/dev/null; " +
            "pactl unload-module module-null-sink 2>/dev/null; " +
            "sleep 0.3; " +
            // Create the virtual mixer sink
            "pactl load-module module-null-sink sink_name=SynapseMixer >/dev/null; " +
            "sleep 0.3; " +
            // Route system audio (default sink monitor) into SynapseMixer
            "pactl load-module module-loopback " +
            "sink=SynapseMixer source=$(pactl get-default-sink).monitor >/dev/null"

        if (root.audioMic && root.audioSystem) {
            // Also route mic into SynapseMixer
            script += "; pactl load-module module-loopback " +
                      "sink=SynapseMixer source=$(pactl get-default-source) >/dev/null"
        }

        // Emit the recording device name as the final stdout line
        script += "; printf 'SynapseMixer.monitor\\n'"

        _audioDeviceProc.run(["bash", "-c", script])
    }

    // ── Null-sink teardown — run after every recording ends ───────────────────
    property Exec _cleanupAudioProc: Exec {
        command: ["bash", "-c",
            "pactl unload-module module-loopback 2>/dev/null; " +
            "pactl unload-module module-null-sink 2>/dev/null"]
    }

    function _teardownNullSink() {
        if (!root._usingNullSink) return
        root._usingNullSink = false
        _cleanupAudioProc.run()
    }

    // ── Notification process ──────────────────────────────────────────────────
    // Uses notify-send --wait + --action (libnotify ≥ 0.8 required).
    // Saved recording: shows "View Folder" (xdg-open dir) and "Open in MPV".
    property Exec _notifyProc: Exec {}

    // ── wf-recorder process ───────────────────────────────────────────────────
    // Runs for the whole recording and logs all along: its output isn't kept.
    property Exec _recProc: Exec {
        discardOutput: true
        onFinished: {
            var savedFile = root._currentFile   // capture before it is cleared

            root.recording        = false
            root.elapsed          = 0
            root._pendingGeometry = ""
            root._currentFile     = ""
            root._cavaRecProc.cancel()
            root.audioBars        = [0, 0, 0, 0, 0, 0]
            root.setupOpen        = false

            // Always tear down the null sink (no-op when mic-only or no-audio)
            root._teardownNullSink()

            if (!root._discarding && savedFile !== "") {
                // Normal stop — notify with interactive action buttons.
                _notifyProc.run(["bash", "-c",
                    "FILE=\"$1\"; " +
                    "DIR=\"$(dirname \"$FILE\")\"; " +
                    "ACTION=$(notify-send" +
                    " --app-name 'ScreenRec'" +
                    " --icon 'video-x-generic'" +
                    " --action 'view=View Folder'" +
                    " --action 'open=Open in MPV'" +
                    " --wait" +
                    " 'Recording Saved' \"$FILE\"); " +
                    "case \"$ACTION\" in" +
                    "  view) xdg-open \"$DIR\" ;;" +
                    "  open) mpv \"$FILE\" ;;" +
                    "esac",
                    "--", savedFile])
            }
            // Discard path: _discardTimer handles file deletion + notification
        }
    }

    // Recordings folder from Config → General, "~" expanded.
    readonly property string outputDir: {
        const dir = Paths.expand(PrefsService.screenRecordingDir).replace(/\/+$/, "")
        return dir !== "" ? dir : Paths.home + "/Videos/screen_recordings"
    }

    // wf-recorder's arguments for this recording (and the file it writes).
    function _recorderArgs() {
        var ts  = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")
        root._currentFile = root.outputDir + "/" + ts + ".mp4"
        var args = ["wf-recorder", "-c", "libx264",
                    "-x", "yuv420p",
                    "-r", "30",                       // Limit FPS to 30
                    "-p", "preset=fast",              // Faster encoding speed
                    "-p", "crf=26",                   // Lower quality/smaller size
                    "-p", "profile=main",             // Maximum web/Discord compatibility
                    "-p", "color_range=tv",           // Fixes washed out blacks/whites
                    "-p", "colorspace=bt709",         // Tags the correct HD color matrix
                    "-p", "color_primaries=bt709",
                    "-p", "color_trc=bt709",
                    "-f", root._currentFile]
        if (root._pendingGeometry !== "")
            args.push("-g", root._pendingGeometry)
        // --audio=DEVICE (the wf-recorder convention)
        if ((root.audioMic || root.audioSystem) && root._resolvedAudioDevice !== "")
            args.push("--audio=" + root._resolvedAudioDevice)
        return args
    }

    function _launch() {
        // $1 is the folder to create; the rest is wf-recorder's command line
        _recProc.run(["bash", "-c", 'mkdir -p "$1" && shift && exec "$@"', "--", root.outputDir]
                     .concat(root._recorderArgs()))
        root.recording   = true
        root.elapsed     = 0
        root.openStrip   = ""
        if (root._resolvedAudioDevice !== "")
            _startCavaWithSource(root._resolvedAudioDevice)
    }

    function startRecording() {
        root._pendingGeometry = ""
        root._discarding      = false
        saveConfig()
        if (root.captureTarget === "screen") {
            root._resolveAudio()
        } else if (root.captureTarget === "window") {
            _pickerProc.run([
                "bash", "-c",
                "hyprctl clients -j | python3 -c \"" +
                "import sys,json; ws=json.load(sys.stdin); " +
                "[print(str(w['at'][0])+','+str(w['at'][1])+' '+str(w['size'][0])+'x'+str(w['size'][1])) " +
                "for w in ws if w['mapped']]\" | slurp"
            ])
        } else {
            _pickerProc.run([
                "bash", "-c",
                "hyprctl monitors -j | python3 -c \"" +
                "import sys,json; ms=json.load(sys.stdin); " +
                "[print(str(m['x'])+','+str(m['y'])+' '+str(m['width'])+'x'+str(m['height'])) for m in ms]\" | slurp"
            ])
        }
    }

    function stopRecording() { _sigProc.run() }

    function discardRecording() {
        root._discarding = true
        var fileToDelete = root._currentFile
        // Kill wf-recorder; _recProc.onExited will see _discarding=true and skip
        // the saved notification. The timer below handles delete + notify.
        _sigProc.run()
        _discardTimer.fileToDelete = fileToDelete
        _discardTimer.restart()
    }

    property var _discardTimer: Timer {
        property string fileToDelete: ""
        interval: 800
        onTriggered: {
            if (fileToDelete !== "") {
                var f = fileToDelete
                _discardDeleteProc.run(["bash", "-c",
                    'rm -f "$1" && ' +
                    "notify-send" +
                    " --app-name 'ScreenRec'" +
                    " --icon 'video-x-generic'" +
                    " 'Recording Discarded'" +
                    " 'The recording was deleted.'",
                    "--", f])
                fileToDelete        = ""
                root._discarding    = false
            }
        }
    }

    property Exec _discardDeleteProc: Exec {}

    function cancelSetup() {
        root.openStrip = ""
        root.setupOpen = false
    }

    property Exec _sigProc: Exec { command: ["pkill", "-INT", "wf-recorder"] }

    // ── Cava — runs during recording, source mirrors wf-recorder's audio ──────
    property Exec _cavaRecProc: Exec {
        stream: true
        onLine: line => {
            if (!root.recording) return
            var t = line.trim()
            if (t === "") return
            if (t.endsWith(";")) t = t.slice(0, -1)
            var parts = t.split(";")
            if (parts.length !== 12) return
            var bars = []
            for (var i = 0; i < 12; i++) bars.push(parseInt(parts[i]) || 0)
            root.audioBars = bars
        }
    }

    function _startCavaWithSource(src) {
        var config =
            "[general]\nbars = 12\nframerate = 20\nnoise_reduction = 77\n\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\n" +
            "data_format = ascii\nascii_max_range = 100\n" +
            "bar_delimiter = 59\nframe_delimiter = 10\n\n" +
            "[input]\nmethod = pulse\nsource = " + src + "\n"

        _cavaRecProc.run(["bash", "-c",
            "mkdir -p /tmp/synapse && printf '%s\\n' \"$1\" > /tmp/synapse/cava_rec.ini && " +
            "exec cava -p /tmp/synapse/cava_rec.ini 2>/dev/null",
            "--", config])
    }
}
