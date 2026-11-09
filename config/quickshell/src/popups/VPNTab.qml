import QtQuick
import "../"
import "../components"
import "../components/network"

// VPNTab — the network popup's VPN page: WireGuard connections (one active
// at a time) and the kill switch. State and nmcli calls live in VpnService.

Item {
    id: root

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen && root.visible) VpnService.refresh()
        }
    }

    Component.onCompleted: VpnService.refresh()

    Column {
        anchors.fill: parent; spacing: 0

        // Header
        Item {
            width: parent.width; height: 40

            Text {
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                text: "VPN"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text
            }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Kill switch toggle
                Rectangle {
                    height: 28; radius: 14
                    width: ksRow.implicitWidth + 18
                    color: VpnService.killSwitch
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                        : ksH.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                    border.color: VpnService.killSwitch
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40)
                        : Qt.rgba(1,1,1,0.10)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Row {
                        id: ksRow; anchors.centerIn: parent; spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰒃"; font.pixelSize: 13
                            color: VpnService.killSwitch ? Theme.active : Qt.rgba(1,1,1,0.40)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Kill Switch"; font.pixelSize: 11; font.weight: Font.Medium
                            color: VpnService.killSwitch ? Theme.active : Qt.rgba(1,1,1,0.45)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                    }

                    HoverHandler { id: ksH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: VpnService.toggleKillSwitch() }
                }

                RefreshButton { busy: VpnService.loading; onClicked: VpnService.refresh() }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 8 }

        // Connection list
        Flickable {
            width: parent.width; height: parent.height - 49
            contentWidth: width; contentHeight: conCol.height
            clip: true; boundsBehavior: Flickable.StopAtBounds

            Column {
                id: conCol; width: parent.width; height: implicitHeight; spacing: 6

                // Active section
                Item {
                    width: parent.width; height: visible ? aLbl.implicitHeight + 4 : 0
                    visible: VpnService.connections.some(function(c) { return c.active })
                    Text {
                        id: aLbl; text: "ACTIVE"
                        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                    }
                }

                Repeater {
                    model: VpnService.connections.filter(function(c) { return c.active })
                    delegate: VpnConnectionRow {
                        required property var modelData
                        width: conCol.width - 2; x: 1; con: modelData
                    }
                }

                Item {
                    width: parent.width; height: 6
                    visible: VpnService.connections.some(function(c) { return c.active })
                          && VpnService.connections.some(function(c) { return !c.active })
                }

                // Available section
                Item {
                    width: parent.width; height: visible ? iLbl.implicitHeight + 4 : 0
                    visible: VpnService.connections.some(function(c) { return !c.active })
                    Text {
                        id: iLbl; text: "AVAILABLE"
                        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2
                        color: Qt.rgba(1,1,1,0.25)
                    }
                }

                Repeater {
                    model: VpnService.connections.filter(function(c) { return !c.active })
                    delegate: VpnConnectionRow {
                        required property var modelData
                        width: conCol.width - 2; x: 1; con: modelData
                    }
                }

                // Empty state
                Item {
                    width: parent.width; height: 180
                    visible: !VpnService.loading && VpnService.connections.length === 0
                    Column {
                        anchors.centerIn: parent; spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰦝"; font.pixelSize: 36; color: Qt.rgba(1,1,1,0.08) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No WireGuard connections"; font.pixelSize: 13; color: Qt.rgba(1,1,1,0.2) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Import a config to get started:"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.14); horizontalAlignment: Text.AlignHCenter }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: codeText.implicitWidth + 24; height: 26; radius: 6
                            color: Qt.rgba(1,1,1,0.05); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                            Text {
                                id: codeText; anchors.centerIn: parent
                                text: "nmcli con import type wireguard file <conf>"
                                font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                            }
                        }
                    }
                }

                // Loading state
                Item {
                    width: parent.width; height: 80
                    visible: VpnService.loading && VpnService.connections.length === 0
                    Column {
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "○"; font.pixelSize: 20; color: Theme.active
                            SequentialAnimation on opacity {
                                running: VpnService.loading && VpnService.connections.length === 0
                                loops:   Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 550 }
                                NumberAnimation { to: 1.0;  duration: 550 }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Loading…"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.25) }
                    }
                }

                Item { width: parent.width; height: 8 }
            }
        }
    }
}
