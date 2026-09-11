import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Blocking critical-battery modal — driven by Popups.batteryCritical*.
// Unlike ConfirmDialog, this has NO click-outside or Escape dismiss: the
// battery is critically low, so it forces an explicit acknowledgement
// rather than letting the user accidentally click past it.

PanelWindow {
    id: root

    color: "transparent"

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    visible: Popups.batteryCriticalOpen

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
        radius: Theme.notchRadius
        color:  Theme.background
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
                text:           "Critical Battery"
                color:          "#ff4444"
                font.pixelSize: 15
                font.bold:      true
            }

            Text {
                width:          parent.width
                text:           "Battery at " + Popups.batteryCriticalLevel + "% — plug in now to avoid losing your work."
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
                radius: Theme.cornerRadius
                color:  ackHov.hovered ? "#cc3a3a" : "#993030"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text:           "Acknowledge"
                    color:          "white"
                    font.pixelSize: 13
                    font.bold:      true
                }

                HoverHandler { id: ackHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: Popups.acknowledgeBatteryCritical() }
            }
        }
    }

    // Keyboard focus is grabbed (OnDemand) but deliberately has no
    // Escape/Return handling — only the Acknowledge button dismisses this.
    Item {
        anchors.fill: parent
        focus: root.visible
    }
}
