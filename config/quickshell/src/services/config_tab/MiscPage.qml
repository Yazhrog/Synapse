import QtQuick
import "../../"

// MiscPage — Config → Misc.
//
// Currently just the update settings. disableAutoUpdate() used to be a one-way
// door with no UI to undo it; the toggle here binds to UpdateService.setAutoUpdate
// so checks can be turned back on without hand-editing update_prefs.json.
Item {
    id: root

    Column {
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   14
            leftMargin:  16
            rightMargin: 16
        }
        spacing: 14

        Text {
            text:           "Updates"
            font.pixelSize: 12
            font.weight:    Font.DemiBold
            color:          Theme.text
        }

        // ── Auto-update toggle ────────────────────────────────────────────
        Rectangle {
            width:        parent.width
            height:       58
            radius:       Theme.cornerRadius
            color:        Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            Column {
                anchors {
                    left:           parent.left
                    leftMargin:     14
                    right:          sw.left
                    rightMargin:    12
                    verticalCenter: parent.verticalCenter
                }
                spacing: 3

                Text {
                    text:           "Check for updates on startup"
                    font.pixelSize: 12
                    color:          Theme.text
                }
                Text {
                    width:          parent.width
                    text:           "Looks for new commits on origin/main 30s after login."
                    font.pixelSize: 10
                    color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                    elide:          Text.ElideRight
                }
            }

            // Pill switch
            Rectangle {
                id: sw
                anchors {
                    right:          parent.right
                    rightMargin:    14
                    verticalCenter: parent.verticalCenter
                }
                width:  42
                height: 24
                radius: 12
                color: UpdateService.autoUpdate
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                    : Qt.rgba(1, 1, 1, 0.07)
                border.color: UpdateService.autoUpdate
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                    : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 140 } }

                Rectangle {
                    width:  18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: UpdateService.autoUpdate ? parent.width - width - 3 : 3
                    color: UpdateService.autoUpdate ? Theme.active : Qt.rgba(1, 1, 1, 0.35)
                    Behavior on x     { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: UpdateService.setAutoUpdate(!UpdateService.autoUpdate)
                }
            }
        }

        // ── Manual check ──────────────────────────────────────────────────
        Row {
            spacing: 10

            Rectangle {
                width: 104; height: 30; radius: 8
                color: ckH.hovered
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.26)
                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.13)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: UpdateService.checking ? "Checking…" : "Check Now"
                    font.pixelSize: 11
                    font.weight:    Font.Medium
                    color:          Theme.active
                }
                HoverHandler { id: ckH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    enabled: !UpdateService.checking && !UpdateService.updating
                    onClicked: UpdateService.check()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 10
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.40)
                text: UpdateService.updateAvailable
                    ? UpdateService.commitsBehind + " update(s) pending"
                    : "Up to date"
            }
        }

        // ── Where the shell is running from ───────────────────────────────
        // Worth surfacing: every config in ~/.config symlinks into this path,
        // so it is what `git pull` updates.
        Column {
            width:   parent.width
            spacing: 3

            Text {
                text:           "Source repository"
                font.pixelSize: 10
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
            }
            Text {
                width:          parent.width
                text:           UpdateService._dir === "" ? "resolving…" : UpdateService._dir
                font.pixelSize: 11
                font.family:    "monospace"
                color:          Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.70)
                elide:          Text.ElideMiddle
            }
        }
    }
}
