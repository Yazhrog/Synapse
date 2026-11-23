import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The audio popup: a bump on the right border, as wide as its page.
PopupSpec {
    id: spec
    key:    "audio"
    region: "rightCenter"
    pageProp:        "audioPage"
    defaultPagePref: "defaultAudioPage"

    function _width(s, item) { return s.px(Metrics.audioPageWidths[item ? item.page : Popups.audioPage] ?? 300) }

    size:   (s, item) => [spec._width(s, item), s.px(Metrics.sideRegionHeight)]
    place:  (s, w, h) => Qt.rect(s.px(10), s.px(6), w - s.px(16), h - s.px(12))
    afterClose: item => item.reset()
    component: Component { AudioControl {} }
}
