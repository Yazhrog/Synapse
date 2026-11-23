import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.services.system
import qs.src.state
import qs.src.theme
// Confirmation modal — renders Dialogs.confirmRequest ({ title, message,
// label, icon, onAccept }) and reports the choice to Dialogs, which runs the
// request's callback. While GpuModeService switches the GPU mode (after
// pkexec authenticated, until the reboot) it shows the processing card.

PanelWindow {
    id: root

    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    readonly property var request: Dialogs.confirmRequest

    visible: Dialogs.confirmOpen || root.running

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
        target: Dialogs
        function onConfirmRequestChanged() {
            if (Dialogs.confirmOpen) {
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

    // ── Choice ────────────────────────────────────────────────────────────────
    function confirm() { Dialogs.accept() }

    function cancel() {
        if (!root.running) Dialogs.cancel()
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
        radius: Theme.radius.notch
        color:  Theme.color.background
        visible: Dialogs.confirmOpen && !root.running

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
                text: root.request?.icon ?? "⚠️"
                color:          Theme.color.text
                font.pixelSize: 32
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           root.request?.title ?? ""
                color:          Theme.color.text
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                width:          parent.width
                text:           root.request?.message ?? ""
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
                    radius: Theme.radius.card
                    color:  highlighted ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: isSel ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.4)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           "Cancel"
                        color:          Theme.color.text
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
                    radius: Theme.radius.card
                    color:  highlighted ? "#cc3a3a" : "#993030"
                    border.width: isSel ? 1 : 0
                    border.color: "white"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text:           root.request?.label ?? "Confirm"
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
        radius: Theme.radius.notch
        color:  Theme.color.background
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
                color:          Theme.color.text
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
