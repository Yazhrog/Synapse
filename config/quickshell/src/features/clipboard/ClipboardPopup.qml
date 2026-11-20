import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The clipboard history: a panel in the bottom-right corner.
PopupSpec {
    key:    "clipboard"
    region: "bottomRight"
    action: "clipboard-toggle"; actionLabel: "Clipboard"
    size:   s => [s.px(Theme.frame.clipboardPanelWidth), s.px(Theme.frame.clipboardPanelHeight)]
    place:  (s, w, h) => Qt.rect(s.px(10), s.px(8), s.px(Theme.frame.clipboardPanelWidth - 10),
                                 s.px(Theme.frame.clipboardPanelHeight - 16))
    focus:  item => item.forceActiveFocus()
    component: Component {
        FocusScope {
            Keys.onEscapePressed: Popups.close("clipboard")
            HistoryTab { anchors.fill: parent }
        }
    }
}
