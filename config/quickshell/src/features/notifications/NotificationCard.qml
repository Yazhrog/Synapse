import QtQuick
import Quickshell.Services.Notifications
import qs.src.theme
// NotificationCard — one notification in NotificationList: urgency bar, app
// icon (letter fallback), app name, summary, body, its actions and ✕.
Item {
    id: card

    // notification is required — guard every access with ?. and ?? fallback
    required property var notification

    // Urgency accent color — guard against undefined notification/urgency
    readonly property color urgencyColor: {
        if (!notification) return Theme.color.accent
        switch (notification.urgency) {
            case NotificationUrgency.Critical: return "#e06c75"
            case NotificationUrgency.Low:      return Qt.rgba(1, 1, 1, 0.25)
            default:                           return Theme.color.accent
        }
    }

    height: cardRow.height + 20

    // Hover background
    Rectangle {
        anchors.fill: parent
        color:        cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Left urgency accent bar
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width:   3
        color:   card.urgencyColor
        opacity: 0.85
    }

    // Content row
    Row {
        id: cardRow
        anchors {
            left:        parent.left; leftMargin:  12
            right:       parent.right; rightMargin:  8
            top:         parent.top;   topMargin:   10
        }
        spacing: 10
        height:  Math.max(iconArea.height, textCol.implicitHeight)

        // App icon
        Item {
            id:     iconArea
            width:  32
            height: 32

            Image {
                id:        iconImg
                anchors.fill: parent
                source: {
                    var ic = card.notification?.appIcon ?? ""
                    if (ic === "") return ""
                    if (ic.startsWith("/")) return "file://" + ic
                    return "image://icon/" + ic
                }
                fillMode:          Image.PreserveAspectFit
                smooth:            true
                visible:           status === Image.Ready
                sourceSize.width:  32
                sourceSize.height: 32
            }

            // Letter fallback
            Rectangle {
                anchors.fill: parent
                radius:       width / 2
                color:        Qt.rgba(1, 1, 1, 0.08)
                visible:      iconImg.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text:           (card.notification?.appName ?? "?").charAt(0).toUpperCase()
                    color:          Theme.color.text
                    font.pixelSize: 14
                    font.bold:      true
                }
            }
        }

        // Text column
        Column {
            id:     textCol
            // Leave room for dismiss button
            width: cardRow.width - iconArea.width - dismissBtn.width - (cardRow.spacing * 2)
            spacing: 3

            // App name
            Text {
                width:          parent.width
                text:           card.notification?.appName ?? ""
                color:          Theme.color.textMuted
                font.pixelSize: 11
                elide:          Text.ElideRight
                visible:        text !== ""
            }

            // Summary
            Text {
                width:            parent.width
                text:             card.notification?.summary ?? ""
                color:            Theme.color.text
                font.pixelSize:   13
                font.bold:        true
                wrapMode:         Text.WordWrap
                maximumLineCount: 2
                elide:            Text.ElideRight
                visible:          text !== ""
            }

            // Body
            Text {
                width:            parent.width
                text:             card.notification?.body ?? ""
                color:            Theme.color.textMuted
                font.pixelSize:   12
                wrapMode:         Text.WordWrap
                maximumLineCount: 3
                elide:            Text.ElideRight
                textFormat:       Text.StyledText
                visible:          text !== ""
            }

            // Action buttons
            Row {
                spacing: 6
                visible: (card.notification?.actions?.length ?? 0) > 0

                Repeater {
                    model: card.notification?.actions ?? []
                    delegate: Item {
                        required property var modelData
                        width:  actionLbl.width + 20
                        height: 22

                        Rectangle {
                            anchors.fill: parent
                            radius:       3
                            color:        actHover.containsMouse
                                          ? Qt.rgba(1,1,1,0.15)
                                          : Qt.rgba(1,1,1,0.07)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            id:               actionLbl
                            anchors.centerIn: parent
                            text:             modelData?.text ?? ""
                            color:            Theme.color.text
                            font.pixelSize:   11
                        }
                        HoverHandler { id: actHover }
                        TapHandler   { onTapped: modelData?.invoke() }
                    }
                }
            }
        }

        // Dismiss ✕
        Item {
            id:     dismissBtn
            width:  24
            height: 24

            Rectangle {
                anchors.fill: parent
                radius:       width / 2
                color:        xHover.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            Text {
                anchors.centerIn: parent
                text:             "✕"
                color:            Theme.color.textMuted
                font.pixelSize:   10
            }
            HoverHandler { id: xHover }
            TapHandler   { onTapped: card.notification?.dismiss() }
        }
    }

    HoverHandler { id: cardHover }
}
