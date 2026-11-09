import QtQuick
import Quickshell
import "../"
import "../components"

// HotspotTab — config editor for the hotspot SSID/password.
// The start/stop toggle is the Quick Settings tile; both use HotspotService,
// which stores the credentials in src/user_data/hotspot.json.

Item {
    id: root

    property string _ssid:      HotspotService.ssid
    property string _password:  HotspotService.password
    property bool   _showPass:  false
    property bool   _dirty:     false   // unsaved changes

    function _save() { HotspotService.saveConfig(root._ssid, root._password) }

    Connections {
        target: HotspotService
        function onConfigLoaded() {
            root._ssid     = HotspotService.ssid
            root._password = HotspotService.password
        }
        function onConfigSaved() { root._dirty = false }
    }

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen && root.visible)
                HotspotService.loadConfig()
        }
    }

    Component.onCompleted: HotspotService.loadConfig()

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent; spacing: 0

        // Header
        Item {
            width: parent.width; height: 40
            Text { anchors { left: parent.left; leftMargin: 2
            verticalCenter: parent.verticalCenter }
            text: "Hotspot"
            font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }

            // Active indicator
            Row {
                anchors { left: parent.left; leftMargin: 76;
                verticalCenter: parent.verticalCenter }
                spacing: 6
                Rectangle { width: 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: HotspotService.on ? Theme.active : Qt.rgba(1,1,1,0.22); Behavior on color { ColorAnimation { duration: 200 } } }
                Text { anchors.verticalCenter: parent.verticalCenter; text: HotspotService.on ? "Active" : "Inactive"; font.pixelSize: 11; color: HotspotService.on ? Theme.active : Qt.rgba(1,1,1,0.32) }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item { width: parent.width; height: 8 }

        Flickable {
            width: parent.width; height: parent.height - 49
            contentWidth: width; contentHeight: mainCol.implicitHeight + 8
            clip: true; boundsBehavior: Flickable.StopAtBounds

            Column {
                id: mainCol; width: parent.width; spacing: 14

                // Info banner
                Rectangle {
                    width: parent.width; height: infoCol.implicitHeight + 16; radius: Theme.cornerRadius
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.06)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18); border.width: 1

                    Column {
                        id: infoCol;
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 4
                        Text { width: parent.width; text: "󰀃  Toggle hotspot from the Quick Settings panel."; font.pixelSize: 11; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7); wrapMode: Text.WordWrap }
                        Text { width: parent.width; text: "Requires an ethernet connection. Shares the same WiFi channel as your current connection."; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.30); wrapMode: Text.WordWrap; lineHeight: 1.4 }
                    }
                }

                // Config card
                Rectangle {
                    width: parent.width; height: cfgCol.implicitHeight + 20; radius: Theme.cornerRadius
                    color: Qt.rgba(1,1,1,0.04); border.color: Qt.rgba(1,1,1,0.07); border.width: 1

                    Column {
                        id: cfgCol; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 12

                        Text { text: "CREDENTIALS"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) }

                        // SSID
                        Item {
                            width: parent.width; height: 32
                            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "SSID"; font.pixelSize: 11; font.weight: Font.Medium; color: Qt.rgba(1,1,1,0.45); width: 72 }
                            Rectangle {
                                anchors { left: parent.left; leftMargin: 76; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: 28; radius: 7
                                color: ssidInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08) : Qt.rgba(1,1,1,0.05)
                                border.color: ssidInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45) : Qt.rgba(1,1,1,0.11); border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                TextInput {
                                    id: ssidInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 12
                                    selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                                    clip: true; maximumLength: 32
                                    text: root._ssid
                                    onTextChanged: { root._ssid = text; root._dirty = true }
                                }
                            }
                        }

                        // Password
                        Item {
                            width: parent.width; height: 32
                            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: "Password"; font.pixelSize: 11; font.weight: Font.Medium; color: Qt.rgba(1,1,1,0.45); width: 72 }
                            Rectangle {
                                anchors { left: parent.left; leftMargin: 76; right: eyeBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                height: 28; radius: 7
                                color: passInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08) : Qt.rgba(1,1,1,0.05)
                                border.color: passInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45) : Qt.rgba(1,1,1,0.11); border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                TextInput {
                                    id: passInput; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 12
                                    selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                                    echoMode: root._showPass ? TextInput.Normal : TextInput.Password
                                    clip: true; maximumLength: 63
                                    text: root._password
                                    onTextChanged: { root._password = text; root._dirty = true }
                                }
                            }
                            Item {
                                id: eyeBtn; anchors { right: parent.right;
                                verticalCenter: parent.verticalCenter }
                                width: 28; height: 28
                                Rectangle { anchors.fill: parent; radius: 6; color: eyeH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent" }
                                Text { anchors.centerIn: parent; text: root._showPass ? "" : ""; font.pixelSize: 13; color: root._showPass ? Theme.active : Qt.rgba(1,1,1,0.28) }
                                HoverHandler { id: eyeH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root._showPass = !root._showPass }
                            }
                        }

                        // Save button — only visible when dirty
                        Rectangle {
                            visible: root._dirty
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 90; height: 28; radius: 8
                            color: saveH.hovered
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                                : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.active }
                            HoverHandler { id: saveH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._save() }
                        }
                    }
                }

                Item { width: parent.width; height: 4 }
            }
        }
    }
}
