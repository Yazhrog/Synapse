import QtQuick
import "../../"

// WifiNetworkRow — one Wi-Fi network: name, lock and signal, Connect /
// Retry, and for the current one Disconnect and Forget (with a confirmation).
// Expands a password field when WifiService asks for one.

Item {
    id: netRow
    required property var  net
    required property bool isCurrent
    // The Wi-Fi tab: which row has its "Forget?" confirmation open
    required property Item tab
    readonly property bool isForgetPending: tab.forgetSsid === net.ssid
    readonly property bool isExpanded:      WifiService.promptSsid   === net.ssid
    readonly property bool isConnecting:    WifiService.connectingTo === net.ssid
    readonly property bool needsPassword:   !!WifiService.needsPassword[net.ssid]
    property bool _showPass: false
    width: parent?.width ?? 0
    height: baseRow.height + expandArea.height

    Rectangle {
        anchors.fill: parent; radius: Theme.cornerRadius
        color: netRow.isCurrent
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
            : rHov.hovered ? Qt.rgba(1,1,1,0.04) : "transparent"
        border.color: netRow.isCurrent
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
            : netRow.needsPassword
                ? Qt.rgba(245/255,196/255,122/255,0.30)
                : Qt.rgba(1,1,1,0.06)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 130 } }
        Behavior on border.color { ColorAnimation { duration: 130 } }
    }

    Item {
        id: baseRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 48

        Column {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text {
                text: netRow.net.ssid; font.pixelSize: 13
                font.weight: netRow.isCurrent ? Font.Medium : Font.Normal
                color: netRow.isCurrent ? Theme.text : Qt.rgba(1,1,1,0.7)
                width: 170; elide: Text.ElideRight
            }
            Text {
                visible: netRow.needsPassword && !netRow.isCurrent
                text: "Password required"; font.pixelSize: 10
                color: Qt.rgba(245/255,196/255,122/255,0.80)
            }
            Text { visible: netRow.isCurrent; text: "Connected"; font.pixelSize: 10; color: Theme.active }
        }

        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 6

            Text {
                visible: netRow.net.secured && !netRow.isCurrent
                text: "󰌾"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.28)
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                width: 22; height: 16; anchors.verticalCenter: parent.verticalCenter
                SignalBars { anchors.centerIn: parent; signal: netRow.net.signal }
            }
            Item {
                visible: netRow.isConnecting; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent; text: "○"; font.pixelSize: 14; color: Theme.active
                    SequentialAnimation on opacity {
                        running: netRow.isConnecting; loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
            }
            // Disconnect
            Item {
                visible: netRow.isCurrent; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 6; color: dH.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
                Text { anchors.centerIn: parent; text: "󰖪"; font.pixelSize: 14; color: dH.hovered ? Qt.rgba(1,1,1,0.65) : Qt.rgba(1,1,1,0.35); Behavior on color { ColorAnimation { duration: 100 } } }
                HoverHandler { id: dH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: WifiService.disconnect() }
            }
            // Forget
            Item {
                visible: netRow.isCurrent; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent; radius: 6
                    color: fH.hovered ? Qt.rgba(248/255,113/255,113/255,0.15) : netRow.isForgetPending ? Qt.rgba(248/255,113/255,113/255,0.10) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text { anchors.centerIn: parent; text: "󰗼"; font.pixelSize: 13; color: (fH.hovered || netRow.isForgetPending) ? "#f87171" : Qt.rgba(1,1,1,0.3); Behavior on color { ColorAnimation { duration: 100 } } }
                HoverHandler { id: fH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: netRow.tab.forgetSsid = netRow.isForgetPending ? "" : netRow.net.ssid }
            }
            // Connect
            Rectangle {
                visible: !netRow.isCurrent && !netRow.isConnecting
                anchors.verticalCenter: parent.verticalCenter
                width: connectLbl.implicitWidth + 20; height: 28; radius: 8
                color: conH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.09)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }
                Text { id: connectLbl; anchors.centerIn: parent; text: netRow.isExpanded ? "Retry" : "Connect"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active }
                HoverHandler { id: conH; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        netRow.tab.forgetSsid = ""
                        if (netRow.isExpanded && passInput.text !== "")
                            WifiService.connectWithPassword(netRow.net.ssid, passInput.text)
                        else
                            WifiService.connect(netRow.net.ssid)
                    }
                }
            }
        }
    }

    Item {
        id: expandArea
        anchors { top: baseRow.bottom; left: parent.left; right: parent.right }
        clip: true
        height: netRow.isForgetPending ? forgetRow.implicitHeight + 16 : netRow.isExpanded ? passRow.implicitHeight + 16 : 0
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Item {
            id: forgetRow
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            implicitHeight: 32
            opacity: netRow.isForgetPending ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Rectangle {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                radius: 8; color: Qt.rgba(248/255,113/255,113/255,0.07)
                border.color: Qt.rgba(248/255,113/255,113/255,0.22); border.width: 1
                Row {
                    anchors.centerIn: parent; spacing: 12
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Forget this network?"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.55) }
                    Rectangle {
                        width: 54; height: 24; radius: 6; color: cfH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.04)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.45) }
                        HoverHandler { id: cfH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: netRow.tab.forgetSsid = "" }
                    }
                    Rectangle {
                        width: 54; height: 24; radius: 6
                        color: ffH.hovered ? Qt.rgba(248/255,113/255,113/255,0.35) : Qt.rgba(248/255,113/255,113/255,0.18)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Forget"; font.pixelSize: 10; font.weight: Font.Medium; color: "#f87171" }
                        HoverHandler { id: ffH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: { netRow.tab.forgetSsid = ""; WifiService.forget(netRow.net.ssid) } }
                    }
                }
            }
        }

        Item {
            id: passRow
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
            implicitHeight: 40
            opacity: netRow.isExpanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Row {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8
                Rectangle {
                    width: parent.width - parent.spacing; height: 32; radius: 8
                    color: Qt.rgba(1,1,1,0.06)
                    border.color: passInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55) : Qt.rgba(1,1,1,0.12)
                    border.width: 1; Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "Password…"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.22); visible: passInput.text === "" }
                    TextInput {
                        id: passInput
                        // Updated anchors to make room for the eye button
                        anchors { left: parent.left; leftMargin: 10; right: eyeBtn.left; rightMargin: 6; top: parent.top; bottom: parent.bottom }
                        verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 12
                        // Toggle echoMode based on state
                        echoMode: netRow._showPass ? TextInput.Normal : TextInput.Password
                        selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); clip: true
                        Keys.onReturnPressed: { if (text.length > 0) WifiService.connectWithPassword(netRow.net.ssid, text) }
                    }

                    // Added Show Password Button
                    Item {
                        id: eyeBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28
                        Rectangle { anchors.fill: parent; radius: 6; color: eyeH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent" }
                        Text { 
                            anchors.centerIn: parent
                            text: netRow._showPass ? "" : ""
                            font.pixelSize: 13
                            color: netRow._showPass ? Theme.active : Qt.rgba(1,1,1,0.28) 
                        }
                        HoverHandler { id: eyeH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: netRow._showPass = !netRow._showPass }
                    }
                }
            }
        }

        onVisibleChanged: { if (visible && netRow.isExpanded) Qt.callLater(function() { passInput.forceActiveFocus() }) }
    }

    onIsExpandedChanged: {
        if (isExpanded) Qt.callLater(function() { passInput.forceActiveFocus() })
        else            passInput.text = ""
    }

    HoverHandler { id: rHov; enabled: !netRow.isCurrent }
}
