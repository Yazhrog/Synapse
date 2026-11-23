import QtQuick
import qs.src.components.base
import qs.src.theme
// AppTile — one app in AppLauncher: icon (letter fallback), name and the
// pin toggle. Right-click toggles the pin too. Reports hover, launch and
// pin; the launcher owns the selection.
Rectangle {
    id: card
    property var  app:      ({ name: "", icon: "", pinned: false })
    property bool selected: false
    signal hoverEntered()
    signal launched()
    signal pinToggled()

    height: 46
    radius: 9

    color: card.selected
           ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.14)
           : card.app.pinned
             ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, rowH.hovered ? 0.10 : 0.055)
             : rowH.hovered ? Qt.rgba(1,1,1,0.06) : "transparent"
    border.color: card.selected
                  ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.28)
                  : card.app.pinned
                    ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, rowH.hovered ? 0.30 : 0.18)
                    : rowH.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
    border.width: 1

    Behavior on color        { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }

    HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }

    // Declared before the Row so the pin button stacks above it
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: card.hoverEntered()
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) card.pinToggled()
            else                                 card.launched()
        }
    }

    Row {
        anchors {
            left:   parent.left;  leftMargin:  12
            right:  parent.right; rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 12

        // App icon
        Item {
            width: 28; height: 28
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: ico
                anchors.fill: parent
                source: {
                    var s = card.app.icon
                    if (!s || s === "")    return ""
                    if (s.startsWith("/")) return "file://" + s
                    return "image://icon/" + s
                }
                fillMode:          Image.PreserveAspectFit
                smooth:            true
                sourceSize.width:  28
                sourceSize.height: 28
            }

            // Letter fallback
            Rectangle {
                anchors.fill: parent
                radius:       7
                color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.18)
                visible: ico.status !== Image.Ready || card.app.icon === ""
                Text {
                    anchors.centerIn: parent
                    text:           card.app.name.charAt(0).toUpperCase()
                    font.pixelSize: 13; font.bold: true
                    color:          Theme.color.accent
                }
            }
        }

        // App name
        Text {
            width: parent.width - 28 - pinBtn.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            text:           card.app.name
            font.pixelSize: 13
            color:          card.selected ? Theme.color.accent : Theme.color.text
            elide:          Text.ElideRight
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // Pin toggle — always shown on pinned rows (doubles as
        // the pinned indicator), on hover/selection otherwise
        ActionBtn {
            id: pinBtn
            anchors.verticalCenter: parent.verticalCenter
            icon:    card.app.pinned && rowH.hovered ? "󰐄" : "󰐃"
            active:  card.app.pinned
            opacity: card.app.pinned || card.selected || rowH.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            onClicked: card.pinToggled()
        }
    }
}
