import QtQuick
import qs.src.services.desktop
import qs.src.theme
// NotchTitleItem — the focused app's name (ActiveWindowService).

Text {
    text:  ActiveWindowService.title
    color: Theme.color.text
    font.pixelSize: 13
    verticalAlignment:   Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
}
