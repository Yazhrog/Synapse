import QtQuick
import Quickshell.Io
import "../"
import "../../"
import "../../components"

// Dashboard Home tab — layout only.
//
//  ┌──────────────┬───────────────────────────┬──────────────┐
//  │ ProfileCard  │  ClockCard                │              │
//  ├──────────────┤                           │ QuickSettings│
//  │ CalendarCard │  PlayerCard               │ (brightness  │
//  │              │                           │  + toggles)  │
//  └──────────────┴───────────────────────────┴──────────────┘

Item {
    id: root

    readonly property int colW:    210
    readonly property int gap:       8
    readonly property int profileH: 160
    readonly property int clockH:   220

    // The dashboard closed: back to the clock view.
    function reset() { clockCard.reset() }

    // ── Avatar path ───────────────────────────────────────────────────────────
    // Both gif (magick frame) and non-gif (symlink) cases land at the same
    // curr_wall_static.jpg, so no readlink resolution is needed.
    readonly property string _staticJpg: Paths.wallpaperDir + "/curr_wall_static.jpg"
    property string _avatarPath: _staticJpg

    // Re-arm the image on every successful apply.
    // Because the path never changes, Qt's image cache would serve the old
    // texture. Clearing _avatarPath for one frame then restoring it forces
    // the Image to re-read the file from disk.
    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            root._avatarPath = ""
            reloadTimer.restart()
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        repeat:   false
        onTriggered: root._avatarPath = root._staticJpg
    }

    // ── Left column ───────────────────────────────────────────────────────────
    Item {
        id: leftCol
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW

        ProfileCard {
            id: profileCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.profileH
            // Custom avatar from Config → General, else the wallpaper.
            avatarPath: PrefsService.avatarPath.trim() !== ""
                ? Paths.expand(PrefsService.avatarPath) : root._avatarPath
        }

        CalendarCard {
            anchors {
                left: parent.left; right: parent.right
                top: profileCard.bottom; topMargin: root.gap
                bottom: parent.bottom
            }
        }
    }

    // ── Right column — QuickSettings fills full height ────────────────────────
    QuickSettings {
        id: rightCard
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: root.gap }
        width: root.colW
    }

    // ── Center column ─────────────────────────────────────────────────────────
    Item {
        id: centerCol
        anchors {
            left:  leftCol.right;  leftMargin:  root.gap
            right: rightCard.left; rightMargin: root.gap
            top:   parent.top;     bottom:      parent.bottom
            topMargin: root.gap
        }

        ClockCard {
            id: clockCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.clockH
        }

        PlayerCard {
            anchors {
                left:   parent.left;  right:  parent.right
                top:    clockCard.bottom; topMargin: root.gap
                bottom: parent.bottom
            }
        }
    }
}
