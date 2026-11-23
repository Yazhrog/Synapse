pragma Singleton
import QtQuick
import Quickshell
import "hypr.js" as HyprCmd

// Hypr — the one place that runs hyprctl to change Hyprland.
//
//   Hypr.setOptions("general", { gaps_in: { top: 5, right: 5, bottom: 5, left: 5 } })
//   Hypr.submap("Synapse_clean");  Hypr.submap("reset")
//   Hypr.evalLua("if SynapseFrameBlur then … end")   // Lua provider only
//   Hypr.dispatch('hl.dsp.dpms({ action = "disable" })', ["dpms", "off"])
//
// `provider` ("lua" or "conf") comes from user_data/config_Provider.json,
// written by the installer; each call builds the right syntax for it
// (hypr.js, unit-tested). Commands run one at a time, in call order; `done`
// gets (ok, stderr) after the last command of the call. Queries and events
// stay on Quickshell.Hyprland.
Singleton {
    id: root

    readonly property string provider: _provider.data.configProvider === "conf" ? "conf" : "lua"
    readonly property bool   busy:     _queue.busy

    function setOptions(section: string, values: var, done: var) {
        _runAll(HyprCmd.setOptions(provider, section, values), done)
    }
    function submap(name: string, done: var) { _runAll([HyprCmd.submap(provider, name)], done) }
    function reload(done: var)               { _runAll([HyprCmd.reload()], done) }
    // A dispatcher in each provider's form, e.g. dispatch('hl.dsp.dpms({ action = "disable" })', ["dpms", "off"]).
    function dispatch(lua: string, conf: var, done: var) { _runAll([HyprCmd.dispatch(provider, lua, conf)], done) }
    function evalLua(lua: string, done: var) {
        const argv = HyprCmd.evalLua(provider, lua)
        if (argv) _runAll([argv], done)
        else if (done) done(false, "Lua only")
    }

    // ── Implementation ──────────────────────────────────────────────────────
    function _runAll(cmds, done) {
        let ok = true, err = ""
        cmds.forEach((argv, i) => {
            const last = i === cmds.length - 1
            _queue.enqueue(argv, (success, result, code, stderr) => {
                if (!success) { ok = false; err = stderr; console.warn("Hypr: " + argv.join(" ") + " failed: " + stderr) }
                if (last && done) done(ok, err)
            })
        })
    }

    property ExecQueue _queue: ExecQueue {}

    property JsonStore _provider: JsonStore {
        path:     Paths.userData("config_Provider.json")
        defaults: ({ configProvider: "lua" })
        readOnly: true
        watch:    true
    }
}
