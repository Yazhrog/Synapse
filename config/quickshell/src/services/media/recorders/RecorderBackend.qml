import QtQuick

// RecorderBackend — how ScreenRecService records (ARCHITECTURE.md §5.11,
// recorder backend strategy). An implementation turns the recording options
// into a command line; the service runs it, stops it with `stopCommand`
// (the recorder must save the file on that signal) and handles audio
// routing, the picker and the notifications itself.
//
// Implementations: WfRecorder. F14 adds gpu-screen-recorder and wl-screenrec.
QtObject {
    // Shown in the UI and logs.
    property string name: ""
    // Run to stop the recording cleanly.
    property var stopCommand: []

    // opts: { file: string, geometry: string ("x,y wxh" or "" for the whole
    // screen), audioDevice: string ("" for none) } → the argument list.
    function command(opts: var): var { return [] }
}
