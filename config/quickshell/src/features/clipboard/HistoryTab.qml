import QtQuick
import QtQuick.Controls
import qs.src.core
import qs.src.services.data
import qs.src.state
import qs.src.theme
// HistoryTab — the clipboard popup: pinned entries, then the history (minus
// what is pinned), each a ClipRow; loading and empty states.
Item {
    id: root

    // ClipboardService reloads the history while the popup is open.
    Lease { service: ClipboardService; active: Popups.clipboardOpen }

    readonly property var pinned:  ClipboardService.pinned  ?? []
    readonly property var history: ClipboardService.entries ?? []

    // ── Flat unified model ─────────────────────────────────────────────────────
    readonly property var flatModel: {
        var result = []
        var pins   = root.pinned
        var hist   = root.history

        // Build fast-lookup set of pinned previews/texts for O(1) dedup
        var lookup = {}
        for (var k = 0; k < pins.length; k++) {
            if (pins[k].preview) lookup[pins[k].preview] = true
            if (pins[k].text)    lookup[pins[k].text]    = true
        }

        // Pinned section (top)
        for (var pi = 0; pi < pins.length; pi++) {
            result.push({
                kind:     "pinned",
                text:     pins[pi].text    ?? "",
                preview:  pins[pi].preview ?? pins[pi].text ?? "",
                storedId: pins[pi].id      ?? "",
                pinIndex: pi,
                isImage:  false
            })
        }

        // History section
        for (var hi = 0; hi < hist.length; hi++) {
            var e = hist[hi]
            if (!e.isImage && (lookup[e.preview] || lookup[(e.preview ?? "").trim()])) continue
            result.push({
                kind:    "entry",
                id:      e.id,
                preview: e.preview,
                isImage: e.isImage ?? false
            })
        }

        return result
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Header ─────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 44

            Text {
                anchors.centerIn: parent
                text:           "Clipboard"
                font.pixelSize: 14
                font.weight:    Font.DemiBold
                color:          Theme.color.text
            }

            // Clear unpinned history button
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                width:  clearRow.implicitWidth + 14
                height: 26; radius: 8
                color: clearH.hovered
                    ? Qt.rgba(248/255, 113/255, 113/255, 0.18)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(248/255, 113/255, 113/255, clearH.hovered ? 0.38 : 0.12)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰩺"; font.pixelSize: 12
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clear"; font.pixelSize: 10
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                HoverHandler { id: clearH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: ClipboardService.wipeHistory() }
            }
        }

        // Divider
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

        // ── Content ────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: parent.height - 45

            // Loading state
            Column {
                anchors.centerIn: parent; spacing: 10
                visible: (ClipboardService.loading ?? false)
                         && root.history.length === 0
                         && root.pinned.length  === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "○"; font.pixelSize: 22; color: Theme.color.accent
                    SequentialAnimation on opacity {
                        running: parent.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 500 }
                        NumberAnimation { to: 1.0;  duration: 500 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Loading…"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.25)
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent; spacing: 10
                visible: !(ClipboardService.loading ?? false)
                         && root.history.length === 0
                         && root.pinned.length  === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰅍"; font.pixelSize: 32; color: Qt.rgba(1,1,1,0.08)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Clipboard is empty"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.20)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Copy something to get started"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.13)
                }
            }

            // ── List ───────────────────────────────────────────────────────────
            ListView {
                id: mainList
                anchors {
                    fill:         parent
                    topMargin:    6
                    leftMargin:   2
                    rightMargin:  12 
                    bottomMargin: 4
                }
                clip:           true
                spacing:        4
                boundsBehavior: Flickable.StopAtBounds
                visible:        root.flatModel.length > 0
                model:          root.flatModel

                // Point to the detached scrollbar below
                ScrollBar.vertical: vbar

                // Smooth repositioning when items are removed
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
                }

                delegate: ClipRow {
                    required property var modelData
                    required property int index
                    width: mainList.width - 4

                    isPinned:    modelData.kind === "pinned"
                    entryId:     modelData.kind === "pinned" ? (modelData.storedId ?? "") : (modelData.id ?? "")
                    previewText: modelData.preview ?? ""
                    fullText:    modelData.kind === "pinned" ? (modelData.text ?? "") : ""
                    isImage:     modelData.isImage ?? false
                    pinnedIndex: modelData.kind === "pinned" ? modelData.pinIndex : -1
                }
            }

            // ── External Scrollbar placed at the absolute edge ────────────────
            ScrollBar {
                id: vbar
                anchors {
                    top:    parent.top
                    bottom: parent.bottom
                    right:  parent.right
                    topMargin: 6
                    bottomMargin: 4
                }
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth:  4
                    implicitHeight: 10
                    radius:         2
                    color:          Qt.rgba(1, 1, 1, 0.22)
                }
            }
        }
    }
}
