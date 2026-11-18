pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// PowerService — lock, suspend, log out, reboot and shut down.
//
// Lock and suspend run at once; log out, reboot and shut down go through
// scripts/PowerControl.sh (hyprshutdown, then the systemd action). Asking
// first is the caller's job (the power menu's ConfirmDialog).
Singleton {
    id: root

    readonly property var actions: ["lock", "suspend", "logout", "reboot", "shutdown"]

    function lock()     { _queue.enqueue(["loginctl", "lock-session"]) }
    function suspend()  { _queue.enqueue(["systemctl", "suspend"]) }
    function logout()   { _queue.enqueue(["bash", _script, "logout"]) }
    function reboot()   { _queue.enqueue(["bash", _script, "reboot"]) }
    function shutdown() { _queue.enqueue(["bash", _script, "shutdown"]) }

    // One of `actions` by name; false for an unknown one.
    function run(action: string): bool {
        if (actions.indexOf(action) === -1) return false
        root[action]()
        return true
    }

    // ── Implementation ──────────────────────────────────────────────────────
    readonly property string _script: Quickshell.shellDir + "/src/scripts/PowerControl.sh"

    property ExecQueue _queue: ExecQueue {}
}
