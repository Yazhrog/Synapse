import QtQuick
import qs.src.components.base
import qs.src.core
import qs.src.services.media
import qs.src.state
// AudioControl — the audio popup: the page area and the tab column, both
// from AudioPages. Hosted by the right-center region of DynamicSurface.
Item {
    id: root

    function reset() { switcher.reset() }

    // The mixer lists every device: AudioService tracks them while shown.
    Lease { service: AudioService; active: root.visible }

    property string page: Popups.audioPage

    AudioPages { id: registry }

    Connections {
        target: Popups
        function onAudioPageChanged() {
            root.page = Popups.audioPage
        }
    }

    Row {
        anchors.fill: parent
        spacing: 8

        // ── Page content ──────────────────────────────────────────────────────
        Item {
            width:  parent.width - switcher.implicitWidth - parent.spacing - 1 - parent.spacing
            height: parent.height
            clip:   true

            PageStack {
                anchors.fill: parent
                pages:   registry.pages
                current: root.page
            }
        }

        // Divider
        Rectangle {
            width: 1; height: parent.height
            color: Qt.rgba(1, 1, 1, 0.1)
        }

        // Tab switcher — right side
        TabSwitcher {
            id: switcher
            orientation: "vertical"
            height: (parent.height - 17)
            anchors.verticalCenter: parent.verticalCenter
            model: Array.from(registry.pages, p => ({ key: p.key, icon: p.icon }))
            currentPage: root.page
            onPageChanged: function(key) { Popups.audioPage = key }
        }
    }
}
