import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import "../components"
import "../services"
import "../"

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
        searchInput.text             = ""
        searchInput.forceActiveFocus()
    }

    function focusSearch() { searchInput.forceActiveFocus() }

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

        property string searchQuery:     ""
        property bool   schemePopupOpen: false
        property bool   folderMode:      false
        property string appliedScheme:   WallpaperService.scheme

        readonly property var filteredWallpapers: {
            var q = searchQuery.toLowerCase()
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

            delegate: Item {
                id:                      cardDelegate
                required property string modelData
                required property int    index
                property bool isPreview: WallpaperService.previewWall === modelData
                property bool isCurrent: WallpaperService.currentWall === modelData
                readonly property int labelH: 30

                width:  isPreview ? (130 * 1.2) : 130
                height: isPreview ? wallGrid.height : wallGrid.height - 14
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.InOutCubic } }

                Item {
                    id:           cardContent
                    anchors.fill: parent
                    visible:      false

                    Image {
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        anchors.top:   parent.top
                        height:        parent.height - cardDelegate.labelH
                        source:        modelData.indexOf("://") !== -1 ? modelData : "file://" + modelData
                        fillMode:      Image.PreserveAspectCrop
                        asynchronous:  true
                        cache:         true
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height: cardDelegate.labelH
                        color: isPreview
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                            : Qt.rgba(1,1,1,0.09)

                        Text {
                            anchors.centerIn: parent
                            width:               parent.width - 10
                            text:                modelData.split("/").pop().replace(/\.[^/.]+$/, "")
                            color:               isPreview ? Theme.active : Qt.rgba(1,1,1,0.65)
                            font.pixelSize:      10
                            font.weight:         isPreview ? Font.Medium : Font.Normal
                            elide:               Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Rectangle {
                    id: cardMask
                    anchors.fill: parent
                    radius: 10
                    visible: false
                    layer.enabled: true
                }

                MultiEffect {
                    source: cardContent
                    anchors.fill: parent
                    maskEnabled: true
                    maskSource: cardMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.width: isPreview ? 2 : 1
                    border.color: isPreview ? Theme.active
                        : isCurrent ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
                        : Qt.rgba(1,1,1,0.15)
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on border.width { NumberAnimation  { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        content.schemePopupOpen = false
                        if (cardDelegate.isPreview) {
                            content.appliedScheme = WallpaperService.scheme
                            WallpaperService.apply(cardDelegate.modelData)
                            Popups.close("wallpaper")
                        } else {
                            WallpaperService.previewWall = cardDelegate.modelData
                        }
                    }
                }
            }
        }

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

                Rectangle {
                    id:                 folderBtn
                    width:              32
                    height:             32
                    radius:             8
                    color: folderBtnMA.containsMouse 
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14) 
                           : (content.folderMode ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : Qt.rgba(1,1,1,0.04))
                    border.color: (content.folderMode || folderBtnMA.containsMouse)
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                        : Qt.rgba(1,1,1,0.09)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent; text: "󰉋"; font.pixelSize: 15
                        color: (content.folderMode || folderBtnMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.5)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    MouseArea {
                        id:                 folderBtnMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            content.schemePopupOpen = false
                            content.folderMode = !content.folderMode
                            if (content.folderMode) {
                                dirInput.text = WallpaperService.wallpaperDir
                                dirInput.forceActiveFocus()
                                dirInput.selectAll()
                            } else {
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }

                Rectangle {
                    id:                 filterBox
                    width:              300
                    height:             32
                    radius:             8
                    color: filterBoxMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.06)
                    border.color: (searchInput.activeFocus || dirInput.activeFocus)
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                        : (filterBoxMA.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.1))
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id:                 filterBoxMA
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    Item {
                        anchors.fill:        parent
                        anchors.leftMargin:  10
                        anchors.rightMargin: 10
                        visible: !content.folderMode

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search wallpapers…"
                            color: (searchInput.activeFocus || filterBoxMA.containsMouse) ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7) : Qt.rgba(1,1,1,0.28)
                            font.pixelSize: 12; visible: searchInput.text === ""
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill:      parent
                            verticalAlignment: TextInput.AlignVCenter
                            color:             Theme.text
                            font.pixelSize:    12
                            selectionColor:    Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                            clip:              true
                            onTextChanged:     content.searchQuery = text

                            Keys.onReturnPressed: {
                                var walls = content.filteredWallpapers
                                if (!walls || walls.length === 0) return
                                var previewInSearch = false
                                for (var i = 0; i < walls.length; i++) {
                                    if (walls[i] === WallpaperService.previewWall) { previewInSearch = true; break }
                                }
                                var target = previewInSearch ? WallpaperService.previewWall : walls[0]
                                content.appliedScheme = WallpaperService.scheme
                                WallpaperService.apply(target)
                                Popups.close("wallpaper")
                            }
                            Keys.onLeftPressed: {
                                var walls = content.filteredWallpapers
                                if (!walls || walls.length === 0) return
                                var cur = WallpaperService.previewWall; var idx = -1
                                for (var i = 0; i < walls.length; i++) { if (walls[i] === cur) { idx = i; break } }
                                idx = (idx <= 0) ? walls.length - 1 : idx - 1
                                WallpaperService.previewWall = walls[idx]
                                wallGrid.positionViewAtIndex(idx, ListView.Center)
                            }
                            Keys.onRightPressed: {
                                var walls = content.filteredWallpapers
                                if (!walls || walls.length === 0) return
                                var cur = WallpaperService.previewWall; var idx = -1
                                for (var i = 0; i < walls.length; i++) { if (walls[i] === cur) { idx = i; break } }
                                idx = (idx < 0 || idx >= walls.length - 1) ? 0 : idx + 1
                                WallpaperService.previewWall = walls[idx]
                                wallGrid.positionViewAtIndex(idx, ListView.Center)
                            }
                            Keys.onEscapePressed: {
                                if (searchInput.text !== "") {
                                    var target = WallpaperService.previewWall !== ""
                                        ? WallpaperService.previewWall : WallpaperService.currentWall
                                    var walls = WallpaperService.wallpapers; var idx = 0
                                    for (var i = 0; i < walls.length; i++) { if (walls[i] === target) { idx = i; break } }
                                    searchInput.text = ""
                                    wallGrid.forceLayout()
                                    wallGrid.positionViewAtIndex(idx, ListView.Center)
                                } else { Popups.closeAll() }
                            }
                        }
                    }

                    Item {
                        anchors.fill:        parent
                        anchors.leftMargin:  10
                        anchors.rightMargin: 10
                        visible:             content.folderMode

                        Text {
                            id: pathLbl
                            anchors.left:           parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:                   "Path: "
                            color:                  (dirInput.activeFocus || filterBoxMA.containsMouse) ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
                            font.pixelSize:         11
                        }

                        TextInput {
                            id:                dirInput
                            anchors.left:      pathLbl.right
                            anchors.right:     parent.right
                            anchors.top:       parent.top
                            anchors.bottom:    parent.bottom
                            verticalAlignment: TextInput.AlignVCenter
                            color:             Theme.text
                            font.pixelSize:    12
                            font.family:       "JetBrainsMono Nerd Font"
                            selectionColor:    Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                            clip:              true
                            Keys.onReturnPressed: {
                                WallpaperService.wallpaperDir = dirInput.text
                                WallpaperService.refresh()
                                content.folderMode = false
                                searchInput.forceActiveFocus()
                            }
                            Keys.onEscapePressed: {
                                content.folderMode = false
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }

                Rectangle {
                    id:                 schemeBtn
                    width:              schemeBtnRow.implicitWidth + 20
                    height:             32
                    radius:             8
                    color: schemeBtnMA.containsMouse 
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14) 
                           : (content.schemePopupOpen ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : Qt.rgba(1,1,1,0.04))
                    border.color: (content.schemePopupOpen || schemeBtnMA.containsMouse)
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                        : Qt.rgba(1,1,1,0.09)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Row {
                        id:                 schemeBtnRow; anchors.centerIn: parent; spacing: 7
                        Text {
                            text:                   "󰏘"
                            font.pixelSize:         14
                            color:                  (content.schemePopupOpen || schemeBtnMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.55)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color       { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            text:                   WallpaperService.scheme
                            font.pixelSize:         12
                            color:                  (content.schemePopupOpen || schemeBtnMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.7)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color       { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            text:                   content.schemePopupOpen ? "▴" : "▾"
                            font.pixelSize:         8
                            color:                  (content.schemePopupOpen || schemeBtnMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.35)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id:           schemeBtnMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    content.schemePopupOpen = !content.schemePopupOpen
                    }
                }
            }

            Rectangle {
                id: applyBtn
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                property bool active:   content.applyActive
                width:                  active ? 90 : 0
                height:                 32
                radius:                 8
                opacity:                active ? 1 : 0
                clip:                   true
                color: applyBtnMA.containsMouse
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                border.color: applyBtnMA.containsMouse
                    ? Theme.active
                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                border.width: 1
                Behavior on width        { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on opacity      { NumberAnimation { duration: 160 } }
                Behavior on color        { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }
                Text {
                    anchors.centerIn: parent
                    text:             WallpaperService.applying ? "…" : "Apply"
                    font.pixelSize:   12
                    font.weight:      Font.Medium 
                    color:            Theme.active
                    opacity:          applyBtn.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }
                MouseArea {
                    id:           applyBtnMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    enabled:      applyBtn.active && !WallpaperService.applying
                    onClicked: {
                        var target = WallpaperService.previewWall !== ""
                            ? WallpaperService.previewWall : WallpaperService.currentWall
                        content.appliedScheme = WallpaperService.scheme
                        WallpaperService.apply(target)
                        Popups.close("wallpaper")
                    }
                }
            }
        }

        TapHandler {
            enabled:  content.schemePopupOpen
            onTapped: content.schemePopupOpen = false
        }
    }

    Rectangle {
        id: schemeDropdown
        z:       100
        visible: content.schemePopupOpen
        clip:    false

        width:  schemeDropdownCol.implicitWidth + 32
        height: schemeDropdownCol.implicitHeight + 16
        radius: Theme.cornerRadius

        color:        Theme.background
        border.color: Theme.active
        border.width: 1

        opacity:            content.schemePopupOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        onVisibleChanged: {
            if (visible) {
                var pos = schemeBtn.mapToItem(root, 0, 0)
                x = Math.min(pos.x, root.width - width - 4)
                y = pos.y - height - 6
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        ColumnLayout {
            id:               schemeDropdownCol
            anchors.centerIn: parent
            spacing:          4

            Repeater {
                model: WallpaperService.schemes
                delegate: Rectangle {
                    id: schemeItem
                    required property string modelData
                    property bool sel: WallpaperService.scheme === modelData

                    Layout.fillWidth: true
                    // Pad minimumWidth to ensure space between text and rectangle edges
                    Layout.minimumWidth: schemeItemText.implicitWidth + 40 
                    Layout.preferredHeight: 32

                    radius: 8
                    color: schemeItemMA.containsMouse 
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14) 
                        : (sel ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : "transparent")

                    border.color: (sel || schemeItemMA.containsMouse) 
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                        : "transparent"
                    border.width: 1

                    Behavior on color        { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12
                        spacing: 10

                        Text {
                            text:                   sel ? "●" : "○"
                            font.pixelSize:         10
                            color:                  (sel || schemeItemMA.containsMouse) ? Theme.active : Qt.rgba(1,1,1,0.3)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id:                     schemeItemText
                            text:                   modelData
                            font.pixelSize:         13
                            color:                  (sel || schemeItemMA.containsMouse) ? Theme.text : Qt.rgba(1,1,1,0.65)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id:           schemeItemMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            WallpaperService.scheme = modelData
                            content.schemePopupOpen = false
                        }
                    }
                }
            }
        }
    }
}
