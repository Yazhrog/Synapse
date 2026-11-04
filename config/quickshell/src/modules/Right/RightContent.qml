import QtQuick
import Quickshell
import "../../components"
import "../../windows"
import "../../"

Item {
    // Set by the Dynamic Surface host (#39); contents adopt it progressively.
    property real localScale: 1.0

    id: root

    // DynamicSurface grows the notch for notifications, network and toasts.
    implicitWidth: contentRow.implicitWidth

    //Behavior on implicitWidth {
    //    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    //}
    implicitHeight: contentRow.implicitHeight

    // ── Normal content — fades out when any right popup opens ─────────────────
    Row {
        id: contentRow
        //anchors.centerIn: parent
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        opacity: (Popups.notificationsOpen || Popups.networkOpen) ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // A Row top-aligns its children: center each one, so items shorter
        // than the tallest icon (e.g. the battery) line up with the others.
        Network       { anchors.verticalCenter: parent.verticalCenter }
        Audio         { anchors.verticalCenter: parent.verticalCenter }
        Battery       { anchors.verticalCenter: parent.verticalCenter }
        Clock         {}
        SysTray       { anchors.verticalCenter: parent.verticalCenter }
        Notifications { anchors.verticalCenter: parent.verticalCenter }
    }

    // ── Open indicator — fades in when any right popup opens ──────────────────
    Text {
        anchors.centerIn: parent
        text:           "▾"
        color:          Theme.active
        font.pixelSize: 14
        opacity:        (Popups.notificationsOpen || Popups.networkOpen) ? 1 : 0
        visible:        opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
}
