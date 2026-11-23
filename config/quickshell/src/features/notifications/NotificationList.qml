import QtQuick
import qs.src.services.notifications
import qs.src.theme
// ─────────────────────────────────────────────────────────────
// NotificationList — content of the notifications popup
// ─────────────────────────────────────────────────────────────
Item {
    id: root

    width:  360

    // Total height: header + list area (or empty state)
    height: header.height
            + (NotificationService.count > 0 ? listArea.height : emptyState.height)

    // ── Header ─────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text:           "Notifications"
            color:          Theme.color.text
            font.pixelSize: 14
            font.bold:      true
        }

        // Clear-all — only visible when there are notifications
        Item {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width:   clearLabel.width + 16
            height:  26
            visible: NotificationService.count > 0

            Rectangle {
                anchors.fill: parent
                radius:       13
                color:        clearHover.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Text {
                id:               clearLabel
                anchors.centerIn: parent
                text:             "Clear all"
                color:            Theme.color.textMuted
                font.pixelSize:   12
            }
            HoverHandler { id: clearHover }
            TapHandler   { onTapped: NotificationService.dismissAll() }
        }
    }

    // Divider — only when list is non-empty
    Rectangle {
        id: divider
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        height:  1
        color:   Qt.rgba(1, 1, 1, 0.06)
        visible: NotificationService.count > 0
    }

    // ── Scrollable list ─────────────────────────────────────────
    Item {
        id:      listArea
        anchors { top: divider.bottom; left: parent.left; right: parent.right }
        // Clamp to maxListHeight — ListView scrolls inside
        height:  Math.min(contentList.contentHeight, maxListHeight)
        visible: NotificationService.count > 0

        readonly property int maxListHeight: 440

        ListView {
            id:             contentList
            anchors.fill:   parent
            model:          NotificationService.list
            clip:           true
            spacing:        1
            boundsBehavior: Flickable.StopAtBounds

            delegate: NotificationCard {
                required property var modelData
                width:        ListView.view.width
                notification: modelData
            }
        }

        // Fade overlay when clipped
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height:  28
            visible: contentList.contentHeight > listArea.maxListHeight
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0.09, 0.11, 0.13, 1.0) }
            }
        }
    }

    // ── Empty state ─────────────────────────────────────────────
    Item {
        id:      emptyState
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        height:  80
        visible: NotificationService.count === 0

        Column {
            anchors.centerIn: parent
            spacing:          6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "󰂚"
                color:          Qt.rgba(1, 1, 1, 0.15)
                font.pixelSize: 28
                font.family:    Theme.color.iconFont
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "No notifications"
                color:          Theme.color.textMuted
                font.pixelSize: 12
            }
        }
    }
}
