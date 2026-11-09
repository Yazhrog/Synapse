import QtQuick
import "../../"

// NotchTitleItem — the focused app's name (ActiveWindowService).

Text {
    text:  ActiveWindowService.title
    color: Theme.text
    font.pixelSize: 13
    verticalAlignment:   Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
}
