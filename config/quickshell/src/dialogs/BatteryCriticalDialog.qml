import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.state
import qs.src.theme
// Blocking alert modal (the critical battery) — renders Dialogs.alertRequest
// ({ title, message, label }); Acknowledge calls Dialogs.acknowledge().
// Unlike ConfirmDialog, this has NO click-outside or Escape dismiss: the
// battery is critically low, so it forces an explicit acknowledgement
// rather than letting the user accidentally click past it.

PanelWindow {
    id: root

    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    readonly property var request: Dialogs.alertRequest

    visible: Dialogs.alertOpen

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    PopupFocusGrab {
        window:         root
        active:         Dialogs.alertOpen
        dismissOnClear: false
        onFocused:      keySink.forceActiveFocus()
    }

    // ── Dim overlay — no click-to-dismiss ────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
    }

    // ── Dialog ────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.centerIn: parent
        width:  360
        height: col.implicitHeight + 48
        radius: Theme.radius.notch
        color:  Theme.color.background
        border.color: "#ff4444"
        border.width: 1

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
                text:           "⚠"
                color:          "#ff4444"
                font.pixelSize: 32
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           root.request?.title ?? ""
                color:          "#ff4444"
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                width:          parent.width
                text:           root.request?.message ?? ""
                color:          Qt.rgba(1, 1, 1, 0.65)
                font.pixelSize: 12
                wrapMode:       Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight:     1.4
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  130
                height: 38
                radius: Theme.radius.card
                color:  ackHov.hovered ? "#cc3a3a" : "#993030"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text:           root.request?.label ?? "Acknowledge"
                    color:          "white"
                    font.pixelSize: 13
                    font.bold:      true
                }

                HoverHandler { id: ackHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: Dialogs.acknowledge() }
            }
        }
    }

    // Keyboard focus is grabbed (PopupFocusGrab) but deliberately has no
    // Escape/Return handling — only the Acknowledge button dismisses this.
    Item {
        id:           keySink
        anchors.fill: parent
        focus: root.visible
    }
}
