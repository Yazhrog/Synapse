import QtQuick
import qs.src.components.base
import qs.src.theme
Item {
    id: root

    property string _page: "general"

    ConfigTabs { id: registry }

    // First tab, every page scrolled to the top (the dashboard closed).
    function reset() {
        _page = registry.tabs[0].key
        stack.resetAll()
    }

    readonly property var _tabs: Array.from(registry.tabs, t => ({ key: t.key, icon: t.icon, label: t.label }))

    Row {
        anchors {
            fill:    parent
            margins: 8
        }
        spacing: 12

        // ── Left: tab column (30%) ────────────────────────────────────────────
        Rectangle {
            width:  Math.floor((parent.width - parent.spacing) * 0.30)
            height: parent.height
            radius: Theme.cornerRadius
            color:  Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            TabSwitcher {
                orientation: "vertical"
                anchors {
                    top:              parent.top
                    bottom:           parent.bottom
                    left:             parent.left
                    right:            parent.right
                    topMargin:        8
                    bottomMargin:     8
                    leftMargin:       6
                    rightMargin:      6
                }
                currentPage: root._page
                model:       root._tabs
                onPageChanged: function(key) { root._page = key }
            }
        }

        // ── Right: content area (70%) ─────────────────────────────────────────
        Item {
            width:  parent.width - Math.floor((parent.width - parent.spacing) * 0.30) - parent.spacing
            height: parent.height

            PageStack {
                id: stack
                anchors.fill: parent
                pages:   registry.tabs
                current: root._page
            }
        }
    }
}