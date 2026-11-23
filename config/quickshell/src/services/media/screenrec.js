// screenrec.js — the pure parts of ScreenRecService. Pure JS, tested by
// tests/unit/screenrec.test.mjs.

// Seconds → "mm:ss".
function formatElapsed(seconds) {
    const m = Math.floor(seconds / 60), s = seconds % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
}

// The audio routing script for the options, or null when no script is needed
// (no audio: nothing to resolve). Its last stdout line is the device to
// record from.
//   mic only    → the default source, passed straight to the recorder
//   system only → a SynapseMixer null sink fed by the default sink's monitor
//   both        → the same, plus a loopback from the default source (mic)
// The null sink (usesNullSink) has to be torn down after the recording.
function audioRouting(mic, system) {
    if (!mic && !system) return null
    if (!system) return { command: ["pactl", "get-default-source"], usesNullSink: false }
    let script =
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
    if (mic)
        script += "; pactl load-module module-loopback " +
                  "sink=SynapseMixer source=$(pactl get-default-source) >/dev/null"
    // Emit the recording device name as the final stdout line
    script += "; printf 'SynapseMixer.monitor\\n'"
    return { command: ["bash", "-c", script], usesNullSink: true }
}

// The last non-empty line of a command's output ("" if none).
function lastLine(out) {
    const lines = String(out).split("\n").map(l => l.trim()).filter(l => l !== "")
    return lines.length > 0 ? lines[lines.length - 1] : ""
}

// cava's config for the recording meter: 12 bars, raw ASCII on stdout.
function cavaConfig(source) {
    return "[general]\nbars = 12\nframerate = 20\nnoise_reduction = 77\n\n" +
           "[output]\nmethod = raw\nraw_target = /dev/stdout\n" +
           "data_format = ascii\nascii_max_range = 100\n" +
           "bar_delimiter = 59\nframe_delimiter = 10\n\n" +
           "[input]\nmethod = pulse\nsource = " + source + "\n"
}

// One cava frame ("12;40;…;" with 12 values) → the 12 levels, or null.
function parseCavaLine(line) {
    let t = String(line).trim()
    if (t === "") return null
    if (t.endsWith(";")) t = t.slice(0, -1)
    const parts = t.split(";")
    if (parts.length !== 12) return null
    return parts.map(p => parseInt(p) || 0)
}

if (typeof module !== "undefined")
    module.exports = { formatElapsed, audioRouting, lastLine, cavaConfig, parseCavaLine }
