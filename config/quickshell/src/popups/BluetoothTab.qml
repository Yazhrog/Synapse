import QtQuick
import "../"
import "../components"
import "../components/network"

// BluetoothTab — the network popup's Bluetooth page: paired devices, the
// ones a scan finds, pairing (with an optional legacy PIN) and removal.
// State and bluetoothctl calls live in BluetoothService.

Item {
    id: root

    // Which row has its PIN field / remove confirmation open
    property string pairingMac: ""
    property string removeMac:  ""

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen && root.visible) {
                root.pairingMac = ""
                root.removeMac  = ""
                BluetoothService.refresh()
            }
        }
    }

    Component.onCompleted: BluetoothService.refresh()

    Column {
        anchors.fill: parent; spacing: 0

        // Header
        Item {
            width: parent.width; height: 48   // header: 8 px around the 32 px buttons

            Text { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
            text: "Bluetooth"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                RadioPowerButton     { on: BluetoothService.powered; onClicked: BluetoothService.togglePower() }
                SettingsLaunchButton { onClicked: BluetoothService.openSettings() }

                // Scan / Stop pill — disabled when adapter is off
                Rectangle {
                    width: scanRow.implicitWidth + 20; height: 30; radius: 15
                    opacity: BluetoothService.powered ? 1.0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    color: BluetoothService.scanning ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : scanH.hovered && BluetoothService.powered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12) : Qt.rgba(1,1,1,0.05)
                    border.color: BluetoothService.scanning ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.48) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28); border.width: 1
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Row {
                        id: scanRow; anchors.centerIn: parent; spacing: 7
                        Rectangle {
                            width: 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: BluetoothService.scanning ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            SequentialAnimation on opacity { 
                                running: BluetoothService.scanning; loops: Animation.Infinite; NumberAnimation { to: 0.15; duration: 450 }
                                NumberAnimation { to: 1.0; duration: 450 }
                            }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: BluetoothService.scanning ? "Stop" : "Scan"; font.pixelSize: 12; font.weight: Font.Medium; color: BluetoothService.scanning ? Theme.active : Qt.rgba(1,1,1,0.6); Behavior on color { ColorAnimation { duration: 130 } } }
                    }
                    HoverHandler { id: scanH; cursorShape: BluetoothService.powered ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    MouseArea { anchors.fill: parent; onClicked: if (BluetoothService.powered) BluetoothService.toggleScan() }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 8 }

        // Scan animation strip
        Item {
            width: parent.width; height: BluetoothService.scanning ? 90 : 0; clip: true
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            ScanRings { running: BluetoothService.scanning; anchors.centerIn: parent; width: 52; height: 52; centerGlyph: "󰂯"; glyphSize: 14 }
            Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
            text: "Scanning for devices…"; font.pixelSize: 10; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50) }
        }

        Flickable {
            width: parent.width
            height: parent.height - 57 - (BluetoothService.scanning ? 90 : 0)
            contentWidth: width; contentHeight: devCol.height
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            Column {
                id: devCol; width: parent.width; height: implicitHeight; spacing: 4

                Item { width: parent.width; height: visible ? pLbl.implicitHeight + 4 : 0; visible: BluetoothService.paired.length > 0
                    Text { id: pLbl; text: "PAIRED"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) } }

                Repeater {
                    model: BluetoothService.paired
                    delegate: BluetoothDeviceRow { required property var modelData; tab: root; width: devCol.width - 2; x: 1; device: modelData; isPaired: true }
                }

                Item { width: parent.width; height: 10; visible: BluetoothService.paired.length > 0 && BluetoothService.available.length > 0 }

                Item { width: parent.width; height: visible ? aLbl.implicitHeight + 4 : 0; visible: BluetoothService.available.length > 0
                    Text { id: aLbl; text: BluetoothService.scanning ? "DISCOVERED" : "AVAILABLE"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(1,1,1,0.25) } }

                Repeater {
                    model: BluetoothService.available
                    delegate: BluetoothDeviceRow { required property var modelData; tab: root; width: devCol.width - 2; x: 1; device: modelData; isPaired: false }
                }

                // Empty state
                Item {
                    width: parent.width; height: 120
                    visible: !BluetoothService.scanning && BluetoothService.devices.length === 0 && BluetoothService.powered
                    Column { anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰂯"; font.pixelSize: 32; color: Qt.rgba(1,1,1,0.08) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No devices found"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.2) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Tap Scan to discover nearby devices"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.14) }
                    }
                }

                Item { width: parent.width; height: 8 }
            }
        }
    }

    // Bluetooth off — covers the list only
    RadioOffOverlay {
        anchors { fill: parent; topMargin: 57 }
        visible: !BluetoothService.powered
        z: 2
        glyph: "󰂲"; buttonGlyph: "󰂯"; title: "Bluetooth is off"
        onTurnOn: BluetoothService.setPower(true)
    }
}
