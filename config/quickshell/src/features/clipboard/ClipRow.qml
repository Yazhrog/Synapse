import QtQuick
import qs.src.components.base
import qs.src.services.data
import qs.src.state
import qs.src.theme
// ClipRow — one clipboard entry in HistoryTab: a text preview or an image
// thumbnail, copy / delete / pin actions on hover, double-tap to paste. A
// deleted row collapses before the entry is removed so the list reflows.
Item {
    id: row

    property bool   isPinned:    false
    property string entryId:     ""   // cliphist row id (for history) or storedId (for pinned)
    property string previewText: ""   // cliphist list preview string
    property string fullText:    ""   // full decoded text (pinned items only)
    property bool   isImage:     false
    property int    pinnedIndex: -1

    // Image preview: decoded to a temp file per entry id
    property string _imgPath: ""

    Connections {
        target: ClipboardService
        function onPreviewReady(id, path) { if (id === row.entryId) row._imgPath = path }
    }

    Component.onCompleted: {
        if (row.isImage && row.entryId !== "") ClipboardService.decodePreview(row.entryId)
    }

    // Collapse height to zero for animated removal
    property bool _removing: false

    height:  _removing ? 0 : (card.height + 2)
    opacity: _removing ? 0 : 1
    clip: true

    Behavior on height  { NumberAnimation { duration: 210; easing.type: Easing.InCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // ── Card ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }

        height: Math.max(row.isImage ? 66 : 42, innerRow.height + 18)
        radius: 9

        color: row.isPinned
            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, rHov.hovered ? 0.10 : 0.055)
            : rHov.hovered ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(1, 1, 1, 0.024)

        border.color: row.isPinned
            ? Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, rHov.hovered ? 0.30 : 0.18)
            : rHov.hovered ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.065)
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // ── Inner layout ──────────────────────────────────────────────────────
        Row {
            id: innerRow
            anchors {
                left:           parent.left;  leftMargin:  10
                right:          parent.right; rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 8
            height: Math.max(row.isImage ? 56 : 22, previewLabel.implicitHeight)

            // Left: image thumbnail -OR- text glyph
            Item {
                id:     leftSlot
                width:  row.isImage ? 74 : 18
                height: innerRow.height
                anchors.verticalCenter: parent.verticalCenter

                // ── Image thumbnail ───────────────────────────────────────────
                Rectangle {
                    visible: row.isImage
                    anchors {
                        left: parent.left; top: parent.top
                        bottom: parent.bottom; right: parent.right
                        rightMargin: 6
                    }
                    radius: 6
                    color:  Qt.rgba(1, 1, 1, 0.05)
                    clip:   true

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source:   row._imgPath !== "" ? ("file://" + row._imgPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth:   true
                        asynchronous: true
                        opacity: thumbImg.status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }

                    // Placeholder while loading / no path yet
                    Item {
                        anchors.fill: parent
                        visible: thumbImg.status !== Image.Ready

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(1,1,1,0.03)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "🖼"; font.pixelSize: 18; opacity: 0.22
                        }
                    }
                }

                // ── Text icon glyph ───────────────────────────────────────────
                Text {
                    visible: !row.isImage
                    anchors.verticalCenter: parent.verticalCenter
                    text:           "󰅍"
                    font.pixelSize: 12
                    color:          Qt.rgba(1, 1, 1, 0.22)
                }
            }

            // ── Preview text / image label ─────────────────────────────────────
            Text {
                id: previewLabel
                width: innerRow.width
                       - leftSlot.width
                       - actionsRow.implicitWidth
                       - innerRow.spacing * 2
                       - 2
                anchors.verticalCenter: parent.verticalCenter

                text: row.isImage ? "Image" : row.previewText
                font.pixelSize:   12
                color: row.isImage
                    ? Qt.rgba(1, 1, 1, 0.28)
                    : Qt.rgba(1, 1, 1, 0.78)
                font.italic:      row.isImage
                elide:            Text.ElideRight
                maximumLineCount: 2
                wrapMode:         Text.WordWrap
            }

            // ── Action buttons (appear on hover; pin stays on when pinned) ────
            Row {
                id: actionsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                // Copy
                ActionBtn {
                    icon: "󰆏"
                    opacity: rHov.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    onClicked: {
                        if (row.isPinned) ClipboardService.copyText(row.fullText || row.previewText)
                        else             ClipboardService.copyEntry(row.entryId)
                        Popups.close("clipboard")
                    }
                }

                // Delete / fully remove
                ActionBtn {
                    icon:   "󰩺"
                    danger: true
                    opacity: rHov.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    onClicked: {
                        row._removing = true
                        delayedAction.isPinned    = row.isPinned
                        delayedAction.pinnedIndex = row.pinnedIndex
                        delayedAction.entryId     = row.entryId
                        delayedAction.restart()
                    }
                }

                // Pin / Unpin  (hidden for image entries — images can't be pinned)
                // Always shown on pinned rows (doubles as the pinned indicator)
                ActionBtn {
                    icon:    row.isPinned && rHov.hovered ? "󰐄" : "󰐃"
                    active:  row.isPinned
                    visible: !row.isImage
                    opacity: row.isPinned || rHov.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    onClicked: {
                        if (row.isPinned)
                            ClipboardService.unpinAt(row.pinnedIndex)
                        else
                            ClipboardService.pinEntry(row.entryId, row.previewText)
                    }
                }
            }
        }
    }

    HoverHandler { id: rHov }

    // ── Double-tap: copy + close popup + paste into active field ───────────────
    TapHandler {
        onDoubleTapped: {
            if (row.isPinned) ClipboardService.copyText(row.fullText || row.previewText)
            else             ClipboardService.copyEntry(row.entryId)
            Popups.close("clipboard")
            ClipboardService.typeFromClipboard()
        }
    }

    // Fires after the collapse animation completes so the list reflows smoothly
    Timer {
        id: delayedAction
        property bool   isPinned:    false
        property int    pinnedIndex: -1
        property string entryId:     ""
        interval: 220
        onTriggered: {
            if (isPinned) {
                // Remove from pin list
                if (pinnedIndex >= 0) ClipboardService.unpinAt(pinnedIndex)
                if (entryId !== "") ClipboardService.deleteEntry(entryId)
            } else {
                if (entryId !== "") ClipboardService.deleteEntry(entryId)
            }
        }
    }
}
