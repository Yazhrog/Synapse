import QtQuick
import "../../"

// NotchCountItem — the timer or the stopwatch in the notch: icon on the
// left, the time in the middle, play / pause and reset on the right.
// While `urgent` (the timer's last 30 s) the icon and time turn red and
// the time blinks.

Item {
    id: root

    property string glyph:   ""
    property string display: ""
    property bool   running: false
    property bool   urgent:  false

    signal toggled()
    signal reset()

    readonly property int fw: Theme.notchRadius

    Text {
        anchors { left: parent.left; leftMargin: root.fw; verticalCenter: parent.verticalCenter }
        text:           root.glyph
        font.pixelSize: 16
        color:          root.urgent ? "#ff5555" : Theme.active
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Text {
        id: timeText
        anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text:           root.display
        font.pixelSize: 15
        font.weight:    Font.Bold
        font.family:    "JetBrainsMono Nerd Font"
        horizontalAlignment: Text.AlignHCenter
        color:          root.urgent ? "#ff5555" : Theme.text
        Behavior on color { ColorAnimation { duration: 200 } }

        // Blink while urgent — 1 → 0.25 → 1
        SequentialAnimation on opacity {
            id: blink
            running: root.urgent
            loops:   Animation.Infinite
            NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
        }
        // Snap back to full opacity when the blink stops
        Connections {
            target: blink
            function onRunningChanged() { if (!blink.running) timeText.opacity = 1.0 }
        }
    }

    Row {
        anchors { right: parent.right; rightMargin: root.fw; verticalCenter: parent.verticalCenter }
        spacing: root.fw

        NotchGlyphButton {
            anchors.verticalCenter: parent.verticalCenter
            text: root.running ? "󱫟" : "󱫡"
            onClicked: root.toggled()
        }
        NotchGlyphButton {
            anchors.verticalCenter: parent.verticalCenter
            text: "󱫥"
            onClicked: root.reset()
        }
    }
}
