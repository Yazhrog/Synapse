// Scene smoke test and golden-image capture.
//
// Loads every scene of lib/SceneList.qml, one after the other, in an
// offscreen window. Run by tests/smoke.sh (each scene must load without a QML
// error) and by tests/golden.sh, which sets SYNAPSE_GOLDEN_OUT: each scene is
// then also captured to <dir>/<name>.png after its animations settle.
import Quickshell
import QtQuick
ShellRoot {
    id: shell

    readonly property string outDir:  Quickshell.env("SYNAPSE_GOLDEN_OUT") ?? ""
    readonly property bool   capture: outDir !== ""
    // Long enough for every Behavior (animDuration 320 ms) and the first
    // service polls to settle.
    readonly property int    settle:  capture ? 1500 : 300

    SceneList { id: list }

    property int _index: -1
    readonly property var _scene: _index >= 0 && _index < list.scenes.length ? list.scenes[_index] : null

    function _next() {
        _index++
        if (_index >= list.scenes.length) {
            console.log("SMOKE OK")
            Qt.quit()
            return
        }
        _scene.setup()
        loader.sourceComponent = _scene.component
        settleTimer.restart()
    }

    function _done() {
        loader.sourceComponent = null
        Qt.callLater(_next)
    }

    FloatingWindow {
        implicitWidth: 1920; implicitHeight: 1080
        color: "transparent"

        // A scene with w/h set gets that size; otherwise the item keeps its
        // own size (implicit or set by itself) and the loader follows it.
        Loader {
            id: loader
            onLoaded: {
                const s = shell._scene
                if (s.w > 0) item.width  = s.w
                if (s.h > 0) item.height = s.h
            }
        }
    }

    Timer {
        id: settleTimer
        interval: shell.settle
        onTriggered: {
            const s = shell._scene
            if (!shell.capture) { shell._done(); return }
            if (!loader.item || loader.width <= 0 || loader.height <= 0) {
                console.log("GOLDEN SKIP " + s.name + " (empty)")
                shell._done(); return
            }
            const ok = loader.grabToImage(function(result) {
                result.saveToFile(shell.outDir + "/" + s.name + ".png")
                console.log("GOLDEN " + s.name + (s.clock ? " clock" : ""))
                shell._done()
            })
            if (!ok) { console.log("GOLDEN FAIL " + s.name); shell._done() }
        }
    }

    Component.onCompleted: _next()
}
