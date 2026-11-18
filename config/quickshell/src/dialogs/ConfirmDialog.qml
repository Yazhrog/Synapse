import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.services.data
import qs.src.services.system
import qs.src.state
import qs.src.theme
// Unified confirmation modal — renders Popups.confirm* and reports the choice.
// Call Popups.showConfirm() to open, Popups.cancelConfirm() to close.
//
// The confirmed action runs in its service:
//   "shutdown" / "reboot" / "logout" / "lock" / "suspend" → PowerService
//   "factory-reset"   → DataService.factoryReset() (deletes user data, restarts the shell)
//   "gpu-switch-envy" → GpuModeService.switchTo(<mode>), which reboots when done;
//                       while it switches (GpuModeService.switching, after pkexec
//                       authenticated) the dialog shows the processing card.

PanelWindow {
    id: root

    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    visible: Popups.confirmOpen || root.running

    property int selIndex: 0   // 0 = Cancel, 1 = Confirm

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Modal: a click outside (e.g. on another monitor) must not dismiss it.
    PopupFocusGrab {
        window:         root
        active:         root.visible
        dismissOnClear: false
        onFocused:      keyHandler.forceActiveFocus()
    }

    readonly property bool running: GpuModeService.switching

    Connections {
        target: Popups
        function onConfirmOpenChanged() {
            if (Popups.confirmOpen) {
                root.selIndex = 0
                keyHandler.forceActiveFocus()
            }
        }
    }

    Connections {
        target: GpuModeService
        function onSwitchingChanged() {
            if (GpuModeService.switching) keyHandler.forceActiveFocus()
        }
    }

    // ── Action dispatch ───────────────────────────────────────────────────────
    function confirm() {
        // Read the request before cancelConfirm() clears it.
        const action  = Popups.confirmAction
        const gfxMode = Popups.confirmGfxMode
        Popups.cancelConfirm()
        if (action === "factory-reset")        DataService.factoryReset()
        else if (action === "gpu-switch-envy") GpuModeService.switchTo(gfxMode)
        else                                   PowerService.run(action)
    }

    function cancel() {
        if (!root.running) Popups.cancelConfirm()
    }

    // ── Dim overlay ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: if (!root.running) root.cancel()
        }
    }

    // ── Confirm dialog ────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  360
        height: col.implicitHeight + 48
        radius: Theme.notchRadius
        color:  Theme.background
        visible: Popups.confirmOpen && !root.running

        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors {
                top:         parent.top
                left:        parent.left
                right:       parent.right
                topMargin:   24
                leftMargin:  24
                rightMargin: 24
            }
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    switch (Popups.confirmAction) {
                        case "shutdown":        return "⏻"
                        case "reboot":          return "↺"
                        case "logout":          return "⎋"
                        case "gpu-switch-envy": return "⚠️"
                        default:                return "⚠️"
                    }
                }
                color:          Theme.text
                font.pixelSize: 32
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           Popups.confirmTitle
                color:          Theme.text
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                width:          parent.width
                text:           Popups.confirmMessage
                color:          Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 12
                wrapMode:       Text.WordWrap
                textFormat:     Text.RichText
                lineHeight:     1.4
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    readonly property bool isSel: root.selIndex === 0
                    readonly property bool highlighted: isSel || cancelHov.hovered

                    width:  130
                    height: 38
                    radius: Theme.cornerRadius
                    color:  highlighted ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: isSel ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           "Cancel"
                        color:          Theme.text
                        font.pixelSize: 13
                    }

                    HoverHandler { id: cancelHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selIndex = 0
                        onClicked: root.cancel()
                    }
                }

                Rectangle {
                    readonly property bool isSel: root.selIndex === 1
                    readonly property bool highlighted: isSel || confirmHov.hovered

                    width:  130
                    height: 38
                    radius: Theme.cornerRadius
                    color:  highlighted ? "#cc3a3a" : "#993030"
                    border.width: isSel ? 1 : 0
                    border.color: "white"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           Popups.confirmLabel
                        color:          "white"
                        font.pixelSize: 13
                        font.bold:      true
                    }

                    HoverHandler { id: confirmHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.selIndex = 1
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }

    // ── Processing card ───────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  300
        height: processingCol.implicitHeight + 56
        radius: Theme.notchRadius
        color:  Theme.background
        visible: root.running

        MouseArea { anchors.fill: parent }

        Column {
            id: processingCol
            anchors {
                top:         parent.top
                left:        parent.left
                right:       parent.right
                topMargin:   28
                leftMargin:  24
                rightMargin: 24
            }
            spacing: 18

            Canvas {
                id: spinnerCanvas
                anchors.horizontalCenter: parent.horizontalCenter
                width:  40
                height: 40
                transformOrigin: Item.Center

                RotationAnimator {
                    target:      spinnerCanvas
                    from:        0
                    to:          360
                    duration:    900
                    loops:       Animation.Infinite
                    running:     root.running
                    easing.type: Easing.Linear
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2, cy = height / 2, r = 16
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.strokeStyle = "rgba(255,255,255,0.1)"
                    ctx.lineWidth   = 3
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI)
                    ctx.strokeStyle = "white"
                    ctx.lineWidth   = 3
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }

                Component.onCompleted: requestPaint()
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "Applying Changes"
                color:          Theme.text
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width:          parent.width
                text:           "Switching to <b>" + GpuModeService.targetMode + "</b> graphics mode.<br>"
                                + "Your system will reboot when finished."
                color:          Qt.rgba(1, 1, 1, 0.55)
                font.pixelSize: 12
                wrapMode:       Text.WordWrap
                textFormat:     Text.RichText
                lineHeight:     1.5
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  parent.width
                height: 1
                color:  Qt.rgba(1, 1, 1, 0.07)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "Do not turn off your computer."
                color:          Qt.rgba(1, 1, 1, 0.3)
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Escape / Enter
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.visible
        Keys.onLeftPressed:   root.selIndex = 0
        Keys.onRightPressed:  root.selIndex = 1
        Keys.onReturnPressed: root.selIndex === 0 ? root.cancel() : root.confirm()
        Keys.onEscapePressed: root.cancel()
    }
}
