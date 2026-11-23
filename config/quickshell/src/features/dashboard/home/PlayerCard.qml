import QtQuick
import qs.src.services.media
import qs.src.theme
// PlayerCard — the Home page's media card: blurred cover art, title and
// artist, transport controls, progress, a player picker when several are
// running, and cava bars along the bottom.
Item {
    id: root

    // ── MPRIS (MediaService picks the player) ─────────────────────────────────
    readonly property var filteredPlayers:     MediaService.players
    readonly property int selectedPlayerIndex: MediaService.selectedIndex
    onVisibleChanged: if (!visible) sourcePicker.open = false

    readonly property var  player:    MediaService.player
    readonly property bool isPlaying: MediaService.isPlaying
    readonly property string artUrl:    root.player?.trackArtUrl ?? ""

    readonly property string title: {
        var t = root.player?.trackTitle
        return (t && t !== "") ? t : "Nothing Playing"
    }
    readonly property string artist: {
        var a = root.player?.trackArtists
        if (!a) return ""
        if (typeof a === "string") return a
        if (typeof a.join === "function") return a.join(", ")
        return a.toString()
    }

    readonly property real length:   root.player?.length   ?? 0
    readonly property real position: root.player?.position ?? 0

    property real _pos: 0
    onPositionChanged: root._pos = position

    Timer {
        interval: 1000; running: root.isPlaying; repeat: true
        onTriggered: {
            if (root.length > 0)
                root._pos = Math.min(root._pos + 1, root.length)
        }
    }

    // ── Shared cava bars (32 bars from CavaService) ───────────────────────────
    readonly property int _cavaBars: 32
    readonly property var _bars: CavaService.bars

    // ── Background visuals ────────────────────────────────────────────────────
    PlayerArt { anchors.fill: parent; artUrl: root.artUrl }

    // ── Track name + artist ───────────────────────────────────────────────────
    Column {
        anchors {
            left:  parent.left;  leftMargin:  14
            right: parent.right; rightMargin: 14
            top:   parent.top;   topMargin:   16
        }
        spacing: 4
        Text {
            width: parent.width
            text:  root.title
            font.pixelSize: 18; font.weight: Font.Bold
            color: "#ffffff"; elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width:   parent.width
            text:    root.artist
            visible: root.artist !== ""
            font.pixelSize: 13
            color: Qt.rgba(1,1,1,0.55); elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Bottom stack: controls + progress (raised to give room for picker) ──────
    Column {
        anchors {
            left:   parent.left;   leftMargin:   14
            right:  parent.right;  rightMargin:  14
            bottom: parent.bottom; bottomMargin: 54
        }
        spacing: 6

        // Controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28
            Repeater {
                model: [ { key: "prev" }, { key: "play" }, { key: "next" } ]
                delegate: Rectangle {
                    required property var  modelData
                    required property int  index
                    readonly property bool isPlay: modelData.key === "play"
                    readonly property string dispIcon: {
                        if (modelData.key === "prev") return "\u23EE"
                        if (modelData.key === "next") return "\u23ED"
                        return root.isPlaying ? "\u23F8" : "\u23F5"
                    }
                    width:  isPlay ? 44 : 36; height: isPlay ? 44 : 36
                    radius: height / 2
                    color: isPlay
                           ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.18)
                           : cH.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.06)
                    border.color: isPlay ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.3) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.dispIcon
                        font.pixelSize: isPlay ? 18 : 14
                        color: isPlay ? Theme.color.accent : Qt.rgba(1,1,1,0.7)
                    }
                    HoverHandler { id: cH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            switch (modelData.key) {
                                case "play": MediaService.togglePlaying(); break
                                case "prev": MediaService.previous();      break
                                case "next": MediaService.next();          break
                            }
                        }
                    }
                }
            }
        }

        // Progress bar + timestamps
        PlayerProgress {
            width:    parent.width
            position: root._pos
            length:   root.length
            canSeek:  !!root.player && root.length > 0
            onSeekRequested: seconds => {
                MediaService.seek(seconds)
                root._pos = seconds
            }
        }
    }

    // ── Source picker — upward-expanding pill ─────────────────────────────────
    // Sits in the gap between the controls and the card bottom; expands upward.
    PlayerSourcePicker {
        id: sourcePicker
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom:           parent.bottom
            bottomMargin:     12
        }
        visible:       root.filteredPlayers.length > 1
        z:             30
        players:       root.filteredPlayers
        selectedIndex: root.selectedPlayerIndex
        player:        root.player
        onSelected:    index => MediaService.select(index)
    }

    // ── Cava bars — independent, always flush with the card bottom ────────────
    Item {
        visible: CavaService.enabled
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 32
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 2
            readonly property real barW: Math.max(1, (parent.width - spacing * (root._cavaBars - 1)) / root._cavaBars)
            Repeater {
                model: root._bars
                delegate: Item {
                    required property int modelData
                    required property int index
                    width: parent.barW; height: 32
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width:  parent.width
                        readonly property real _amp: root.isPlaying ? (modelData / 100) : 0
                        height: Math.max(2, _amp * 32)
                        radius: width / 2
                        color:  Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.25 + _amp * 0.65)
                        Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius:       Theme.radius.card
        color:        "transparent"
        border.color: Qt.rgba(1,1,1,0.08)
        border.width: 1
    }

    // Close dropdown on click outside
    TapHandler {
        enabled: sourcePicker.open
        onTapped: sourcePicker.open = false
    }
}
