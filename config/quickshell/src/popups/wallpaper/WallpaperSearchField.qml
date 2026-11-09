import QtQuick
import "../../"

// WallpaperSearchField — the picker's text box: "Search wallpapers…", or in
// folder mode "Path: <folder>". Keys are passed up as signals; the picker
// decides what they do.

Rectangle {
    id:                 filterBox

    // false: search the wallpapers; true: edit the wallpaper folder
    property bool folderMode: false
    readonly property alias query: searchInput.text
    readonly property bool  focused: searchInput.activeFocus || dirInput.activeFocus

    // Search field keys
    signal applyRequested()            // Enter
    signal stepRequested(int step)     // ← / →
    signal escapePressed()             // Esc
    // Path field: Enter saves the folder, Esc leaves folder mode
    signal folderCommitted(string path)
    signal folderCancelled()

    function clearSearch() { searchInput.text = "" }
    function focusSearch() { searchInput.forceActiveFocus() }
    function focusPath(path) {
        dirInput.text = path
        dirInput.forceActiveFocus()
        dirInput.selectAll()
    }

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
        visible: !filterBox.folderMode

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

            Keys.onReturnPressed: filterBox.applyRequested()
            Keys.onLeftPressed:   filterBox.stepRequested(-1)
            Keys.onRightPressed:  filterBox.stepRequested(1)
            Keys.onEscapePressed: filterBox.escapePressed()
        }
    }

    Item {
        anchors.fill:        parent
        anchors.leftMargin:  10
        anchors.rightMargin: 10
        visible:             filterBox.folderMode

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
            Keys.onReturnPressed: filterBox.folderCommitted(dirInput.text)
            Keys.onEscapePressed: filterBox.folderCancelled()
        }
    }
}
