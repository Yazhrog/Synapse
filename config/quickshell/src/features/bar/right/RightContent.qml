import QtQuick
import Quickshell
import qs.src.state
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
        NetworkIndicator       { anchors.verticalCenter: parent.verticalCenter }
        AudioIndicator         { anchors.verticalCenter: parent.verticalCenter }
        BatteryIndicator       { anchors.verticalCenter: parent.verticalCenter }
        Clock         {}
        SysTray       { anchors.verticalCenter: parent.verticalCenter }
        NotificationsButton { anchors.verticalCenter: parent.verticalCenter }
    }
}
