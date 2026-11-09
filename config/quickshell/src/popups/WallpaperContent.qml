import QtQuick
import QtQuick.Controls
import Quickshell
import "../components"
import "../services"
import "../"
import "wallpaper"

// WallpaperContent — the wallpaper picker UI: horizontal wallpaper strip,
// search, folder mode, colour scheme dropdown and apply. Fills the popup body
// (including the flare margins `fw`/`fh`). Hosted by the bottom-center region of
// DynamicSurface.
Item {
    id: root

    property bool open: false
    property int  fw:   Theme.notchRadius
    property int  fh:   Theme.notchRadius

    // Reset the picker each time it opens (also when created already open).
    onOpenChanged: if (open) reset()
    Component.onCompleted: if (open) reset()

    function reset() {
        WallpaperService.refresh()
        WallpaperService.previewWall = ""
        content.schemePopupOpen      = false
        content.folderMode           = false
        content.appliedScheme        = WallpaperService.scheme
        searchField.clearSearch()
        // No focus here: the surface calls focusSearch() once it has the
        // keyboard. Focusing twice makes Qt's Wayland text-input re-enable
        // the surface and log a warning.
    }

    function focusSearch() { searchField.focusSearch() }

    // Applies `path` (with the chosen scheme) and closes the picker.
    function applyWall(path) {
        content.appliedScheme = WallpaperService.scheme
        WallpaperService.apply(path)
        Popups.close("wallpaper")
    }

    // ← / → in the search field: preview the previous / next match, wrapping.
    function stepPreview(step) {
        var walls = content.filteredWallpapers
        if (!walls || walls.length === 0) return
        var idx = walls.indexOf(WallpaperService.previewWall)
        if (step < 0) idx = (idx <= 0) ? walls.length - 1 : idx - 1
        else          idx = (idx < 0 || idx >= walls.length - 1) ? 0 : idx + 1
        WallpaperService.previewWall = walls[idx]
        wallGrid.positionViewAtIndex(idx, ListView.Center)
    }

    Connections {
        target: WallpaperService
        function onWallpapersChanged() {
            if (!root.open) return
            var walls = WallpaperService.wallpapers
            if (!walls || walls.length === 0) return
            var target = WallpaperService.currentWall
            for (var i = 0; i < walls.length; i++) {
                if (walls[i] === target) {
                    WallpaperService.previewWall = target
                    wallGrid.targetCenterIndex   = i
                    centerLockTimer.restart()
                    wallGrid.forceLayout()
                    wallGrid.positionViewAtIndex(i, ListView.Center)
                    return
                }
            }
        }
    }

    Timer {
        id: centerLockTimer
        interval: Theme.animDuration
        onTriggered: wallGrid.targetCenterIndex = -1
    }

    Item {
        id: content
        focus: true
        anchors {
            fill:         parent
            topMargin:    16
            bottomMargin: root.fh + 8
            leftMargin:   root.fw + 16
            rightMargin:  root.fw + 16
        }

        property bool   schemePopupOpen: false
        property bool   folderMode:      false
        property string appliedScheme:   WallpaperService.scheme

        readonly property var filteredWallpapers: {
            var q = searchField.query.toLowerCase()
            if (q === "") return WallpaperService.wallpapers
            return WallpaperService.wallpapers.filter(function(p) {
                return p.split("/").pop().toLowerCase().indexOf(q) !== -1
            })
        }

        readonly property bool applyActive:
            WallpaperService.previewWall !== "" ||
            (WallpaperService.currentWall !== "" &&
             WallpaperService.scheme !== content.appliedScheme)

        opacity: root.open ? 1 : 0
        transform: Translate {
            y: root.open ? 0 : 40
            Behavior on y { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? Theme.animDuration * 0.5 : Theme.animDuration * 0.15
            }
        }

        // ── Wallpaper strip ───────────────────────────────────────────────────
        ListView {
            id: wallGrid
            property int targetCenterIndex: -1
            onWidthChanged: {
                if (root.open && targetCenterIndex !== -1 && count > targetCenterIndex)
                    positionViewAtIndex(targetCenterIndex, ListView.Center)
            }

            anchors.top:          parent.top
            anchors.left:         parent.left
            anchors.right:        parent.right
            anchors.bottom:       divider.top
            anchors.bottomMargin: 8

            orientation:    ListView.Horizontal
            spacing:        14
            clip:           true
            boundsBehavior: Flickable.StopAtBounds
            interactive:    false
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                height: 6
            }
            model: content.filteredWallpapers

            Text {
                anchors.centerIn: parent
                visible:          wallGrid.count === 0
                text:             "No wallpapers found in " + WallpaperService.wallpaperDir
                color:            Qt.rgba(1,1,1,0.25)
                font.pixelSize:   13
            }

            // First click previews, a click on the previewed card applies it
            delegate: WallpaperCard {
                id: card
                stripHeight: wallGrid.height
                onClicked: {
                    content.schemePopupOpen = false
                    if (card.isPreview) root.applyWall(card.modelData)
                    else                WallpaperService.previewWall = card.modelData
                }
            }
        }

        // Wheel / touchpad scrolls the strip horizontally
        MouseArea {
            anchors.top:          parent.top
            anchors.left:         parent.left
            anchors.right:        parent.right
            anchors.bottom:       divider.top
            anchors.bottomMargin: 8
            z:                    wallGrid.z + 1
            acceptedButtons:      Qt.NoButton
            onWheel: function(wheel) {
                const delta = (wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0)
                    ? (wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.pixelDelta.y)
                    : (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y)
                wallGrid.contentX = Math.max(0,
                    Math.min(wallGrid.contentWidth - wallGrid.width,
                        wallGrid.contentX - delta))
            }
        }

        Rectangle {
            id: divider
            anchors.bottom:       utilBar.top
            anchors.bottomMargin: 8
            anchors.left:         parent.left
            anchors.right:        parent.right
            height: 1
            color: Qt.rgba(1,1,1,0.07)
        }

        // ── Bottom bar: folder · search / path · scheme … Apply ───────────────
        Item {
            id: utilBar
            anchors.bottom:       parent.bottom
            anchors.bottomMargin: -20
            anchors.left:         parent.left
            anchors.right:        parent.right
            height: 32

            Row {
                anchors.centerIn: parent
                spacing: 8

                WallpaperToolButton {
                    icon:   "󰉋"
                    active: content.folderMode
                    onClicked: {
                        content.schemePopupOpen = false
                        content.folderMode = !content.folderMode
                        if (content.folderMode) searchField.focusPath(WallpaperService.wallpaperDir)
                        else                    searchField.focusSearch()
                    }
                }

                WallpaperSearchField {
                    id: searchField
                    folderMode: content.folderMode

                    onApplyRequested: {
                        var walls = content.filteredWallpapers
                        if (!walls || walls.length === 0) return
                        // The previewed wallpaper if it matches the search, else the first match
                        root.applyWall(walls.indexOf(WallpaperService.previewWall) >= 0
                                       ? WallpaperService.previewWall : walls[0])
                    }
                    onStepRequested: function(step) { root.stepPreview(step) }
                    onEscapePressed: {
                        if (searchField.query === "") { Popups.closeAll(); return }
                        // Clear the search and keep the previewed (or current) wallpaper centred
                        var target = WallpaperService.previewWall !== ""
                            ? WallpaperService.previewWall : WallpaperService.currentWall
                        var idx = Math.max(0, WallpaperService.wallpapers.indexOf(target))
                        searchField.clearSearch()
                        wallGrid.forceLayout()
                        wallGrid.positionViewAtIndex(idx, ListView.Center)
                    }
                    onFolderCommitted: function(path) {
                        WallpaperService.wallpaperDir = path
                        WallpaperService.refresh()
                        content.folderMode = false
                        searchField.focusSearch()
                    }
                    onFolderCancelled: {
                        content.folderMode = false
                        searchField.focusSearch()
                    }
                }

                WallpaperToolButton {
                    id: schemeBtn
                    icon:      "󰏘"
                    label:     WallpaperService.scheme
                    showArrow: true
                    active:    content.schemePopupOpen
                    onClicked: content.schemePopupOpen = !content.schemePopupOpen
                }
            }

            WallpaperApplyButton {
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                active: content.applyActive
                onClicked: root.applyWall(WallpaperService.previewWall !== ""
                                          ? WallpaperService.previewWall : WallpaperService.currentWall)
            }
        }

        TapHandler {
            enabled:  content.schemePopupOpen
            onTapped: content.schemePopupOpen = false
        }
    }

    SchemeDropdown {
        z: 100
        open:       content.schemePopupOpen
        anchorItem: schemeBtn
        bounds:     root
        onCloseRequested: content.schemePopupOpen = false
    }
}
