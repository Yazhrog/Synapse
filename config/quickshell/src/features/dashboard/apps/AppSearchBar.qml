import QtQuick
import qs.src.theme
// AppSearchBar — AppLauncher's search field: placeholder, a shortcut hint,
// and the keys that drive the list (reported as signals; the launcher owns
// the query and the selection).
Rectangle {
    id: searchBar
    property alias text: searchInput.text
    // Shown on the right while the field is empty.
    property string hint: ""
    signal edited(string text)
    signal moved(int delta)          // Up / Down
    signal pinMoved(int delta)       // Ctrl+Shift+Up / Down
    signal pinToggled()              // Ctrl+P
    signal accepted()                // Enter
    signal closeRequested()          // Escape on an empty field

    function focusInput() { searchInput.forceActiveFocus() }

    height: 44; radius: 12
    color: Qt.rgba(1,1,1,0.06)
    border.color: searchInput.activeFocus
                  ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.50)
                  : Qt.rgba(1,1,1,0.12)
    border.width: 1
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Row {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"; font.pixelSize: 16
            color: searchInput.activeFocus
                   ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.7)
                   : Qt.rgba(1,1,1,0.35)
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
            width: parent.width - 26 - parent.spacing
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:    "Search apps…"
                color:   Qt.rgba(1,1,1,0.22)
                font.pixelSize: 13
                visible: searchInput.text === ""
            }

            // Pin shortcut hint, for whichever row is selected
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: searchBar.hint
                color:   Qt.rgba(1,1,1,0.22)
                font.pixelSize: 11
                visible: searchInput.text === "" && searchBar.hint !== ""
            }

            TextInput {
                id: searchInput
                anchors { fill: parent; topMargin: 2; bottomMargin: 2 }
                verticalAlignment: TextInput.AlignVCenter
                color:          Theme.color.text
                font.pixelSize: 13
                selectionColor: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.35)
                clip: true

                onTextChanged: searchBar.edited(text)

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        searchBar.pinToggled()
                        event.accepted = true
                    }
                }

                Keys.onUpPressed: function(event) {
                    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                        searchBar.pinMoved(-1)
                        return
                    }
                    searchBar.moved(-1)
                }

                Keys.onDownPressed: function(event) {
                    if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
                        searchBar.pinMoved(1)
                        return
                    }
                    searchBar.moved(1)
                }

                Keys.onReturnPressed: searchBar.accepted()

                Keys.onEscapePressed: {
                    if (text !== "") {
                        text = ""
                    } else {
                        searchBar.closeRequested()
                    }
                }
            }
        }
    }
}
