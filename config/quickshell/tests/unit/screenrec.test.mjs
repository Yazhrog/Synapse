// Unit tests for src/services/media/screenrec.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const R = require("../../src/services/media/screenrec.js")

test("formatElapsed", () => {
    assert.equal(R.formatElapsed(0), "00:00")
    assert.equal(R.formatElapsed(65), "01:05")
    assert.equal(R.formatElapsed(3600), "60:00")
})

test("audioRouting per option", () => {
    assert.equal(R.audioRouting(false, false), null)
    assert.deepEqual(R.audioRouting(true, false), { command: ["pactl", "get-default-source"], usesNullSink: false })
    const sys = R.audioRouting(false, true), both = R.audioRouting(true, true)
    assert.equal(sys.usesNullSink, true)
    assert.equal(sys.command[0], "bash")
    assert.ok(sys.command[2].includes("sink_name=SynapseMixer"))
    assert.ok(!sys.command[2].includes("source=$(pactl get-default-source)"))
    assert.ok(both.command[2].includes("source=$(pactl get-default-source)"))
    assert.ok(both.command[2].endsWith("printf 'SynapseMixer.monitor\\n'"))
})

test("lastLine", () => {
    assert.equal(R.lastLine("a\n\nSynapseMixer.monitor\n  \n"), "SynapseMixer.monitor")
    assert.equal(R.lastLine(""), "")
})

test("parseCavaLine: 12 levels or null", () => {
    assert.deepEqual(R.parseCavaLine("1;2;3;4;5;6;7;8;9;10;11;x;"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0])
    assert.equal(R.parseCavaLine("1;2;3;"), null)
    assert.equal(R.parseCavaLine("  "), null)
})

test("cavaConfig names the source", () => {
    assert.ok(R.cavaConfig("SynapseMixer.monitor").endsWith("source = SynapseMixer.monitor\n"))
})
