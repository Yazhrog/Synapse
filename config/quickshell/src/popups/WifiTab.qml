import QtQuick
import "../"
import "../components"
import "../components/network"

// WifiTab — the network popup's Wi-Fi page: the wired connection (when a
// cable is in), the current network and the available ones. Connect first
// tries without a password; if nmcli asks for one, the row expands a field.
// State and nmcli calls live in WifiService.

Item {
    id: root

    // Which row has its "Forget?" confirmation open
    property string forgetSsid: ""

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen) {
                root.forgetSsid = ""
                WifiService.resetPrompts()
                WifiService.poll()
                WifiService.scan(false)
            }
        }
    }

    // Lists once the radio is known to be on (startup, or turned on here)
    Connections {
        target: WifiService
        function onRadioOnChanged() {
            if (WifiService.radioOn && WifiService.networks.length === 0) WifiService.scan(false)
        }
    }

    Component.onCompleted: WifiService.scan(false)

    Column {
        anchors.fill: parent; spacing: 0

        Item {
            width: parent.width; height: 48   // header: 8 px around the 32 px buttons
            Text { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
            text: "Wi-Fi"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                RadioPowerButton     { on: WifiService.radioOn; onClicked: WifiService.setRadio(!WifiService.radioOn) }
                SettingsLaunchButton { onClicked: WifiService.openSettings() }
                RefreshButton {
                    busy:      WifiService.scanning
                    available: WifiService.radioOn
                    onClicked: WifiService.scan(true)
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 8 }

        // Wired connection — stays visible while Wi-Fi is off
        Item {
            id: ethBlock
            width: parent.width
            height: WifiService.ethernet ? ethRow.height + 10 : 0
            visible: WifiService.ethernet
            EthernetRow { id: ethRow; width: parent.width - 2; x: 1 }
        }

        Flickable {
            id: flick; width: parent.width; height: parent.height - 57 - ethBlock.height
            contentWidth: width; contentHeight: contentCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: contentCol; width: flick.width; height: implicitHeight; spacing: 4

                Item { width: parent.width; height: visible ? sLbl1.implicitHeight + 4 : 0; visible: WifiService.current !== null
                    Text { id: sLbl1; text: "CONNECTED"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) } }

                WifiNetworkRow { tab: root; visible: WifiService.current !== null; width: parent.width - 2; x: 1; net: WifiService.current ?? { ssid: "", signal: 0, secured: false, inUse: true }; isCurrent: true }

                Item { width: parent.width; height: 10; visible: WifiService.current !== null && WifiService.available.length > 0 }

                Item { width: parent.width; height: visible ? sLbl2.implicitHeight + 4 : 0; visible: WifiService.available.length > 0
                    Text { id: sLbl2; text: "AVAILABLE"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(1,1,1,0.25) } }

                Repeater {
                    model: WifiService.available
                    delegate: WifiNetworkRow { required property var modelData; tab: root; width: contentCol.width - 2; x: 1; net: modelData; isCurrent: false }
                }

                Item {
                    width: parent.width; height: 160
                    visible: !WifiService.scanning && WifiService.networks.length === 0 && WifiService.radioOn
                    Column { anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤭"; font.pixelSize: 34; color: Qt.rgba(1,1,1,0.08) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No networks found"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.2) } }
                }

                Item {
                    width: parent.width; height: 160
                    visible: WifiService.scanning && WifiService.networks.length === 0
                    ScanRings { running: WifiService.scanning; anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                    width: 96; height: 96; centerGlyph: "󰤨"; glyphSize: 18 }
                    Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                    text: "Scanning…"; font.pixelSize: 11; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) }
                }

                Item { width: parent.width; height: 8 }
            }
        }
    }

    // Wi-Fi off — covers the list only (below the header and the wired row)
    RadioOffOverlay {
        anchors { fill: parent; topMargin: 57 + ethBlock.height }
        visible: !WifiService.radioOn
        z: 2
        glyph: "󰤭"; buttonGlyph: "󰤨"; title: "Wi-Fi is off"
        onTurnOn: WifiService.setRadio(true)
    }
}
