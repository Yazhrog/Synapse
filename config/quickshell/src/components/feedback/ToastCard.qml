import QtQuick
import Quickshell.Services.Notifications
import qs.src.theme
// ToastCard — the content of a notification toast: app icon and name, close
// button, summary, body, action buttons and the urgency-coloured countdown
// bar. Presentational: the host passes `notification`, `showing` and
// `duration` (the toast queue's) and handles dismissRequested(); it also
// draws the background.
// Height follows the content (implicitHeight).
Item {
    id: root

    property var  notification: null
    property bool showing:      false
    property int  duration:     5000      // ms the countdown bar runs
    signal dismissRequested()
    // Width of the countdown bar when full.
    property real barWidth: width

    implicitHeight: cardCol.implicitHeight

    Rectangle {
        id: progressBar
        anchors {
            right:        parent.right
            bottom:       cardCol.bottom
            bottomMargin: -10
        }
        height:  3
        radius:  2
        opacity: 0.8
        color: {
            if (!root.notification) return "#ABB2BF"
            switch (root.notification.urgency) {
                case NotificationUrgency.Critical: return "#e06c75"
                case NotificationUrgency.Low:      return Qt.rgba(1,1,1,0.25)
                default:                           return "#ABB2BF"
            }
        }

        property bool running: false

        width: running ? 0 : root.barWidth
        Behavior on width {
            enabled: progressBar.running
            NumberAnimation { duration: root.duration; easing.type: Easing.Linear }
        }

        Connections {
            target: root
            function onShowingChanged() {
                progressBar.running = false
                if (root.showing) progressTick.restart()
            }
        }

        Timer {
            id:          progressTick
            interval:    16
            onTriggered: progressBar.running = true
        }
    }

    Column {
        id: cardCol
        width:   parent.width
        spacing: 2
        bottomPadding: 10

        Row {
            width:   parent.width
            height:  40
            spacing: 8

            Item {
                width:  16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id:           toastIcon
                    anchors.fill: parent
                    source: {
                        var ic = root.notification?.appIcon ?? ""
                        if (ic === "") return ""
                        if (ic.startsWith("/")) return "file://" + ic
                        return "image://icon/" + ic
                    }
                    fillMode:          Image.PreserveAspectFit
                    smooth:            true
                    visible:           status === Image.Ready
                    sourceSize.width:  16
                    sourceSize.height: 16
                }
                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        Qt.rgba(1,1,1,0.1)
                    visible:      toastIcon.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text:           (root.notification?.appName ?? "?").charAt(0).toUpperCase()
                        color:          Theme.color.text
                        font.pixelSize: 9
                        font.bold:      true
                    }
                }
            }

            Text {
                width:                  parent.width - 16 - 24 - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text:                   root.notification?.appName ?? ""
                color:                  Theme.color.textMuted
                font.pixelSize:         11
                elide:                  Text.ElideRight
            }

            Item {
                width:  20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        xHover.hovered ? Qt.rgba(1,1,1,0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text {
                    anchors.centerIn: parent
                    text:             "✕"
                    color:            Theme.color.textMuted
                    font.pixelSize:   9
                }
                HoverHandler { id: xHover }
                TapHandler   { onTapped: root.dismissRequested() }
            }
        }

        Text {
            width:            parent.width
            text:             root.notification?.summary ?? ""
            color:            Theme.color.text
            font.pixelSize:   13
            font.bold:        true
            wrapMode:         Text.WordWrap
            maximumLineCount: 2
            elide:            Text.ElideRight
            visible:          text !== ""
        }

        Text {
            width:            parent.width
            text:             root.notification?.body ?? ""
            color:            Theme.color.textMuted
            font.pixelSize:   12
            wrapMode:         Text.WordWrap
            maximumLineCount: 2
            elide:            Text.ElideRight
            textFormat:       Text.StyledText
            visible:          text !== ""
        }

        Row {
            spacing:    6
            topPadding: 2
            visible:    (root.notification?.actions?.length ?? 0) > 0

            Repeater {
                model: root.notification?.actions ?? []
                delegate: Item {
                    required property var modelData
                    width:  actionLbl.width + 20
                    height: 24
                    Rectangle {
                        anchors.fill: parent
                        radius:       4
                        color:        actHover.hovered ? Qt.rgba(1,1,1,0.18) : Qt.rgba(1,1,1,0.08)
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
                    TapHandler {
                        onTapped: {
                            modelData?.invoke()
                            root.dismissRequested()
                        }
                    }
                }
            }
        }
    }
}
