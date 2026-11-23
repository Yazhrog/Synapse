import QtQuick
import qs.src.theme
import "player.js" as Player
// PlayerSourcePicker — the pill that shows the current MPRIS player and,
// clicked, expands upward into the list of the others.
Item {
    id: sourcePicker
    property var  players:       []
    property int  selectedIndex: -1
    property var  player:        null
    property bool open:          false
    signal selected(int index)

    // Footprint tracks the animated pill so hit-testing always matches
    width:  pill.width
    height: pill.height

    Rectangle {
        id: pill
        anchors.bottom:           parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        // Width is driven only by the always-visible active row — no circular dep
        width: activeRow.implicitWidth + 28

        readonly property int _rowH: 26
        height: sourcePicker.open
                ? (_rowH * sourcePicker.players.length)
                : _rowH
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        radius:       _rowH / 2
        clip:         true
        color:        Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.18)
        border.color: sourcePicker.open
                      ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.30)
                      : "transparent"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Column anchored to pill bottom — children stack upward on expand
        Column {
            id: pillCol
            anchors {
                bottom: parent.bottom
                left:   parent.left
                right:  parent.right
            }
            spacing: 0

            // ── Other player rows (appear above the active row) ─────────
            Repeater {
                model: sourcePicker.players

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === sourcePicker.selectedIndex

                    // Fixed width = pill; breaks the old circular dep on otherRow.implicitWidth
                    width:   pill.width
                    height:  isCurrent ? 0 : (sourcePicker.open ? pill._rowH : 0)
                    visible: !isCurrent
                    opacity: sourcePicker.open ? 1 : 0
                    Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           Player.playerIcon(modelData)
                            font.pixelSize: 11
                            color:          rowH.hovered
                                            ? Qt.rgba(1,1,1,0.90)
                                            : Qt.rgba(1,1,1,0.55)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           Player.playerLabel(modelData)
                            font.pixelSize: 10
                            color:          rowH.hovered
                                            ? Qt.rgba(1,1,1,0.90)
                                            : Qt.rgba(1,1,1,0.55)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }

                    HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            sourcePicker.selected(index)
                            sourcePicker.open = false
                        }
                    }
                }
            }

            // ── Active player row (always visible, anchored at pill bottom) ─
            Item {
                height: pill._rowH
                width:  pill.width

                Row {
                    id: activeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           Player.playerIcon(sourcePicker.player)
                        font.pixelSize: 11
                        color:          Theme.color.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:           Player.playerLabel(sourcePicker.player)
                        font.pixelSize: 10
                        font.weight:    Font.Medium
                        color:          Qt.rgba(1,1,1,0.92)
                    }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked:    sourcePicker.open = !sourcePicker.open
                }
            }
        }
    }
}
