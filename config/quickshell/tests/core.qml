// Behaviour tests of the core toolkit (src/core): Exec, ExecQueue, JsonStore,
// Lease. Each test is an async step; prints "PASS <name>" or "FAIL <name>: …",
// then CORE OK when every step passed. Run by tests/smoke.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.src.core
ShellRoot {
    id: t

    readonly property string dir: Quickshell.env("HOME") + "/core-test"
    property int failures: 0
    property int index: -1

    function pass(name) { console.log("PASS " + name); Qt.callLater(next) }
    function fail(name, msg) { failures++; console.log("FAIL " + name + ": " + msg); Qt.callLater(next) }
    function check(name, cond, msg) { if (cond) pass(name); else fail(name, msg) }

    // Runs `argv` with a fresh Exec and calls back with what it reported.
    function exec(props, argv, cb) {
        const e = execComp.createObject(t, props)
        const events = []
        e.succeeded.connect(r => events.push(["ok", r]))
        e.failed.connect((c, err) => events.push(["fail", c, err]))
        e.line.connect(l => events.push(["line", l]))
        e.finished.connect(() => Qt.callLater(() => { cb(events, e); e.destroy() }))
        e.run(argv)
        return e
    }
    Component { id: execComp; Exec {} }

    // Reads a file's current content (or null when missing).
    function readFile(path, cb) {
        exec({}, ["sh", "-c", 'if [ -f "$1" ]; then printf "1"; cat "$1"; else printf "0"; fi', "--", path],
             ev => cb(ev[0][1][0] === "1" ? ev[0][1].slice(1) : null))
    }
    function writeFile(path, text, cb) {
        exec({}, ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "--", path, text], () => cb())
    }
    function store(props, cb) {
        const s = (props.defaults ? storeComp : tasksStoreComp).createObject(t, props)
        if (s.ready) Qt.callLater(() => cb(s))
        else s.loaded.connect(() => Qt.callLater(() => cb(s)))
        return s
    }
    Component { id: storeComp; JsonStore {} }
    Component { id: tasksStoreComp; JsonStore { defaults: ({ tasks: [], nextId: 0 }) } }

    readonly property var steps: [
        // ── Exec ────────────────────────────────────────────────────────────
        () => exec({ parse: out => out.split("\n") }, ["sh", "-c", "printf 'a\\nb'"], ev =>
            check("exec parses stdout", JSON.stringify(ev) === '[["ok",["a","b"]]]', JSON.stringify(ev))),
        () => exec({}, ["sh", "-c", "echo partial; exit 1"], (ev, e) =>
            check("exec keeps stdout of a failed run in lastOutput", ev[0][0] === "fail" && e.lastOutput === "partial\n", e.lastOutput)),
        () => exec({}, ["sh", "-c", "echo err >&2; exit 3"], ev =>
            check("exec reports exit code and stderr", JSON.stringify(ev) === '[["fail",3,"err\\n"]]', JSON.stringify(ev))),
        () => exec({}, ["sh", "-c", 'printf %s "$1"', "--", '$(echo hacked); "x'], ev =>
            check("exec passes data as one literal argument", ev[0][1] === '$(echo hacked); "x', JSON.stringify(ev))),
        () => exec({ stdinText: "secret\n" }, ["cat"], ev =>
            check("exec writes stdin", ev[0][0] === "ok" && ev[0][1] === "secret\n", JSON.stringify(ev))),
        () => exec({ timeout: 300 }, ["sleep", "5"], ev =>
            check("exec times out with 124", ev[0][0] === "fail" && ev[0][1] === 124, JSON.stringify(ev))),
        () => exec({}, ["definitely-not-a-command-xyz"], ev =>
            check("exec reports a command that can't start", ev[0][0] === "fail" && ev[0][1] === -2, JSON.stringify(ev))),
        () => exec({ parse: out => { throw new Error("bad") } }, ["true"], ev =>
            check("exec turns a parse error into failed(-1)", ev[0][0] === "fail" && ev[0][1] === -1, JSON.stringify(ev))),
        () => exec({ stream: true }, ["sh", "-c", "echo a; echo b"], ev =>
            check("exec streams lines", JSON.stringify(ev) === '[["line","a"],["line","b"],["ok",""]]', JSON.stringify(ev))),
        () => {
            // run() while running cancels the first run, which reports nothing
            const events = []
            const e = execComp.createObject(t)
            e.succeeded.connect(r => events.push(r.trim()))
            e.failed.connect(c => events.push("failed " + c))
            e.run(["sh", "-c", "sleep 0.5; echo first"])
            e.run(["echo", "second"])
            restartTimer.cb = () => { check("exec restart cancels the running command", JSON.stringify(events) === '["second"]', JSON.stringify(events)); e.destroy() }
            restartTimer.start()
        },
        () => {
            const results = []
            queue.enqueue(["sh", "-c", "sleep 0.2; echo 1"], (ok, r) => results.push(r.trim()))
            queue.enqueue(["echo", "2"], (ok, r) => results.push(r.trim()))
            queue.enqueue(["false"], (ok, r, code) => {
                results.push("x" + code)
                check("execqueue runs in order", JSON.stringify(results) === '["1","2","x1"]', JSON.stringify(results))
            })
        },
        // A callback that queues more (Hypr.setOptions(…, () => Hypr.reload())),
        // and one that throws: every command still runs, once, in order.
        () => {
            const results = []
            queue.enqueue(["echo", "a"], (ok, r) => {
                results.push(r.trim())
                queue.enqueue(["echo", "c"], (ok2, r2) => {
                    results.push(r2.trim())
                    check("execqueue runs what a callback queues, after a throwing callback",
                          JSON.stringify(results) === '["a","b","c"]', JSON.stringify(results))
                })
            })
            queue.enqueue(["echo", "b"], (ok, r) => { results.push(r.trim()); throw new Error("boom") })
        },
        () => exec({ discardOutput: true }, ["sh", "-c", "echo out; echo err >&2; exit 2"], ev =>
            check("exec discardOutput reads neither stream", JSON.stringify(ev) === '[["fail",2,""]]', JSON.stringify(ev))),

        // ── JsonStore ───────────────────────────────────────────────────────
        // (defaults declared in QML, as services do: passed through
        // createObject() a JS object becomes a map with sorted keys)
        () => store({ path: dir + "/new/tasks.json" }, s =>
            settle(() => readFile(dir + "/new/tasks.json", text =>
                check("store creates a missing file with the defaults",
                      s.ready && JSON.stringify(s.data) === '{"tasks":[],"nextId":0}' && text === '{"tasks":[],"nextId":0}',
                      JSON.stringify(s.data) + " / " + text)))),
        () => writeFile(dir + "/merge.json", '{"extra":true,"nextId":4}', () =>
            store({ path: dir + "/merge.json", defaults: ({ tasks: [], nextId: 0 }) }, s =>
                check("store keeps the file's keys and fills missing ones",
                      JSON.stringify(s.data) === '{"extra":true,"nextId":4,"tasks":[]}', JSON.stringify(s.data)))),
        () => writeFile(dir + "/upd.json", '{"tasks":[],"nextId":0}', () =>
            store({ path: dir + "/upd.json", defaults: ({ tasks: [], nextId: 0 }) }, s => {
                const id = s.update(d => { d.tasks.unshift({ id: d.nextId, title: "a" }); return d.nextId++ })
                settle(() => readFile(dir + "/upd.json", text =>
                    check("store update returns, saves compact JSON",
                          id === 0 && text === '{"tasks":[{"id":0,"title":"a"}],"nextId":1}', id + " / " + text)))
            })),
        () => writeFile(dir + "/broken.json", '{"tasks": [oops', () =>
            store({ path: dir + "/broken.json", defaults: ({ tasks: [] }) }, s => {
                const ok = s.error !== "" && JSON.stringify(s.data) === '{"tasks":[]}'
                s.update(d => d.tasks.push(1))
                settle(() => readFile(dir + "/broken.json.broken", backup => readFile(dir + "/broken.json", text =>
                    check("store keeps an unreadable file as .broken before writing",
                          ok && backup === '{"tasks": [oops' && text === '{"tasks":[1]}', s.error + " / " + backup + " / " + text))))
            })),
        () => writeFile(dir + "/clear.json", '{"tasks":[1,2]}', () =>
            store({ path: dir + "/clear.json", defaults: ({ tasks: [] }) }, s => {
                let clearedSeen = false
                s.cleared.connect(() => clearedSeen = true)
                s.clear()
                settle(() => readFile(dir + "/clear.json", text =>
                    check("store clear writes the defaults, then resets data",
                          clearedSeen && text === '{"tasks":[]}' && JSON.stringify(s.data) === '{"tasks":[]}', clearedSeen + " / " + text)))
            })),
        () => writeFile(dir + "/clear2.json", '{"tasks":[1,2]}', () =>
            store({ path: dir + "/clear2.json", defaults: ({ tasks: [] }) }, s => {
                s.clear()
                s.update(d => d.tasks.push(9))      // while the clear is being written
                settle(() => readFile(dir + "/clear2.json", text =>
                    check("store keeps a change made during clear",
                          text === '{"tasks":[9]}' && JSON.stringify(s.data) === '{"tasks":[9]}', text + " / " + JSON.stringify(s.data))))
            })),
        // A path that can't be read (a directory): never loaded, so clear() must not write.
        () => exec({}, ["mkdir", "-p", dir + "/isdir.json"], () => {
            const s = storeComp.createObject(t, { path: dir + "/isdir.json", defaults: ({ a: 0 }) })
            settle(() => {
                s.clear()
                settle(() => exec({}, ["sh", "-c", '[ -d "$1" ] && echo dir', "--", dir + "/isdir.json"], ev =>
                    check("store clear before the first load writes nothing",
                          !s.ready && ev[0][1].trim() === "dir", s.ready + " / " + JSON.stringify(ev))))
            })
        }),
        () => writeFile(dir + "/mig.json", '{"a":1}', () =>
            store({ path: dir + "/mig.json", defaults: ({ a: 0 }), version: 2,
                    migrate: (d, from) => { d.b = from; return d } }, s =>
                settle(() => readFile(dir + "/mig.json", text =>
                    check("store migrates once and records _version",
                          text === '{"a":1,"b":0,"_version":2}', text))))),
        () => writeFile(dir + "/ro.json", '{"a":1}', () =>
            store({ path: dir + "/ro.json", defaults: ({ a: 0 }), readOnly: true }, s => {
                s.update(d => d.a = 2)
                settle(() => readFile(dir + "/ro.json", text =>
                    check("store readOnly never writes", text === '{"a":1}' && s.data.a === 1, text)))
            })),
        () => readFile(dir + "/missing-ro.json", () =>
            store({ path: dir + "/missing-ro.json", defaults: ({ a: 0 }), readOnly: true }, s =>
                settle(() => readFile(dir + "/missing-ro.json", text =>
                    check("store readOnly doesn't create a missing file", text === null && s.data.a === 0, String(text)))))),

        // ── Lease ───────────────────────────────────────────────────────────
        () => {
            const svg = leaseTarget
            const l = leaseComp.createObject(t, { service: svg, active: false })
            const a = svg.count
            l.active = true;  const b = svg.count
            l.active = true;  const c = svg.count
            l.active = false; const d = svg.count
            l.active = true
            l.destroy()
            settle(() => check("lease acquires once, releases on inactive and destruction",
                               [a, b, c, d, svg.count].join() === "0,1,1,0,0", [a, b, c, d, svg.count].join()))
        }
    ]

    LeaseCount { id: leaseTarget }
    Component { id: leaseComp; Lease {} }
    ExecQueue { id: queue }

    // Lets FileView writes and object destruction land before checking.
    function settle(cb) { settleTimer.cb = cb; settleTimer.start() }
    Timer { id: settleTimer; interval: 300; property var cb; onTriggered: cb() }
    Timer { id: restartTimer; interval: 900; property var cb; onTriggered: cb() }

    function next() {
        index++
        if (index >= steps.length) {
            if (failures === 0) console.log("CORE OK (" + steps.length + " tests)")
            Qt.quit()
            return
        }
        steps[index]()
    }

    Component.onCompleted: next()
}
