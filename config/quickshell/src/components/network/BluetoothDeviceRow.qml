import QtQuick
import "../../"

// BluetoothDeviceRow — one device: icon, name and status; Connect /
// Disconnect and Remove (with a confirmation) when paired, Pair and an
// optional legacy PIN field when not.

Item {
    id: dRow
    required property var  device
    required property bool isPaired
    // The Bluetooth tab: which row has its PIN field / remove confirmation open
    required property Item tab

    readonly property bool isConnected:     device.connected
    readonly property bool inAction:        BluetoothService.actionMac   === device.mac
    readonly property bool inRemove:        BluetoothService.removingMac === device.mac
    readonly property bool isPairingOpen:   tab.pairingMac  === device.mac
    readonly property bool isRemovePending: tab.removeMac   === device.mac

    width: parent?.width ?? 0
    height: baseRow.height + expandArea.height

    Rectangle {
        anchors.fill: parent; radius: Theme.cornerRadius
        color: dRow.isConnected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
            : rowHov.hovered && !dRow.isPaired ? Qt.rgba(1,1,1,0.04) : "transparent"
        border.color: dRow.isConnected
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
            : dRow.isRemovePending ? Qt.rgba(248/255,113/255,113/255,0.22) : Qt.rgba(1,1,1,0.06)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    Item {
        id: baseRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 50

        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: BluetoothService.glyph(dRow.device.iconType); font.pixelSize: 18
            color: dRow.isConnected ? Theme.active
                : (dRow.inAction || dRow.inRemove) ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) : Qt.rgba(1,1,1,0.32)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Column {
            anchors { left: parent.left; leftMargin: 44; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text {
                text: dRow.device.name; font.pixelSize: 13
                font.weight: dRow.isConnected ? Font.Medium : Font.Normal
                color: dRow.isConnected ? Theme.text : Qt.rgba(1,1,1,0.68)
                width: 160; elide: Text.ElideRight
            }
            Text {
                visible: dRow.isConnected || dRow.inAction || dRow.inRemove
                text: dRow.inRemove ? "Removing…" : dRow.inAction ? "Working…" : "Connected"
                font.pixelSize: 10
                color: (dRow.inAction || dRow.inRemove) ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55) : Theme.active
            }
        }

        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 6

            // Spinner
            Text {
                visible: dRow.inAction || dRow.inRemove
                text: "○"; font.pixelSize: 15; color: Theme.active
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: dRow.inAction || dRow.inRemove; loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 450 }
                    NumberAnimation { to: 1.0;  duration: 450 }
                }
            }

            // Paired: connect/disconnect pill
            Rectangle {
                visible: dRow.isPaired && !dRow.inAction && !dRow.inRemove
                anchors.verticalCenter: parent.verticalCenter
                width: togContent.implicitWidth + 20; height: 28; radius: 14
                color: dRow.isConnected ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14) : togH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.04)
                border.color: dRow.isConnected ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.36) : Qt.rgba(1,1,1,0.11)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Row {
                    id: togContent; anchors.centerIn: parent; spacing: 7
                    Rectangle { width: 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: dRow.isConnected ? Theme.active : Qt.rgba(1,1,1,0.25); Behavior on color { ColorAnimation { duration: 150 } } }
                    Text { text: dRow.isConnected ? "Connected" : "Connect"; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter; color: dRow.isConnected ? Theme.active : Qt.rgba(1,1,1,0.48); Behavior on color { ColorAnimation { duration: 120 } } }
                }
                HoverHandler { id: togH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: dRow.isConnected ? BluetoothService.disconnect(dRow.device.mac) : BluetoothService.connect(dRow.device.mac) }
            }

            // Paired: remove button
            Item {
                visible: dRow.isPaired && !dRow.inAction && !dRow.inRemove
                width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 7; color: rmH.hovered ? Qt.rgba(248/255,113/255,113/255,0.20) : dRow.isRemovePending ? Qt.rgba(248/255,113/255,113/255,0.12) : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
                Text { anchors.centerIn: parent; text: "󰗼"; font.pixelSize: 13; color: (rmH.hovered || dRow.isRemovePending) ? "#f87171" : Qt.rgba(1,1,1,0.25); Behavior on color { ColorAnimation { duration: 100 } } }
                HoverHandler { id: rmH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: { dRow.tab.pairingMac = ""; dRow.tab.removeMac = dRow.isRemovePending ? "" : dRow.device.mac } }
            }

            // Available: Pair + PIN icon
            Row {
                visible: !dRow.isPaired && !dRow.inAction
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: pairLbl.implicitWidth + 20; height: 28; radius: 8
                    color: pairH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.09)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { id: pairLbl; anchors.centerIn: parent; text: "Pair"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active }
                    HoverHandler { id: pairH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: { dRow.tab.removeMac = ""; dRow.tab.pairingMac = ""; BluetoothService.pair(dRow.device.mac, "") } }
                }

                Item {
                    width: 24; height: 28; anchors.verticalCenter: parent?.verticalCenter
                    Rectangle { anchors.fill: parent; radius: 6; color: pinH.hovered ? Qt.rgba(1,1,1,0.10) : dRow.isPairingOpen ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12) : Qt.rgba(1,1,1,0.04); border.color: dRow.isPairingOpen ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30) : Qt.rgba(1,1,1,0.09); border.width: 1; Behavior on color { ColorAnimation { duration: 100 } } }
                    Text { anchors.centerIn: parent; text: "󰌾"; font.pixelSize: 12; color: dRow.isPairingOpen ? Theme.active : pinH.hovered ? Qt.rgba(1,1,1,0.7) : Qt.rgba(1,1,1,0.28); Behavior on color { ColorAnimation { duration: 100 } } }
                    HoverHandler { id: pinH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            dRow.tab.removeMac  = ""
                            dRow.tab.pairingMac = dRow.isPairingOpen ? "" : dRow.device.mac
                            if (!dRow.isPairingOpen) Qt.callLater(function() { pinInput.forceActiveFocus() })
                            else pinInput.text = ""
                        }
                    }
                }
            }
        }
    }

    // Expandable
    Item {
        id: expandArea
        anchors { top: baseRow.bottom; left: parent.left; right: parent.right }
        clip: true
        height: dRow.isRemovePending ? removeRow.implicitHeight + 16 : dRow.isPairingOpen ? pinRow.implicitHeight + 16 : 0
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Remove confirmation
        Item {
            id: removeRow
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            implicitHeight: 32
            opacity: dRow.isRemovePending ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Rectangle {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                radius: 8; color: Qt.rgba(248/255,113/255,113/255,0.06); border.color: Qt.rgba(248/255,113/255,113/255,0.22); border.width: 1
                Row {
                    anchors.centerIn: parent; spacing: 12
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Remove this device?"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.5) }
                    Rectangle { width: 58; height: 24; radius: 6; color: cxH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.04); Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.42) }
                        HoverHandler { id: cxH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: dRow.tab.removeMac = "" }
                    }
                    Rectangle { width: 64; height: 24; radius: 6; color: rxH.hovered ? Qt.rgba(248/255,113/255,113/255,0.40) : Qt.rgba(248/255,113/255,113/255,0.18); Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Remove"; font.pixelSize: 10; font.weight: Font.Medium; color: "#f87171" }
                        HoverHandler { id: rxH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: { dRow.tab.removeMac = ""; BluetoothService.remove(dRow.device.mac) } }
                    }
                }
            }
        }

        // PIN row
        Item {
            id: pinRow
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            implicitHeight: pinCol.implicitHeight
            opacity: dRow.isPairingOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Column {
                id: pinCol
                anchors { left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                spacing: 6
                Text { width: parent.width; text: "Legacy PIN pairing — enter the PIN shown on your device"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.30); wrapMode: Text.WordWrap }
                Row {
                    width: parent.width; spacing: 8
                    Rectangle {
                        width: parent.width - pairConfBtn.width - parent.spacing; height: 32; radius: 8
                        color: Qt.rgba(1,1,1,0.06)
                        border.color: pinInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55) : Qt.rgba(1,1,1,0.12)
                        border.width: 1; Behavior on border.color { ColorAnimation { duration: 120 } }
                        Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "PIN (optional)…"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.22); visible: pinInput.text === "" }
                        TextInput {
                            id: pinInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter; color: Theme.text
                            font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 8
                            selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); clip: true
                            Keys.onReturnPressed: { dRow.tab.pairingMac = ""; BluetoothService.pair(dRow.device.mac, text) }
                        }
                    }
                    Rectangle {
                        id: pairConfBtn; width: 64; height: 32; radius: 8
                        color: pcH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.42); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "Pair"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active }
                        HoverHandler { id: pcH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: { dRow.tab.pairingMac = ""; BluetoothService.pair(dRow.device.mac, pinInput.text) } }
                    }
                }
            }
        }
    }

    onIsPairingOpenChanged: { if (!isPairingOpen) pinInput.text = "" }
    HoverHandler { id: rowHov; enabled: !dRow.isPaired }
}
