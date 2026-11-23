import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.src.components.base
import qs.src.services.system
import qs.src.state
import qs.src.theme
// UpdatePopup — centered overlay popup for shell update notifications.
// Same structural pattern as ConfirmDialog: PanelWindow Overlay, dim background,
// centered fixed-size card. Instantiated per-screen in shell.qml.
//
// States:
//   checking      — spinner in header, no body (checking is brief, usually invisible)
//   available     — commit list + Update / Skip / Disable buttons
//   updating      — spinner, please wait text
//   conflict      — pull failed due to local changes: Stash & Update / Cancel
//   success       — Reload Shell / Dismiss (stays up; reloading is the point)
//   error         — classified error text + Retry / Close

PanelWindow {
    id: root

    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool windowVisible: false
    visible: windowVisible

    PopupFocusGrab {
        window:         root
        active:         UpdateService.showPopup
        dismissOnClear: false
        onFocused:      escHandler.forceActiveFocus()
    }
    
    Connections {
        target: UpdateService
        function onShowPopupChanged() {
            if (UpdateService.showPopup) {
                // Overlay-layer popup — close the dashboard so it can't
                // cover this and block input to it.
                Popups.close("dashboard")
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }
    
    Timer {
        id: closeTimer
        interval: 20
        onTriggered: if (!UpdateService.showPopup) root.windowVisible = false
    }

    // The success state is not auto-dismissed: it holds the Reload Shell button,
    // which is the step that actually puts the update on screen.

    // ── Dim overlay ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.50)
        // Pass through clicks in the dim area — update is non-blocking
        MouseArea {
            anchors.fill: parent
            // Intentionally no action — user must use the card buttons
        }
    }

    // ── Card ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  380
        radius: Theme.radius.notch
        color:  Theme.color.background
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // Size to content
        height: cardCol.implicitHeight + 48

        // Prevent clicks from hitting the dim MouseArea
        MouseArea { anchors.fill: parent }

        Item {
            visible: !UpdateService.updating
            anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
            width: 24; height: 24
        
            Rectangle {
                anchors.fill: parent; radius: 6
                color: xHov.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            Text {
                anchors.centerIn: parent
                text: "✕"; font.pixelSize: 11
                color: Qt.rgba(1,1,1,0.35)
            }
            HoverHandler { id: xHov; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: UpdateService.dismiss() }
        }

        Column {
            id: cardCol
            anchors {
                top:         parent.top;   topMargin:   24
                left:        parent.left;  leftMargin:  22
                right:       parent.right; rightMargin: 18
            }
            spacing: 12

            // ── Header row ────────────────────────────────────────────────────
            UpdateHeader { width: parent.width }

            Rectangle {
                width: parent.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.07)
            }

            // ── AVAILABLE ─────────────────────────────────────────────────────
            Column {
                visible: UpdateService.updateAvailable &&
                         !UpdateService.updating &&
                         !UpdateService.hasConflict &&
                         !UpdateService.updateSuccess &&
                         UpdateService.lastError === ""
                width:   parent.width
                spacing: 10

                Text {
                    text: UpdateService.commitsBehind + " new commit" +
                          (UpdateService.commitsBehind === 1 ? "" : "s") + " on main"
                    font.pixelSize: 12
                    color: Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                }

                UpdateCommitList { width: parent.width }

                Row {
                    spacing: 8
                    PillButton {
                        width: 108; label: "Update Now"; medium: true
                        tint: Theme.color.accent; restAlpha: 0.13; hoverAlpha: 0.26; borderAlpha: 0.40
                        textColor: Theme.color.accent
                        onClicked: UpdateService.applyUpdate()
                    }
                    // Skip (dismiss this check)
                    PillButton { width: 58; label: "Skip"; onClicked: UpdateService.dismiss() }
                    // Disable auto-update
                    PillButton {
                        width: 82; label: "Disable"
                        restAlpha: 0; hoverAlpha: 0.06; borderAlpha: 0.07; textColor: Qt.rgba(1, 1, 1, 0.28)
                        onClicked: UpdateService.disableAutoUpdate()
                    }
                }
            }

            // ── UPDATING ──────────────────────────────────────────────────────
            Column {
                visible: UpdateService.updating
                width:   parent.width
                spacing: 6

                Text {
                    text:           "Pulling latest changes from origin/main…"
                    font.pixelSize: 12
                    color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                    wrapMode:       Text.WordWrap
                    width:          parent.width
                }
                Text {
                    text:           "Do not close the shell."
                    font.pixelSize: 10
                    color:          Qt.rgba(1, 1, 1, 0.25)
                }
            }

            // ── CONFLICT ──────────────────────────────────────────────────────
            Column {
                visible: UpdateService.hasConflict && !UpdateService.updating
                width:   parent.width
                spacing: 12

                Text {
                    text: "Local uncommitted changes conflict with the update.\n" +
                          "Stash them aside to proceed, or cancel."
                    font.pixelSize: 12
                    color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                    wrapMode:       Text.WordWrap
                    width:          parent.width
                    lineHeight:     1.45
                }

                Row {
                    spacing: 8
                    PillButton {
                        width: 128; label: "Stash & Update"; medium: true
                        tint: "#f5c47a"; restAlpha: 0.10; hoverAlpha: 0.22; borderAlpha: 0.38
                        textColor: "#f5c47a"
                        onClicked: UpdateService.stashAndUpdate()
                    }
                    PillButton { width: 72; label: "Cancel"; onClicked: UpdateService.dismiss() }
                }
            }

            // ── SUCCESS ───────────────────────────────────────────────────────
            Column {
                visible: UpdateService.updateSuccess
                width:   parent.width
                spacing: 12

                Text {
                    text: {
                        var hasPkgList = UpdateService.needsFullInstall &&
                            (UpdateService.newPackages.length > 0 || UpdateService.removedPackages.length > 0)
                        if (hasPkgList) {
                            var msg = "New packages required: " + UpdateService.newPackages.join(", ")
                            if (UpdateService.removedPackages.length > 0)
                                msg += "\n(no longer needed: " + UpdateService.removedPackages.join(", ") + ")"
                            return msg + "\nRe-run ./boot.sh to finish."
                        }
                        return UpdateService.needsFullInstall
                            ? "Update applied.\nThis release changes packages or the deploy map — re-run ./boot.sh to finish."
                            : "Update applied and re-linked.\nReload to see the changes."
                    }
                    font.pixelSize: 12
                    color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                    wrapMode:       Text.WordWrap
                    width:          parent.width
                    lineHeight:     1.45
                }

                Row {
                    spacing: 8
                    // Reload Shell — hyprctl reload + quickshell restart
                    PillButton {
                        width: 108; label: "Reload Shell"; medium: true
                        tint: Theme.color.accent; restAlpha: 0.13; hoverAlpha: 0.26; borderAlpha: 0.40
                        textColor: Theme.color.accent
                        onClicked: UpdateService.reloadShell()
                    }
                    PillButton { width: 72; label: "Dismiss"; onClicked: UpdateService.dismiss() }
                }
            }

            // ── ERROR ─────────────────────────────────────────────────────────
            Column {
                visible: UpdateService.lastError !== "" &&
                         !UpdateService.updating &&
                         !UpdateService.hasConflict
                width:   parent.width
                spacing: 12

                Text {
                    text:           UpdateService.lastError
                    font.pixelSize: 12
                    color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                    wrapMode:       Text.WordWrap
                    width:          parent.width
                }

                Row {
                    spacing: 8
                    PillButton {
                        width: 72; label: "Retry"
                        tint: Theme.color.accent; restAlpha: 0.09; hoverAlpha: 0.22; borderAlpha: 0.30
                        textColor: Theme.color.accent
                        onClicked: UpdateService.check()
                    }
                    PillButton { width: 72; label: "Close"; onClicked: UpdateService.dismiss() }
                }
            }
        }
    }

    // Escape to dismiss (same as ConfirmDialog)
    Item {
        id:           escHandler
        anchors.fill: parent
        focus:        root.visible
        Keys.onEscapePressed: {
            if (!UpdateService.updating) UpdateService.dismiss()
        }
    }
}
