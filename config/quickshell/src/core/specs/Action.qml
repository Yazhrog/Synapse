import QtQuick

// Action — one user-triggerable command (ARCHITECTURE.md §5.6).
//
//   Action { key: "clipboard-toggle"; label: "Clipboard"; group: "Popups"
//            run: () => Popups.toggle("clipboard") }
//
// `key` is the IPC target (`qs ipc call <key> toggle`) and the
// keybind-defaults.json / keybinds.json key. Listed in app/ActionManifest.qml,
// or generated there from a page registry (PageSpec.action).
QtObject {
    required property string key
    property string label: key
    property string group: "Other"
    property var    run:   () => {}
}
