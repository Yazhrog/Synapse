// Behaviour test of the design tokens (theme/): the token groups hold
// today's values, and MatugenSource follows colors.json live, keeping the
// palette when the file is half-written or broken. Prints PASS/FAIL lines,
// then THEME OK. Run by tests/smoke.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.core
import qs.src.theme
ShellRoot {
    id: t

    readonly property string file: Paths.userData("colors.json")

    property int failures: 0
    function check(name, cond, msg) {
        if (cond) console.log("PASS " + name)
        else { failures++; console.log("FAIL " + name + ": " + msg) }
    }
    function same(a, b) { return Qt.colorEqual(a, b) }

    FileView { id: seed; path: t.file; atomicWrites: true }

    // Each step writes the file, then the next one checks what the source made of it.
    property int step: 0
    Timer {
        id: tick
        interval: 600; repeat: true; running: true
        onTriggered: t.run(t.step++)
    }

    function run(n) {
        const c = Theme.color
        if (n === 0) {
            check("fallback palette", same(c.accent, "#a6d0f7") && same(c.background, "#1a282a")
                  && same(c.text, "#cdd6f4") && same(c.textMuted, "#94e2d5"), c.accent + " " + c.background)
            check("frame values", Theme.frame.borderWidth === 6 && Theme.frame.notchHeight === 40
                  && Theme.frame.opacity === 1 && Theme.frame.barStyle === "frame", "")
            check("radius", Theme.radius.card === 17 && Theme.radius.notch === 15, Theme.radius.card + "/" + Theme.radius.notch)
            check("motion", Theme.motion.slow === 320 && Theme.motion.fast === 150
                  && Theme.motion.emphasized === Easing.InOutCubic, "")
            check("surface = background × opacity", same(c.surface, c.background), c.surface)
            check("state layer from the foreground", same(c.hairline, Qt.rgba(c.text.r, c.text.g, c.text.b, 0.07)), c.hairline)
            check("scrim is black", same(c.scrim, Qt.rgba(0, 0, 0, 0.6)), c.scrim)
            check("alpha()", same(c.alpha("#ff0000", 0.5), Qt.rgba(1, 0, 0, 0.5)), c.alpha("#ff0000", 0.5))
            seed.setText(JSON.stringify({ background: "#101010", active: "#ff8800", text: "#eeeeee",
                                          subtext: "#aaaaaa" }))
        } else if (n === 1) {
            check("colors.json read", same(c.accent, "#ff8800") && same(c.background, "#101010")
                  && same(c.text, "#eeeeee") && same(c.textMuted, "#aaaaaa"), c.accent + " " + c.background)
            check("missing key keeps its colour", same(c.border, "#ffffff"), c.border)
            seed.setText("{ \"active\": ")
        } else if (n === 2) {
            check("broken file keeps the palette", same(c.accent, "#ff8800"), c.accent)
            seed.setText("")
        } else if (n === 3) {
            check("empty file keeps the palette", same(c.accent, "#ff8800"), c.accent)
            seed.setText(JSON.stringify({ active: "#00ff00" }))
        } else {
            tick.stop()
            check("live reload", same(c.accent, "#00ff00") && same(c.background, "#101010"), c.accent)
            if (t.failures === 0) console.log("THEME OK")
            Qt.quit()
        }
    }
}
