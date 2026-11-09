import QtQuick
import "../../"

// VpnConnectionRow — one WireGuard connection; a click connects or
// disconnects it. Pulses when it becomes active.

Item {
    id: vRow
    required property var con   // { name, active, busy }
    height: 54

    property bool _wasActive: false
    onConChanged: {
        if (con.active && !_wasActive) pulseAnim.restart()
        _wasActive = con.active
    }

    // Card background
    Rectangle {
        id: card; anchors.fill: parent; radius: Theme.cornerRadius
        color: vRow.con.active
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08)
            : vHov.hovered ? Qt.rgba(1,1,1,0.04) : "transparent"
        border.color: vRow.con.active
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
            : Qt.rgba(1,1,1,0.07)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        SequentialAnimation {
            id: pulseAnim; running: false
            ColorAnimation { target: card; to: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30); duration: 160 }
            ColorAnimation { target: card; to: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08); duration: 500; easing.type: Easing.OutCubic }
        }
    }

    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 12

        // Shield glyph
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰦝"; font.pixelSize: 20
            color: vRow.con.active
                ? Theme.active
                : vRow.con.busy
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                    : Qt.rgba(1,1,1,0.28)
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 4

            Text {
                text: vRow.con.name; font.pixelSize: 13
                font.weight: vRow.con.active ? Font.Medium : Font.Normal
                color: vRow.con.active ? Theme.text : Qt.rgba(1,1,1,0.65)
                width: 160; elide: Text.ElideRight
            }
            Text {
                font.pixelSize: 10
                text: vRow.con.busy
                    ? (vRow.con.active ? "Disconnecting…" : "Connecting…")
                    : vRow.con.active ? "Connected" : "Disconnected"
                color: vRow.con.busy
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.60)
                    : vRow.con.active ? Theme.active : Qt.rgba(1,1,1,0.32)
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }

    // Right: spinner or status dot
    Item {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: 28; height: 28

        Text {
            anchors.centerIn: parent; visible: vRow.con.busy
            text: "○"; font.pixelSize: 16; color: Theme.active
            SequentialAnimation on opacity {
                running: vRow.con.busy; loops: Animation.Infinite
                NumberAnimation { to: 0.15; duration: 450 }
                NumberAnimation { to: 1.0;  duration: 450 }
            }
        }

        Rectangle {
            anchors.centerIn: parent; visible: !vRow.con.busy
            width: 10; height: 10; radius: 5
            color: vRow.con.active
                ? Theme.active
                : vHov.hovered ? Qt.rgba(1,1,1,0.35) : Qt.rgba(1,1,1,0.18)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    HoverHandler { id: vHov; cursorShape: Qt.PointingHandCursor }
    MouseArea {
        anchors.fill: parent
        enabled: !vRow.con.busy
        onClicked: vRow.con.active
            ? VpnService.disconnect(vRow.con.name)
            : VpnService.connect(vRow.con.name)
    }
}
