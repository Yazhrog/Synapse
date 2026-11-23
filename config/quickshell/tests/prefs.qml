// Behaviour test of Prefs / PrefSchema: an old shell_prefs.json (written by
// the previous PrefsService, 4-space JSON, sorted keys, an unknown key and an
// out-of-range value) loads with every value kept, is validated on read,
// and is written back with the unknown key kept. Prints PASS/FAIL lines,
// then PREFS OK. Run by tests/smoke.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.core
import qs.src.services.data
ShellRoot {
    id: t

    readonly property string file: Paths.userData("shell_prefs.json")
    readonly property string oldText: JSON.stringify({
        alwaysShowBatteryPercentage: false, autoUpdate: false, backgroundBlur: true,
        backgroundOpacity: 85, barStyle: "pills", borderWidth: 99, cornerRadius: 17,
        defaultAudioPage: "mixer", someFutureKey: "kept", surfaceScale: "auto",
        use24HourClock: false
    }, null, 4)

    property int failures: 0
    function check(name, cond, msg) {
        if (cond) console.log("PASS " + name)
        else { failures++; console.log("FAIL " + name + ": " + msg) }
    }

    FileView { id: seed; path: t.file; atomicWrites: true; onSaved: t.step = 1 }
    FileView { id: reread; path: t.file; blockLoading: true }

    property int step: 0
    onStepChanged: if (step === 1) wait.start()

    Component.onCompleted: seed.setText(oldText)

    Timer {
        id: wait
        interval: 150; repeat: true
        onTriggered: {
            if (!Prefs.ready) return
            stop()
            const d = Prefs.data
            check("old values kept", d.backgroundOpacity === 85 && d.barStyle === "pills" && d.autoUpdate === false
                  && d.use24HourClock === false && d.defaultAudioPage === "mixer" && d.surfaceScale === "auto",
                  JSON.stringify(d))
            check("missing keys default", d.enableVisualiser === true && d.avatarPath === ""
                  && JSON.stringify(d.barLayout) === "{}", JSON.stringify(d))
            check("validated on read", d.borderWidth === 16, "borderWidth " + d.borderWidth)
            check("isDefault", Prefs.isDefault("cornerRadius") && !Prefs.isDefault("barStyle"), "")

            let borderNotified = 0
            const onBorder = () => borderNotified++
            Prefs.data.borderWidthChanged.connect(onBorder)
            Prefs.set("backgroundOpacity", 70)
            Prefs.data.borderWidthChanged.disconnect(onBorder)
            check("only the changed key notifies", borderNotified === 0 && Prefs.data.backgroundOpacity === 70,
                  "borderWidth notified " + borderNotified + " times")

            Prefs.set("barStyle", "nonsense")
            check("strict option rejected", Prefs.data.barStyle === "frame", Prefs.data.barStyle)
            Prefs.set("backgroundOpacity", 10)
            check("clamped on write", Prefs.data.backgroundOpacity === 50, Prefs.data.backgroundOpacity)
            Prefs.reset("backgroundOpacity")
            check("reset", Prefs.data.backgroundOpacity === 100, Prefs.data.backgroundOpacity)
            saved.start()
        }
    }

    Timer {
        id: saved
        interval: 800      // past the 300 ms save debounce
        onTriggered: {
            reread.reload()
            let doc = {}
            try { doc = JSON.parse(reread.text()) } catch (e) {}
            check("unknown key kept on write", doc.someFutureKey === "kept", reread.text())
            check("written values", doc.barStyle === "frame" && doc.backgroundOpacity === 100, reread.text())
            if (t.failures === 0) console.log("PREFS OK")
            Qt.quit()
        }
    }
}
