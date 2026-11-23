import QtQuick
// PageStack — shows one page of a registry (PageSpec / TabSpec list) at a
// time, each page filling the stack.
//
//   PageStack { anchors.fill: parent; pages: registry.pages
//               current: root.page; host: root }
//
// Pages are created up front and kept (`lazy: false`, the default), or only
// while shown (`lazy: true`). A page item gets `host` if it declares it.
// resetAll() calls reset() on every page that has one; items[key] is the
// page item (reassigned, so bindings on it update).
Item {
    id: root

    property var    pages:   []
    property string current: ""
    property var    host:    null
    property bool   lazy:    false

    property var items: ({})

    function resetAll() {
        for (const k in items) {
            const it = items[k]
            if (it && typeof it.reset === "function") it.reset()
        }
    }

    Repeater {
        model: root.pages
        delegate: Item {
            id: slot
            required property var modelData
            anchors.fill: parent
            visible: root.current === modelData.key

            Loader {
                anchors.fill: parent
                active:          !root.lazy || slot.visible
                sourceComponent: slot.modelData.component
                onLoaded: {
                    if ("host" in item) item.host = root.host
                    const items = Object.assign({}, root.items)
                    items[slot.modelData.key] = item
                    root.items = items
                }
                onItemChanged: if (!item && root.items[slot.modelData.key]) {
                    const items = Object.assign({}, root.items)
                    delete items[slot.modelData.key]
                    root.items = items
                }
            }
        }
    }
}
