import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../"

// QuickControlContent — the volume and brightness sliders of the Quick
// Controls OSD, with the default sink; brightness comes from BrightnessService.
// Hosted by the right-center region of DynamicSurface.
Item {
    id: root

    // Poll brightness fast while shown, so the slider follows the keys.
    property bool fastPoll: false

    // ── Audio State ───────────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Binding {
        target: BrightnessService; property: "fastPoll"
        value: true; when: root.fastPoll
    }

    // ── Sliders Layout ────────────────────────────────────────────────
    Row {
        anchors.fill: parent
        spacing: 8

        // Audio Slider
        ChannelColumn {
            icon: {
                if (!root.sink?.ready)            return "󰕾"
                if (root.sink.audio.muted)        return "󰖁"
                if (root.sink.audio.volume > 0.6) return "󰕾"
                if (root.sink.audio.volume > 0.2) return "󰖀"
                return "󰕿"
            }
            value:  root.sink?.ready ? root.sink.audio.volume : 0
            muted:  root.sink?.audio.muted ?? false
            active: root.sink?.ready ?? false

            onVolumeChanged: function(v) {
                if (root.sink?.ready) root.sink.audio.volume = v
            }
            onMuteToggled: {
                if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
            }
        }

        // Brightness Slider
        ChannelColumn {
            icon:   "󰃠"
            value:  BrightnessService.value
            muted:  false
            active: true

            onVolumeChanged: function(v) {
                BrightnessService.set(v)
            }
        }
    }

    // ── Reusable ChannelColumn Component ──────────────────────────────────────
    component ChannelColumn: Item {
        id: col

        property string label:  ""
        property string icon:   ""
        property real   value:  0.0
        property bool   muted:  false
        property bool   active: false

        readonly property int trackHeight: 180
        readonly property int barW:        22
        readonly property int thumbD:      barW - 6

        signal volumeChanged(real value)
        signal muteToggled()

        implicitWidth:  inner.implicitWidth
        implicitHeight: inner.implicitHeight

        readonly property string pctText: active ? Math.round(value * 100) + "%" : "--%"

        Column {
            id: inner
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           col.pctText
                color:          col.muted ? Qt.rgba(1,1,1,0.25) : Theme.text
                font.pixelSize: 13
                font.bold:      true
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  col.barW
                height: col.trackHeight

                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: width / 2
                    color:  Qt.rgba(1,1,1,0.08)

                    // Fill bar
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: Math.max(radius * 2, parent.height * col.value)
                        radius: parent.radius
                        color:  col.muted ? Qt.rgba(1,1,1,0.15) : Theme.active
                        Behavior on color  { ColorAnimation  { duration: 150 } }
                        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }

                    // Thumb
                    Rectangle {
                        id: thumb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width:  col.thumbD
                        height: width
                        radius: width / 2
                        color:  col.muted ? Qt.rgba(1,1,1,0.3) : "#ffffff"
                        y: {
                            var travel = track.height - height
                            return Math.max(0, Math.min(travel, (1.0 - col.value) * travel))
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Drag to change value
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.SizeVerCursor
                        function calc(my) {
                            var travel = track.height - thumb.height
                            return Math.max(0.0, Math.min(1.0, 1.0 - (my - thumb.height / 2) / travel))
                        }
                        onPressed:         col.volumeChanged(calc(mouseY))
                        onPositionChanged: if (pressed) col.volumeChanged(calc(mouseY))
                    }

                    // Scroll wheel to change value
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            var step = 0.05
                            var delta = event.angleDelta.y > 0 ? step : -step
                            col.volumeChanged(Math.max(0.0, Math.min(1.0, col.value + delta)))
                        }
                    }
                }
            }

            // Icon & Mute Toggle
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  col.barW + 16
                height: 28
                radius: Theme.cornerRadius
                color:  col.muted
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
                            : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text:           col.icon
                    font.pixelSize: 14
                    color:          col.muted ? Theme.active : Qt.rgba(1,1,1,0.55)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: muteHov.hovered ? Qt.rgba(1,1,1,0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                HoverHandler { id: muteHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: col.muteToggled()}
            }

            // Label
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:            col.label
                color:           Qt.rgba(1,1,1,0.3)
                font.pixelSize:  10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
                elide:           Text.ElideRight
                width:           col.barW + 50
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
