// Behaviour test of the popup lifecycle (state/SurfaceState, Popups,
// PopupLifecycle, Dialogs), with two throwaway popups registered the way
// App registers the manifest. Prints PASS/FAIL lines, then LIFECYCLE OK.
// Run by tests/smoke.sh.
import Quickshell
import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
ShellRoot {
    id: t

    // A throwaway popup: one spec, one line in a list (what PopupManifest does).
    readonly property list<PopupSpec> popups: [
        PopupSpec { key: "a"; region: "top" },
        PopupSpec { key: "b"; region: "bottomRight" }
    ]
    Binding { target: SurfaceState; property: "popups"; value: t.popups }

    property var events: []
    Connections {
        target: SurfaceState
        function onOpening(k, s) { t.events.push("opening " + k + "@" + s) }
        function onOpened(k, s)  { t.events.push("opened " + k + "@" + s) }
        function onClosing(k, s) { t.events.push("closing " + k + "@" + s) }
        function onClosed(k, s)  { t.events.push("closed " + k + "@" + s) }
    }
    property var helperEvents: []
    PopupLifecycle {
        id: helper
        popup: "a"; screen: "S1"
        onOpening: t.helperEvents.push("opening")
        onClosed:  t.helperEvents.push("closed")
    }

    property int failures: 0
    function check(name, cond, msg) {
        if (cond) console.log("PASS " + name)
        else { failures++; console.log("FAIL " + name + ": " + msg) }
    }
    readonly property int settle: Theme.animDuration + 120

    property var steps: [
        () => {
            check("registry", SurfaceState.regionOf.b === "bottomRight" && SurfaceState.specOf("a") !== null,
                  JSON.stringify(SurfaceState.regionOf))
            check("unknown popup refused", !Popups.open("nope", "S1"), "opened an unknown key")
            Popups.open("a", "S1")
            check("opening at once", SurfaceState.phaseOf("a", "S1") === "opening" && Popups.isOpen("a"),
                  SurfaceState.phaseOf("a", "S1"))
            check("helper phase", helper.phase === "opening", helper.phase)
        },
        () => {
            check("open after the animation", SurfaceState.phaseOf("a", "S1") === "open", SurfaceState.phaseOf("a", "S1"))
            Popups.open("b", "S1")      // replaces a
            check("replaced popup closing", SurfaceState.phaseOf("a", "S1") === "closing"
                  && SurfaceState.phaseOf("b", "S1") === "opening" && !Popups.isOpen("a"),
                  SurfaceState.phaseOf("a", "S1") + "/" + SurfaceState.phaseOf("b", "S1"))
        },
        () => {
            check("replaced popup closed", SurfaceState.phaseOf("a", "S1") === "closed", SurfaceState.phaseOf("a", "S1"))
            Popups.close("a")            // stale close: b stays
            check("stale close ignored", Popups.isOpen("b"), "b closed by close('a')")
            Popups.close()
            Popups.open("b", "S1")       // reopened while closing
        },
        () => {
            check("reopen while closing", SurfaceState.phaseOf("b", "S1") === "open"
                  && t.events.indexOf("closed b@S1") < 0, JSON.stringify(t.events))
            Popups.closeAll()
        },
        () => {
            const want = ["opening a@S1", "opened a@S1", "closing a@S1", "opening b@S1", "opened b@S1",
                          "closed a@S1", "closing b@S1", "opening b@S1", "opened b@S1", "closing b@S1", "closed b@S1"]
            check("signal order", JSON.stringify(t.events) === JSON.stringify(want), JSON.stringify(t.events))
            check("PopupLifecycle", JSON.stringify(t.helperEvents) === '["opening","closed"]', JSON.stringify(t.helperEvents))

            let order = []
            Dialogs.confirm({ title: "one", onAccept: () => order.push("accept one") })
            Dialogs.confirm({ title: "two", onCancel: () => order.push("cancel two") })
            check("dialogs queue", Dialogs.confirmRequest.title === "one", Dialogs.confirmRequest?.title)
            Dialogs.accept()
            check("dialogs next", Dialogs.confirmRequest.title === "two", Dialogs.confirmRequest?.title)
            Dialogs.cancel()
            Dialogs.alert({ title: "battery", onAcknowledge: () => order.push("ack") })
            Dialogs.acknowledge()
            check("dialogs callbacks", JSON.stringify(order) === '["accept one","cancel two","ack"]'
                  && !Dialogs.confirmOpen && !Dialogs.alertOpen, JSON.stringify(order))
        }
    ]
    property int step: 0
    Timer {
        interval: t.settle; repeat: true; running: true
        onTriggered: {
            if (t.step < t.steps.length) { t.steps[t.step](); t.step++; return }
            if (t.failures === 0) console.log("LIFECYCLE OK")
            Qt.quit()
        }
    }
}
