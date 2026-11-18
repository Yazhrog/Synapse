pragma Singleton
import QtQuick
import Quickshell
// Dialogs — the modal requests, one at a time (a mediator between whoever
// asks and the dialog windows that render them).
//
//   Dialogs.confirm({
//       title:   "Reboot?",
//       message: "Your computer will restart.",
//       label:   "Reboot",                 // the confirm button
//       icon:    "↺",                      // default "⚠️"
//       onAccept: () => PowerService.reboot()
//   })
//   Dialogs.alert({ title: "Critical Battery", message: "…", label: "Acknowledge" })
//
// dialogs/ConfirmDialog renders `confirmRequest` and calls accept() or
// cancel(); dialogs/BatteryCriticalDialog renders `alertRequest` and calls
// acknowledge(). The work itself runs in the request's callback (a service).
// A request arriving while one is shown waits its turn. Showing a dialog
// closes the dashboard: both are on the Overlay layer and it would cover it.
Singleton {
    id: root

    readonly property var  confirmRequest: _confirms.length > 0 ? _confirms[0] : null
    readonly property bool confirmOpen:    confirmRequest !== null
    readonly property var  alertRequest:   _alerts.length > 0 ? _alerts[0] : null
    readonly property bool alertOpen:      alertRequest !== null

    function confirm(request: var) {
        _confirms = _confirms.concat([request])
        Popups.close("dashboard")
    }

    function alert(request: var) {
        _alerts = _alerts.concat([request])
        Popups.close("dashboard")
    }

    // The shown confirmation: closed first, then its callback runs.
    function accept() {
        const r = confirmRequest
        if (!r) return
        _confirms = _confirms.slice(1)
        if (r.onAccept) r.onAccept()
    }
    function cancel() {
        const r = confirmRequest
        if (!r) return
        _confirms = _confirms.slice(1)
        if (r.onCancel) r.onCancel()
    }

    function acknowledge() {
        const r = alertRequest
        if (!r) return
        _alerts = _alerts.slice(1)
        if (r.onAcknowledge) r.onAcknowledge()
    }

    property var _confirms: []
    property var _alerts:   []
}
