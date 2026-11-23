import QtQuick
import qs.src.services.system
import qs.src.theme
// UpdateCommitList — the first three incoming commit subjects (hash
// stripped) and a "+ N more" line.
Column {
    spacing: 4

    Repeater {
        model: Math.min(3, UpdateService.commitMessages.length)
        delegate: Row {
            spacing: 8
            Text {
                text:           "·"
                font.pixelSize: 11
                color:          Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.60)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                width:          parent.parent.width - 18
                font.pixelSize: 11
                color:          Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.55)
                elide:          Text.ElideRight
                // Strip the short hash prefix from the commit line
                text: {
                    var m = UpdateService.commitMessages[index] || ""
                    var sp = m.indexOf(" ")
                    return sp >= 0 ? m.substring(sp + 1) : m
                }
            }
        }
    }

    Text {
        visible:        UpdateService.commitMessages.length > 3
        text:           "+ " + (UpdateService.commitMessages.length - 3) + " more"
        font.pixelSize: 10
        color:          Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.40)
        leftPadding:    16
    }
}
