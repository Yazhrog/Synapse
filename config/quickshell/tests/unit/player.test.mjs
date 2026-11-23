// Unit tests for src/features/dashboard/home/player.js. Run: config/quickshell/tests/unit.sh
import { createRequire } from "node:module"
import { test } from "node:test"
import assert from "node:assert/strict"
const require = createRequire(import.meta.url)
const P = require("../../src/features/dashboard/home/player.js")

test("formatTime", () => {
    assert.equal(P.formatTime(0), "0:00")
    assert.equal(P.formatTime(65.9), "1:05")
    assert.equal(P.formatTime(600), "10:00")
})

test("player labels and icons", () => {
    assert.equal(P.playerLabel(null), "—")
    assert.equal(P.playerLabel({ identity: "Mozilla Firefox" }), "Firefox")
    assert.equal(P.playerLabel({ identity: "Chromium" }), "Chromium")
    assert.equal(P.playerLabel({ identity: "mpv" }), "mpv")
    assert.equal(P.playerLabel({ identity: "" }), "Player")
    assert.equal(P.playerIcon(null), "♪")
    assert.equal(P.playerIcon({ identity: "mpv" }), "♪")
    assert.notEqual(P.playerIcon({ identity: "Spotify" }), "♪")
})
