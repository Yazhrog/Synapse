import QtQuick

// WfRecorder — wf-recorder as the recorder backend: H.264 at 30 fps, tagged
// BT.709 TV range so players show the right blacks, small enough to share.
RecorderBackend {
    name: "wf-recorder"
    stopCommand: ["pkill", "-INT", "wf-recorder"]

    function command(opts: var): var {
        const args = ["wf-recorder", "-c", "libx264",
                      "-x", "yuv420p",
                      "-r", "30",                       // Limit FPS to 30
                      "-p", "preset=fast",              // Faster encoding speed
                      "-p", "crf=26",                   // Lower quality/smaller size
                      "-p", "profile=main",             // Maximum web/Discord compatibility
                      "-p", "color_range=tv",           // Fixes washed out blacks/whites
                      "-p", "colorspace=bt709",         // Tags the correct HD color matrix
                      "-p", "color_primaries=bt709",
                      "-p", "color_trc=bt709",
                      "-f", opts.file]
        if (opts.geometry) args.push("-g", opts.geometry)
        // --audio=DEVICE (the wf-recorder convention)
        if (opts.audioDevice) args.push("--audio=" + opts.audioDevice)
        return args
    }
}
