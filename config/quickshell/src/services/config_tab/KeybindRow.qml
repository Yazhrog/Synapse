import QtQuick
import "../"
import "../../"
import "keynames.js" as KeyNames

// KeybindRow — one shell action on Config → Keybinds: its label, the bind
// pill (amber while a change is pending), clear and reset buttons, and a
// capture mode that records the next key combo. A valid combo (with a
// modifier, no conflict) is accepted at once; a conflict is shown and the
// capture stays open. Bare Escape cancels.

Item {
    id: br

    // The KeybindsPage: who is capturing, the pending changes
    required property Item page

    property string action:      ""
    property bool   isCapturing: false
    property var    pendingCombo: null   // { mods, key } or null

    signal requestCapture()
    signal releaseCapture()
    signal captureAccepted(string newMods, string newKey)

    // Capture internals
    property int    _pressedMods: 0
    property string _liveMods:    ""
    property string capturedMods: ""
    property string capturedKey:  ""

    // Derived from service + pending
    readonly property var    _b:         KeybindService.keybinds[action]
    readonly property var    _def:       KeybindService._defaults[action]
    readonly property bool _isUnbound: br._pillText === "Unbound"
    readonly property bool   _isPending: br.pendingCombo !== null && br.pendingCombo !== undefined
    readonly property bool   _isDefault: {
        if (!br._def) return true
        var m = br._isPending ? br.pendingCombo.mods : (br._b ? br._b.mods : "")
        var k = br._isPending ? br.pendingCombo.key  : (br._b ? br._b.key  : "")
        return m === br._def.mods && k === br._def.key
    }
    readonly property string _bindText: {
        if (!br._b || br._b.key === "") return "Unbound"
        return br._b.mods ? br._b.mods + " + " + br._b.key : br._b.key
    }
    // Show pending value in the pill when set
    readonly property string _pillText: {
        if (br._isPending) {
            if (br.pendingCombo.key === "") return "Unbound"
            return br.pendingCombo.mods ? br.pendingCombo.mods + " + " + br.pendingCombo.key : br.pendingCombo.key
        }
        return br._bindText
    }
    readonly property bool   _savedDupe: KeybindService.isDuplicate(action)

    readonly property bool _interactive: br.page.capturingAction === "" || br.isCapturing

    // Live conflict: service binds → pending map → Hyprland binds (in that order)
    readonly property string _conflictLabel: {
        if (!br.capturedKey) return ""
        var c = KeybindService.wouldConflict(br.action, br.capturedMods, br.capturedKey)
        if (c !== "") return c
        var p = br.page.pendingConflict(br.action, br.capturedMods, br.capturedKey)
        if (p !== "") return p
        return KeybindService.wouldConflictHypr(br.action, br.capturedMods, br.capturedKey)
    }
    readonly property bool _hasConflict: _conflictLabel !== ""

    height: isCapturing ? 58 : 36
    clip: true
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    onIsCapturingChanged: {
        if (isCapturing) {
            br._pressedMods = 0
            br._liveMods    = ""
            br.capturedMods = ""
            br.capturedKey  = ""
            KeybindService.loadHyprBinds()   // refresh for conflict detection
            Qt.callLater(function() { _captureArea.forceActiveFocus() })
        }
    }

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: br.isCapturing
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
            : _rH.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        border.color: br._savedDupe
            ? Qt.rgba(248/255, 113/255, 113/255, 0.35)
            : br.isCapturing
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // ── Invisible focus target for key capture ────────────────────────────
    Item {
        id: _captureArea
        anchors.fill: parent
        focus:   br.isCapturing
        visible: br.isCapturing

        Keys.onPressed: function(event) {
            event.accepted = true
            if (KeyNames.isModifier(event.key)) {
                br._liveMods = KeyNames.modsText(event.modifiers)
                return
            }
            br._pressedMods = event.modifiers
            br._liveMods    = KeyNames.modsText(event.modifiers)
        }

        Keys.onReleased: function(event) {
            event.accepted = true
            if (KeyNames.isModifier(event.key)) {
                if (!br.capturedKey) br._liveMods = KeyNames.modsText(event.modifiers)
                return
            }
            // Bare Escape = cancel without saving
            if (event.key === Qt.Key_Escape && br._pressedMods === Qt.NoModifier) {
                br.releaseCapture()
                return
            }
            var k = KeyNames.keyName(event.key)
            if (k !== "") {
                var m = KeyNames.modsText(br._pressedMods)
                br.capturedMods = m
                br.capturedKey  = k
                // Auto-accept when valid: has mods, no service conflict,
                // no pending-map conflict, no Hyprland conflict
                if (m !== ""
                    && KeybindService.wouldConflict(br.action, m, k) === ""
                    && KeybindService.wouldConflictHypr(br.action, m, k) === ""
                    && br.page.pendingConflict(br.action, m, k) === "") {
                    br.captureAccepted(m, k)
                    br.releaseCapture()
                }
                // else: stay open, show conflict warning
            }
        }
    }

    // ── Normal display ────────────────────────────────────────────────────
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  leftMargin: 10; rightMargin: 8 }
        height: 36
        visible: !br.isCapturing

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text:           br._b ? br._b.label : br.action
            font.pixelSize: 12
            color:          br._savedDupe ? "#f87171" : (br._isUnbound ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.68))
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 6

            // Saved duplicate warning
            Text {
                visible: br._savedDupe
                anchors.verticalCenter: parent.verticalCenter
                text:           "⚠ " + KeybindService.conflictsWith(br.action)
                font.pixelSize: 9
                color:          Qt.rgba(248/255, 113/255, 113/255, 0.75)
            }

            // Clear bind
            Rectangle {
                visible: br._pillText !== "Unbound"
                width: 22; height: 22; radius: 6
                color: _clrH.hovered ? Qt.rgba(1,1,1,0.09) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "󰩺"; font.pixelSize: 11
                    color: _clrH.hovered ? "#ff4444" : Qt.rgba(1,1,1,0.28) }
                HoverHandler { id: _clrH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: br._interactive
                    onClicked: {
                        br.page.addPending(br.action, "", "")
                    }
                }
            }

            // Reset to default
            Rectangle {
                visible: !br._isDefault
                width: 22; height: 22; radius: 6
                color: _rstH.hovered ? Qt.rgba(1,1,1,0.09) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 11
                    color: _rstH.hovered ? Theme.active : Qt.rgba(1,1,1,0.28) }
                HoverHandler { id: _rstH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: br._interactive
                    onClicked: {
                        if (br._isPending) {
                            // If the saved value is already default, just drop pending
                            var def = KeybindService._defaults[br.action]
                            if (br._b && br._b.mods === def.mods && br._b.key === def.key)
                                br.page.clearPending(br.action)
                            else
                                br.page.addPending(br.action, def.mods, def.key)
                        } else {
                            // No pending → immediate save (reset is always safe)
                            KeybindService.resetBinding(br.action)
                        }
                    }
                }
            }

            // Binding pill — amber tint when a pending change is staged
            Rectangle {
                height: 24; radius: 6
                width:  _pillT.implicitWidth + 18
                
                color: br._isUnbound
                    ? Qt.rgba(1, 1, 1, 0.04)
                    : ((_pillH.hovered && br._interactive)
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16)
                        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08))
                        
                border.color: br._isUnbound
                    ? Qt.rgba(1, 1, 1, 0.1)
                    : (br._isPending
                        ? Qt.rgba(1.0, 0.74, 0.22, 0.55)
                        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24))
                        
                border.width: 1
                
                opacity: br._interactive ? (br._isUnbound ? 0.7 : 1.0) : 0.4
                
                Behavior on color        { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on opacity      { NumberAnimation { duration: 120 } }

                Text {
                    id: _pillT
                    anchors.centerIn: parent
                    text:           br._pillText
                    font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                    font.italic:    br._isUnbound 
                    
                    color: br._isUnbound 
                        ? Qt.rgba(1, 1, 1, 0.45) 
                        : (br._isPending ? Qt.rgba(1.0, 0.74, 0.22, 1.0) : Theme.active)
                        
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                HoverHandler { id: _pillH; cursorShape: br._interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: br._interactive
                    onClicked: br.requestCapture()
                }
            }
        }
    }

    // ── Capture display ───────────────────────────────────────────────────
    Column {
        anchors { top: parent.top; left: parent.left; right: parent.right
                  leftMargin: 10; rightMargin: 8 }
        spacing: 0
        visible: br.isCapturing

        // Row 1: label + live capture pill + cancel
        Item {
            width: parent.width; height: 36

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text:           br._b ? br._b.label : br.action
                font.pixelSize: 12
                color:          Qt.rgba(1, 1, 1, 0.68)
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6

                // Live capture pill
                Rectangle {
                    height: 24; radius: 6
                    width:  Math.max(120, _capT.implicitWidth + 18)
                    color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08)
                    border.color: br._hasConflict
                        ? Qt.rgba(248/255, 113/255, 113/255, 0.55)
                        : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,
                                  br.capturedKey !== "" ? 0.40 : 0.18)
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        id: _capT
                        anchors.centerIn: parent
                        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                        color: br._hasConflict
                            ? "#f87171"
                            : br.capturedKey !== ""
                                ? Theme.active
                                : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
                        text: {
                            if (br.capturedKey !== "")
                                return (br.capturedMods ? br.capturedMods + " + " : "") + br.capturedKey
                            if (br._liveMods !== "")
                                return br._liveMods + " + ?"
                            return "Press a key..."
                        }
                    }
                }

                // Cancel — Escape also cancels
                Rectangle {
                    width: 28; height: 24; radius: 6
                    color: _cnH.hovered ? Qt.rgba(1,1,1,0.09) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10
                        color: Qt.rgba(1,1,1,0.38) }
                    HoverHandler { id: _cnH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: br.releaseCapture() }
                }
            }
        }

        // Row 2: conflict warning (fades in when there's a conflict)
        Item {
            width: parent.width; height: 22
            opacity: (br.capturedKey !== "" && br._hasConflict) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Text {
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                text:           "⚠  Conflicts with: " + br._conflictLabel
                font.pixelSize: 10
                color:          "#f87171"
            }
        }
    }

    HoverHandler { id: _rH; enabled: !br.isCapturing }
}
