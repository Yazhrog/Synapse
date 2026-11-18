import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The clipboard history: a panel in the bottom-right corner.
PopupSpec {
    key:    "clipboard"
    region: "bottomRight"
    size:   s => [s.px(Metrics.clipboardPanelWidth), s.px(Metrics.clipboardPanelHeight)]
    place:  (s, w, h) => Qt.rect(s.px(10), s.px(8), s.px(Metrics.clipboardPanelWidth - 10),
                                 s.px(Metrics.clipboardPanelHeight - 16))
    focus:  item => item.forceActiveFocus()
    component: Component {
        FocusScope {
            Keys.onEscapePressed: Popups.close("clipboard")
            HistoryTab { anchors.fill: parent }
        }
    }
}
