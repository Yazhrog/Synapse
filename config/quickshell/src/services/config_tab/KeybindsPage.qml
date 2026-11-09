import QtQuick
import QtQuick.Controls
import "../"
import "../../"

// KeybindsPage — Config → Keybinds: every shell action by group, one
// KeybindRow each. Changes are staged as pending (amber) until Save; the
// banner shows how many. While a row captures, KeybindService.isCapturing
// puts Hyprland in a pass-through submap so the keys reach the shell.

Item {
    id: root

    // ── Capture state ─────────────────────────────────────────────────────────
    // The action whose row is recording a combo, "" = none
    property string capturingAction: ""
    readonly property bool anyCapturing: capturingAction !== ""

    // Keep KeybindService in sync so external handlers can observe it.
    // In ShellState / Popups, watch KeybindService.isCapturing and dispatch:
    //   true  →  hyprctl dispatch submap, clean
    //   false →  hyprctl dispatch submap, reset
    onAnyCapturingChanged: KeybindService.isCapturing = anyCapturing

    // ── Pending changes ───────────────────────────────────────────────────────
    property var  _pending:   ({})
    readonly property bool hasPending: Object.keys(_pending).length > 0

    // Used by the rows
    function addPending(action, mods, key) {
        var copy = Object.assign({}, _pending)
        copy[action] = { mods: mods, key: key }
        _pending = copy
    }

    function clearPending(action) {
        var copy = Object.assign({}, _pending)
        delete copy[action]
        _pending = copy
    }

    // Label of another action whose pending combo is mods + key, "" if none
    function pendingConflict(action, mods, key) {
        var combo = mods + "+" + key
        var pkeys = Object.keys(_pending)
        for (var i = 0; i < pkeys.length; i++) {
            if (pkeys[i] === action) continue
            var p = _pending[pkeys[i]]
            if (p.mods + "+" + p.key === combo) {
                var lbl = KeybindService.keybinds[pkeys[i]]
                return (lbl ? lbl.label : pkeys[i]) + " (pending)"
            }
        }
        return ""
    }

    function _applyPending() {
        var ks = Object.keys(_pending)
        for (var i = 0; i < ks.length; i++) {
            var m = _pending[ks[i]].mods
            var k = _pending[ks[i]].key
            if (m === "" && k === "") {
                KeybindService.unbindBinding(ks[i])
            } else {
                KeybindService.updateBinding(ks[i], m, k)
            }
        }
        _pending = {}
        KeybindService.saveAndReload()
    }

    // ── Groups ────────────────────────────────────────────────────────────────
    readonly property var _groups: {
        var groups = {}; var order = []
        var defs = KeybindService._defaults
        var ks   = Object.keys(defs)
        for (var i = 0; i < ks.length; i++) {
            var g = defs[ks[i]].group
            if (!groups[g]) { groups[g] = []; order.push(g) }
            groups[g].push(ks[i])
        }
        return order.map(function(g) { return { name: g, actions: groups[g] } })
    }

    // ── Save banner ───────────────────────────────────────────────────────────
    Rectangle {
        id: _saveBanner
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.hasPending ? 44 : 0
        clip:   true
        color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
        border.width: root.hasPending ? 1 : 0
        radius: 8

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
            spacing: 8
            visible: root.hasPending

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var n = Object.keys(root._pending).length
                    return n + " unsaved change" + (n > 1 ? "s" : "")
                }
                font.pixelSize: 11
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.70)
            }

            // Discard
            Rectangle {
                width: 62; height: 26; radius: 7
                color: _discardH.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                border.color: Qt.rgba(1,1,1,0.13); border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Discard"; font.pixelSize: 10
                    color: Qt.rgba(1,1,1,0.48) }
                HoverHandler { id: _discardH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._pending = {} }
            }

            // Save
            Rectangle {
                width: 62; height: 26; radius: 7
                color: _saveH.hovered
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.42)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 10
                    font.weight: Font.Medium; color: Theme.active }
                HoverHandler { id: _saveH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._applyPending() }
            }
        }
    }

    // ── Scrollable list ───────────────────────────────────────────────────────
    Flickable {
        anchors {
            top:         _saveBanner.bottom
            left:        parent.left
            right:       parent.right
            bottom:      parent.bottom
            leftMargin:  12
            rightMargin: 12
            bottomMargin: 12
            topMargin:   6
        }
        contentWidth:   width
        contentHeight:  _col.implicitHeight + 16
        clip:           true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 3; implicitHeight: 40; radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }
            background: Item {}
        }

        Column {
            id: _col
            width:   parent.width - 12
            spacing: 2

            Repeater {
                model: root._groups
                delegate: Column {
                    required property var modelData
                    required property int index
                    width:   _col.width
                    spacing: 2

                    Item {
                        width:  parent.width
                        height: index > 0 ? 30 : 16
                        Text {
                            anchors.bottom:       parent.bottom
                            anchors.bottomMargin: 4
                            text:           modelData.name
                            font.pixelSize: 9
                            font.weight:    Font.Bold
                            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                        }
                    }

                    Repeater {
                        model: modelData.actions
                        delegate: KeybindRow {
                            id: _br
                            required property string modelData
                            page:         root
                            width:        _col.width
                            action:       modelData
                            isCapturing:  root.capturingAction === modelData
                            pendingCombo: root._pending[modelData] || null
                            onRequestCapture: root.capturingAction = modelData
                            onReleaseCapture: root.capturingAction = ""
                            onCaptureAccepted: function(newMods, newKey) {
                                root.addPending(_br.action, newMods, newKey)
                            }
                        }
                    }
                }
            }
        }
    }
}
