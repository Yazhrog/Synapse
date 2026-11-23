// Contract test: facts that live in two places and must agree, and the shape
// of every registry (ARCHITECTURE.md §11).
//
//   1. Actions (app/ActionManifest.qml, with the popups' generated toggles):
//      unique keys, each with a label, a group and run(); the keys equal the
//      keys of src/config/keybind-defaults.json (the generated Hyprland binds
//      call `qs ipc call <key> toggle`, which IpcBridge routes to the action).
//   2. Popups (app/PopupManifest.qml): unique keys, a known region, a
//      component, size() and place() that return a size and a rect, a
//      pageProp that is a Popups property, a defaultPagePref that is a pref.
//   3. Page and tab registries (DashboardPages, AudioPages, NetworkTabs,
//      ConfigTabs): unique keys, an icon, a component.
//   4. QuickTiles: unique keys, a label, an icon, toggle().
//   5. BarWidgets: unique keys, a known zone, a component; every zone has one.
//   6. NotchItems: unique keys, a known autoScroll, a component.
//
// Run by tests/smoke.sh; prints CONTRACTS OK, or one FAIL line per problem.
// Every entry is also instantiated, by tests/smoke-registries.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.app
import qs.src.features.audio
import qs.src.features.bar
import qs.src.features.bar.center
import qs.src.features.dashboard
import qs.src.features.dashboard.config
import qs.src.features.dashboard.home
import qs.src.features.network
import qs.src.services.data
import qs.src.state
ShellRoot {
    id: root

    PopupManifest  { id: popups }
    ActionManifest { id: actions; popups: popups.popups }
    DashboardPages { id: dashboardPages }
    AudioPages     { id: audioPages }
    NetworkTabs    { id: networkTabs }
    ConfigTabs     { id: configTabs }
    QuickTiles     { id: quickTiles }
    BarWidgets     { id: barWidgets }
    NotchItems     { id: notchItems }

    readonly property var regions: ["top", "right", "leftCenter", "rightCenter", "bottomCenter", "bottomRight"]

    // What a spec's functions read from the DynamicSurface, at scale 1.
    readonly property var fakeSurface: ({
        px: v => Math.round(v), borderWidth: 2, notchRadius: 16, notchHeight: 34,
        notchBottom: 34, cornerRadius: 12, framed: true, width: 1920, height: 1080
    })

    FileView {
        id: defaults
        path: Quickshell.shellDir + "/src/config/keybind-defaults.json"
        blockLoading: true
    }

    property var fails: []
    function fail(msg) { fails.push(msg) }

    // Unique non-empty keys; returns the key list.
    function keysOf(name, list) {
        const seen = {}, out = []
        for (let i = 0; i < list.length; i++) {
            const k = list[i].key
            if (!k) fail(name + ": entry " + i + " has no key")
            else if (seen[k]) fail(name + ": key '" + k + "' is listed twice")
            seen[k] = true
            out.push(k)
        }
        if (list.length === 0) fail(name + " is empty")
        return out
    }

    function checkActions() {
        const list = actions.actions
        const keys = keysOf("actions", list)
        for (const a of list) {
            if (!a.label) fail("action '" + a.key + "' has no label")
            if (!a.group) fail("action '" + a.key + "' has no group")
            if (typeof a.run !== "function") fail("action '" + a.key + "' has no run()")
        }
        const binds = Object.keys(JSON.parse(defaults.text()))
        for (const b of binds)
            if (keys.indexOf(b) < 0) fail("keybind-defaults.json action '" + b + "' is not in the Actions registry")
        for (const k of keys)
            if (binds.indexOf(k) < 0) fail("action '" + k + "' has no line in keybind-defaults.json")
        if (keys.indexOf("quickcontrols-show") >= 0) fail("'quickcontrols-show' is IpcBridge's own target, not an action")
        return keys.length
    }

    function checkPopups() {
        const list = popups.popups
        keysOf("popups", list)
        for (let i = 0; i < list.length; i++) {
            const p = list[i], k = p.key
            if (regions.indexOf(p.region) < 0) fail("popup '" + k + "' has unknown region '" + p.region + "'")
            if (!p.component) fail("popup '" + k + "' has no component")
            const sz = p.size(fakeSurface, null)
            if (!sz || sz.length !== 2 || !(sz[0] > 0) || !(sz[1] > 0)) fail("popup '" + k + "' size() is not [w, h] > 0")
            const r = p.place(fakeSurface, 900, 500)
            if (!r || !(r.width > 0) || !(r.height > 0)) fail("popup '" + k + "' place() is not a rect")
            if (p.pageProp !== "" && typeof Popups[p.pageProp] !== "string")
                fail("popup '" + k + "' pageProp '" + p.pageProp + "' is not a Popups property")
            if (p.defaultPagePref !== "" && !(p.defaultPagePref in Prefs.defaults))
                fail("popup '" + k + "' defaultPagePref '" + p.defaultPagePref + "' is not a pref")
            if (p.pageProp !== "" && (p.pages ?? []).length === 0) fail("popup '" + k + "' has a pageProp but no pages")
        }
        return list.length
    }

    function checkPages(name, list) {
        keysOf(name, list)
        for (const p of Array.from(list)) {
            if (!p.icon) fail(name + " '" + p.key + "' has no icon")
            if (!p.component) fail(name + " '" + p.key + "' has no component")
        }
        return list.length
    }

    function checkTiles() {
        const list = quickTiles.tiles
        keysOf("QuickTiles", list)
        for (const t of Array.from(list)) {
            if (!t.label) fail("tile '" + t.key + "' has no label")
            if (!t.icon) fail("tile '" + t.key + "' has no icon")
            if (typeof t.toggle !== "function") fail("tile '" + t.key + "' has no toggle()")
        }
        return list.length
    }

    function checkBar() {
        const list = barWidgets.widgets
        keysOf("BarWidgets", list)
        const zones = { left: 0, center: 0, right: 0 }
        for (const w of Array.from(list)) {
            if (!(w.zone in zones)) fail("bar widget '" + w.key + "' has unknown zone '" + w.zone + "'")
            else zones[w.zone]++
            if (!w.component) fail("bar widget '" + w.key + "' has no component")
        }
        for (const z in zones) if (zones[z] === 0) fail("bar zone '" + z + "' has no widget")
        return list.length
    }

    function checkNotch() {
        const list = notchItems.items
        keysOf("NotchItems", list)
        for (const n of Array.from(list)) {
            if (["none", "fromTitle", "always"].indexOf(n.autoScroll) < 0)
                fail("notch item '" + n.key + "' has unknown autoScroll '" + n.autoScroll + "'")
            if (!n.component) fail("notch item '" + n.key + "' has no component")
        }
        return list.length
    }

    Component.onCompleted: {
        const counts = [
            checkActions() + " actions",
            checkPopups() + " popups",
            checkPages("DashboardPages", dashboardPages.pages) + " dashboard pages",
            checkPages("AudioPages", audioPages.pages) + " audio pages",
            checkPages("NetworkTabs", networkTabs.pages) + " network tabs",
            checkPages("ConfigTabs", configTabs.tabs) + " config tabs",
            checkTiles() + " tiles",
            checkBar() + " bar widgets",
            checkNotch() + " notch items"
        ]
        for (const f of fails) console.log("FAIL " + f)
        if (fails.length === 0) console.log("CONTRACTS OK (" + counts.join(", ") + ")")
        Qt.quit()
    }
}
