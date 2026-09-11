import QtQuick
import Quickshell.Io

// Hyprland (follow_mouse=1) sometimes doesn't hand a newly-mapped exclusive-
// keyboard-focus layer surface real Wayland keyboard focus until a pointer
// motion event forces it to re-evaluate focus (hyprwm/Hyprland discussion
// #13116). Nudging the cursor 1px and back replicates the manual mouse
// movement that otherwise picks up focus, so a forceActiveFocus() call/retry
// lands on a window that actually has it. Call nudge() right when a popup
// becomes visible.
Item {
    function nudge() {
        posProc.running = false
        posProc.running = true
    }

    Process {
        id: posProc
        command: ["hyprctl", "-j", "cursorpos"]
        running: false
        stdout: StdioCollector {
            id: posBuf
            onStreamFinished: {
                try {
                    var pos = JSON.parse(posBuf.text)
                    moveProc.command = ["sh", "-c",
                        "hyprctl dispatch movecursor " + (pos.x + 1) + " " + pos.y +
                        " && hyprctl dispatch movecursor " + pos.x + " " + pos.y]
                    moveProc.running = true
                } catch (e) {}
            }
        }
    }

    Process {
        id: moveProc
        running: false
    }
}
