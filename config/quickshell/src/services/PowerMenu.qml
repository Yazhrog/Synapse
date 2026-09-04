import QtQuick
import Quickshell.Io
import "../"

// Power menu — vertical list of power action buttons.

Column {
    id: root
    spacing: 4
    width: parent.width
    focus: true

    property int selIndex: 0

    function reset() {
        root.selIndex = 0
        root.forceActiveFocus()
    }

    function activate(modelData) {
        if (modelData.confirm) {
            // Close menu first, then show confirm dialog
            Popups.closeAll()
            Popups.showConfirm(
                modelData.title,
                modelData.message,
                modelData.label2,
                modelData.action
            )
        } else {
            root.runDirect(modelData.action)
        }
    }

    Keys.onUpPressed:     root.selIndex = (root.selIndex <= 0) ? root.actions.length - 1 : root.selIndex - 1
    Keys.onDownPressed:   root.selIndex = (root.selIndex >= root.actions.length - 1) ? 0 : root.selIndex + 1
    Keys.onReturnPressed: root.activate(root.actions[root.selIndex])
    Keys.onEnterPressed:  root.activate(root.actions[root.selIndex])
    Keys.onEscapePressed: Popups.archMenuOpen = false
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_PageUp) {
            root.selIndex = 0
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            root.selIndex = root.actions.length - 1
            event.accepted = true
        }
    }

    readonly property var actions: [
        {
            label:   "Lock        ",
            icon:    "󰌾",
            danger:  false,
            confirm: false,
            action:  "lock"
        },
        {
            label:   "Suspend ",
            icon:    "⏾",
            danger:  false,
            confirm: false,
            action:  "suspend"
        },
        {
            label:   "Log Out  ",
            icon:    "󰍃",
            danger:  true,
            confirm: true,
            title:   "Log Out?",
            message: "You will be logged out of your session. Save your work before continuing.",
            label2:  "Log Out",
            action:  "logout"
        },
        {
            label:   "Reboot     ",
            icon:    "↺",
            danger:  true,
            confirm: true,
            title:   "Reboot?",
            message: "Your computer will restart. Save your work before continuing.",
            label2:  "Reboot",
            action:  "reboot"
        },
        {
            label:   "Shutdown",
            icon:    "⏻",
            danger:  true,
            confirm: true,
            title:   "Shut Down?",
            message: "Your computer will power off. Save your work before continuing.",
            label2:  "Shut Down",
            action:  "shutdown"
        },
    ]

    // Direct runner for non-confirm actions
    Process {
        id: runner
        property var pendingCmd: []
        command: pendingCmd
        onRunningChanged: if (!running) pendingCmd = []
    }

    function runDirect(action) {
        switch (action) {
            case "lock":    runner.pendingCmd = ["loginctl", "lock-session"];    break
            case "suspend": runner.pendingCmd = ["systemctl", "suspend"];        break
        }
        runner.running = true
        Popups.archMenuOpen = false
    }

    Repeater {
        model: root.actions

        delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property bool isSel: root.selIndex === index
            readonly property bool highlighted: isSel || hov.hovered

            width:  root.width
            height: 44
            radius: Theme.cornerRadius
            color:  highlighted
                        ? (modelData.danger ? "#4d2020" : Theme.active)
                        : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text:           modelData.icon
                    font.pixelSize: 16
                    color:          modelData.danger && highlighted ? "#ff6b6b" : highlighted?"#000000":Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text:           modelData.label
                    font.pixelSize: 13
                    color:          modelData.danger && highlighted ? "#ff6b6b" : highlighted?"#000000":Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.selIndex = index
                onClicked: root.activate(modelData)
            }
        }
    }
}
